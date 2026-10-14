import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  EventChannel,
  EventSink,
  StreamHandler,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import HashMap from '@ohos.util.HashMap';
import {
  CallSDK,
  SDKConfig,
  LogConfig,
  Environment,
  CallInfo,
  CallState,
  CallDirection,
  LoginInfo,
  AgentConfig,
  DisplayNumber,
  NumberGroup,
  NumberGroupListResponse,
  InitListener,
  MakeCallCallback,
  CallStateListener,
  OnServerCallListener,
  DisplayNumberListListener,
  NumberGroupListListener,
  AgentConfigListener,
  AudioRoute,
  AudioRouteChangeListener,
} from '@useasy/callsdk-harmony';

/**
 * HarmonyOS 桥接：通道名与 Android/iOS 一致。
 * MethodChannel: com.jj/callkit/methods
 * EventChannel:  com.jj/callkit/events
 *
 * callCalling：原生无 onCallCalling，在 makeCall 成功时补发。
 * sipDisconnected：由 HAR 根据 PJSIP reg_state 丢失发出。
 */
export default class JjCallkitPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler {
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private appContext: common.Context | null = null;
  private pendingInit: MethodResult | null = null;
  private callStateListener: PluginCallStateListener = new PluginCallStateListener(this);
  private serverCallListener: PluginServerCallListener = new PluginServerCallListener(this);
  private audioRouteChangeListener: PluginAudioRouteListener = new PluginAudioRouteListener(this);

  getUniqueClassName(): string {
    return 'JjCallkitPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.appContext = binding.getApplicationContext();
    const messenger = binding.getBinaryMessenger();
    this.methodChannel = new MethodChannel(messenger, 'com.jj/callkit/methods');
    this.methodChannel.setMethodCallHandler(this);
    this.eventChannel = new EventChannel(messenger, 'com.jj/callkit/events');
    this.eventChannel.setStreamHandler(this);
    this.registerPersistentListeners();
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.eventChannel?.setStreamHandler(null);
    this.eventSink = null;
    CallSDK.removeCallStateListener(this.callStateListener);
    CallSDK.setOnServerCallListener(null);
    CallSDK.setOnKickedListener(null);
    CallSDK.setOnSipDisconnectedListener(null);
    CallSDK.setAudioRouteChangeListener(null);
  }

  onListen(_args: Object, events: EventSink): void {
    this.eventSink = events;
  }

  onCancel(_args: Object): void {
    this.eventSink = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'init':
        this.handleInit(call, result);
        break;
      case 'logout':
        CallSDK.logout();
        result.success(null);
        break;
      case 'release':
        CallSDK.removeCallStateListener(this.callStateListener);
        CallSDK.setOnServerCallListener(null);
        CallSDK.setOnKickedListener(null);
        CallSDK.setOnSipDisconnectedListener(null);
        CallSDK.setAudioRouteChangeListener(null);
        CallSDK.release();
        result.success(null);
        break;
      case 'makeCall':
        this.handleMakeCall(call, result);
        break;
      case 'hangupCall':
        CallSDK.hangupCall();
        result.success(null);
        break;
      case 'setMute':
        CallSDK.openMute(this.boolArg(call, 'enabled') === true);
        result.success(null);
        break;
      case 'isMuted':
        result.success(CallSDK.isMuteOn());
        break;
      case 'setSpeaker': {
        const enabled = this.boolArg(call, 'enabled') === true;
        CallSDK.openLoudSpeaker(enabled);
        const routePayload = new HashMap<string, Object | null>();
        routePayload.set('route', this.routeName(CallSDK.getCurrentAudioRoute()));
        this.emit('audioRouteChanged', routePayload);
        result.success(null);
        break;
      }
      case 'isSpeakerOn':
        result.success(CallSDK.isLoudSpeakerOn());
        break;
      case 'getCurrentAudioRoute':
        result.success(this.routeName(CallSDK.getCurrentAudioRoute()));
        break;
      case 'sendDTMF':
        CallSDK.sendDTMF(this.stringArg(call, 'digit'));
        result.success(null);
        break;
      case 'getCurrentCallInfo': {
        const info = CallSDK.getCurrentCallInfo();
        result.success(info !== null ? this.hashMapToCodecMap(this.callInfoMap(info)) : null);
        break;
      }
      case 'canMakeCall':
        result.success(this.canMakeCall());
        break;
      case 'getLoginInfo': {
        const login = this.loginInfoMap();
        result.success(login !== null ? this.hashMapToCodecMap(login) : null);
        break;
      }
      case 'getAgentConfig':
        this.handleAgentConfig(result);
        break;
      case 'getDisplayNumberList':
        this.handleDisplayNumbers(result);
        break;
      case 'getNumberGroupList':
        this.handleNumberGroups(call, result);
        break;
      case 'updateDisplayNumber':
        this.handleUpdateNumber(call, result);
        break;
      case 'updateNumberGroup':
        this.handleUpdateGroup(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  registerPersistentListeners(): void {
    CallSDK.removeCallStateListener(this.callStateListener);
    CallSDK.addCallStateListener(this.callStateListener);
    CallSDK.setOnServerCallListener(this.serverCallListener);
    CallSDK.setOnKickedListener((): void => {
      this.emit('kicked', new HashMap<string, Object | null>());
    });
    CallSDK.setOnSipDisconnectedListener((): void => {
      this.emit('sipDisconnected', new HashMap<string, Object | null>());
    });
    CallSDK.setAudioRouteChangeListener(this.audioRouteChangeListener);
  }

  emit(type: string, payload: HashMap<string, Object | null>): void {
    // 与 Android 一致：{ type, payload }，必须是 Map（不能自定义 class）。
    const payloadMap = new Map<string, Object>();
    payload.forEach((value: Object | null, key: string) => {
      // StandardMessageCodec 对嵌套 null 在部分机型上编码失败，统一成空串/0
      if (value === null || value === undefined) {
        payloadMap.set(key, '');
      } else {
        payloadMap.set(key, value);
      }
    });
    const event = new Map<string, Object>();
    event.set('type', type);
    event.set('payload', payloadMap);
    const sink = this.eventSink;
    if (sink === null) {
      console.error(`[JjCallkit] emit dropped type=${type}, eventSink=null`);
      return;
    }
    // notifyCallState 已 postToMain，这里同步发送，避免再套 setTimeout 丢序
    try {
      sink.success(event);
      console.info(`[JjCallkit] emit ok type=${type}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`[JjCallkit] emit failed type=${type} err=${msg}`);
    }
  }

  callInfoMap(info: CallInfo): HashMap<string, Object | null> {
    const map = new HashMap<string, Object | null>();
    map.set('callId', info.callId ?? '');
    map.set('phoneNumber', info.phoneNumber ?? '');
    map.set('direction', this.directionName(info.direction));
    map.set('state', this.stateName(info.state));
    map.set('startTime', info.startTime);
    return map;
  }

  /** MethodChannel 结果必须用 Map/Array，自定义 class 经 codec 会变成空对象 */
  hashMapToCodecMap(src: HashMap<string, Object | null>): Map<string, Object> {
    const out = new Map<string, Object>();
    src.forEach((value: Object | null, key: string) => {
      if (value === null || value === undefined) {
        out.set(key, '');
      } else {
        out.set(key, value);
      }
    });
    return out;
  }

  hashMapListToCodec(list: HashMap<string, Object | null>[]): Array<Map<string, Object>> {
    const out: Array<Map<string, Object>> = [];
    for (let i = 0; i < list.length; i++) {
      out.push(this.hashMapToCodecMap(list[i]));
    }
    return out;
  }

  private handleInit(call: MethodCall, result: MethodResult): void {
    if (this.pendingInit !== null) {
      result.error('-1', 'init 正在进行', null);
      return;
    }
    const ctx = this.appContext;
    if (ctx === null) {
      result.error('-1', 'context 为空', null);
      return;
    }
    const username = this.stringArg(call, 'username');
    const password = this.optionalStringArg(call, 'password');
    const passwordPk = this.optionalStringArg(call, 'passwordPk');
    const environment = this.stringArg(call, 'environment');
    const envUrl = environment === 'debug' ? Environment.DEBUG : Environment.PRODUCTION;
    const logConfig = new LogConfig();
    const logMap = this.argMap(call, 'logConfig');
    if (logMap !== null) {
      logConfig.enableLog = logMap.get('enableLog') === true;
      const level: Object | undefined = logMap.get('logLevel');
      if (typeof level === 'number') {
        logConfig.logLevel = level;
      }
      const path: Object | undefined = logMap.get('logFilePath');
      if (typeof path === 'string') {
        logConfig.logFilePath = path;
      }
      logConfig.fileLoggingEnabled = logMap.get('fileLoggingEnabled') === true;
      logConfig.consoleLogEnabled = logMap.get('consoleLogEnabled') === true;
    }
    const config = new SDKConfig(username, password, passwordPk, envUrl, logConfig);
    this.pendingInit = result;
    this.registerPersistentListeners();
    CallSDK.init(ctx, config, new PluginInitListener(this));
  }

  completeInitSuccess(): void {
    // init 完成后再次挂载，避免首次 register 落在 initialized 之前被丢掉
    this.registerPersistentListeners();
    this.emit('sipConnected', new HashMap<string, Object | null>());
    const pending = this.pendingInit;
    this.pendingInit = null;
    pending?.success(null);
  }

  completeInitFailed(errorCode: number, errorMsg: string | null): void {
    const payload = new HashMap<string, Object | null>();
    payload.set('errorCode', errorCode);
    payload.set('errorMsg', errorMsg ?? '');
    this.emit('sipConnectFailed', payload);
    const pending = this.pendingInit;
    this.pendingInit = null;
    pending?.error(`${errorCode}`, errorMsg, null);
  }

  private handleMakeCall(call: MethodCall, result: MethodResult): void {
    if (CallSDK.getLoginInfo() === null) {
      result.error('-302', '未登录无法呼叫', null);
      return;
    }
    const phone = this.stringArg(call, 'phoneNumber');
    const userData = this.argRecord(call, 'userData');
    const callback = new PluginMakeCallCallback(this, result);
    if (userData !== null) {
      CallSDK.makeCall(phone, userData, callback);
    } else {
      CallSDK.makeCall(phone, callback);
    }
  }

  private handleAgentConfig(result: MethodResult): void {
    CallSDK.getAgentConfig(new PluginAgentConfigListener(result, this, true));
  }

  private handleDisplayNumbers(result: MethodResult): void {
    CallSDK.queryDisplayNumberList(new PluginDisplayNumberListener(result, this));
  }

  private handleNumberGroups(call: MethodCall, result: MethodResult): void {
    const pageArg: Object | null = call.argument('page') as Object | null;
    const pageSizeArg: Object | null = call.argument('pageSize') as Object | null;
    const page = typeof pageArg === 'number' ? pageArg : 1;
    const pageSize = typeof pageSizeArg === 'number' ? pageSizeArg : 20;
    CallSDK.queryNumberGroupList(page, pageSize, new PluginNumberGroupListener(result, this));
  }

  private handleUpdateNumber(call: MethodCall, result: MethodResult): void {
    const number = this.stringArg(call, 'selectNumber');
    CallSDK.updateAgentSelectNumber(number, new PluginAgentConfigListener(result, this, false));
  }

  private handleUpdateGroup(call: MethodCall, result: MethodResult): void {
    const id = this.optionalStringArg(call, 'id');
    const name = this.optionalStringArg(call, 'name');
    const listener = new PluginAgentConfigListener(result, this, false);
    if (id !== null && id.length > 0) {
      CallSDK.updateAgentNumberGroupById(id, listener);
    } else if (name !== null && name.length > 0) {
      CallSDK.updateAgentNumberGroupByName(name, listener);
    } else {
      result.error('-4002', '号码组 id 和 name 都为空', null);
    }
  }

  private canMakeCall(): boolean {
    if (CallSDK.getLoginInfo() === null) {
      return false;
    }
    const current = CallSDK.getCurrentCallInfo();
    if (current === null) {
      return true;
    }
    return current.state === CallState.RELEASED || current.state === CallState.FAILED;
  }

  loginInfoMap(): HashMap<string, Object | null> | null {
    const info: LoginInfo | null = CallSDK.getLoginInfo();
    if (info === null) {
      return null;
    }
    const map = new HashMap<string, Object | null>();
    map.set('agentId', info.agent?._id ?? null);
    map.set('mobile', info.agent?.mobile ?? null);
    map.set('agentNumber', info.agent?.agentNumber ?? null);
    map.set('accountId', info.account?._id ?? null);
    return map;
  }

  agentConfigMap(config: AgentConfig | null): HashMap<string, Object | null> {
    const map = new HashMap<string, Object | null>();
    const call = config?.agentCallConfig;
    map.set('id', config?._id ?? null);
    map.set('agentName', config?.agentName ?? null);
    map.set('mobile', config?.mobile ?? null);
    map.set('agentNumber', config?.agentNumber ?? null);
    map.set('callerStrategy', call?.callerStrategy ?? []);
    map.set('selectNumber', call?.selectNumber ?? null);
    map.set('numberGroup', call?.numberGroup ?? null);
    map.set('sipNumber', call?.sipNumber ?? null);
    map.set('numbers', call?.numbers ?? []);
    map.set('numberSelect', call?.numberSelect ?? null);
    return map;
  }

  displayNumberMap(item: DisplayNumber): HashMap<string, Object | null> {
    const map = new HashMap<string, Object | null>();
    map.set('id', item.id);
    map.set('status', item.status);
    map.set('number', item.number);
    map.set('province', item.province);
    map.set('city', item.city);
    return map;
  }

  numberGroupMap(item: NumberGroup): HashMap<string, Object | null> {
    const map = new HashMap<string, Object | null>();
    map.set('id', item.id);
    map.set('groupName', item.groupName);
    map.set('name', item.groupName);
    map.set('remark', item.remark);
    return map;
  }

  private directionName(direction: CallDirection): string {
    return direction === CallDirection.SERVER ? 'server' : 'app';
  }

  private stateName(state: CallState): string {
    if (state === CallState.CALLING) {
      return 'calling';
    }
    if (state === CallState.ALERTING) {
      return 'alerting';
    }
    if (state === CallState.ANSWERED) {
      return 'answered';
    }
    if (state === CallState.RELEASED) {
      return 'released';
    }
    if (state === CallState.FAILED) {
      return 'failed';
    }
    return 'calling';
  }

  routeName(route: AudioRoute): string {
    if (route === AudioRoute.SPEAKER) {
      return 'speaker';
    }
    if (route === AudioRoute.BLUETOOTH) {
      return 'bluetooth';
    }
    return 'receiver';
  }

  private stringArg(call: MethodCall, key: string): string {
    const v: Object | null = call.argument(key) as Object | null;
    return typeof v === 'string' ? v : '';
  }

  private optionalStringArg(call: MethodCall, key: string): string | null {
    const v: Object | null = call.argument(key) as Object | null;
    if (v === null || v === undefined) {
      return null;
    }
    return typeof v === 'string' ? v : null;
  }

  private boolArg(call: MethodCall, key: string): boolean | null {
    const v: Object | null = call.argument(key) as Object | null;
    if (typeof v === 'boolean') {
      return v;
    }
    return null;
  }

  private argMap(call: MethodCall, key: string): Map<string, Object> | null {
    const raw: Object | null = call.argument(key) as Object | null;
    if (raw !== null && raw instanceof Map) {
      return raw as Map<string, Object>;
    }
    return null;
  }

  private argRecord(call: MethodCall, key: string): Record<string, Object> | null {
    const map = this.argMap(call, key);
    if (map === null) {
      return null;
    }
    const out: Record<string, Object> = {};
    map.forEach((value: Object, k: string) => {
      if (typeof k === 'string' && value !== undefined) {
        out[k] = value;
      }
    });
    return out;
  }
}

class PluginCallStateListener implements CallStateListener {
  private plugin: JjCallkitPlugin;

  constructor(plugin: JjCallkitPlugin) {
    this.plugin = plugin;
  }

  onCallAlerting(callInfo: CallInfo): void {
    this.plugin.emit('callAlerting', this.plugin.callInfoMap(callInfo));
  }

  onCallAnswered(callInfo: CallInfo): void {
    console.info(`[JjCallkit] onCallAnswered callId=${callInfo.callId} state=${callInfo.state}`);
    this.plugin.emit('callAnswered', this.plugin.callInfoMap(callInfo));
  }

  onCallReleased(callInfo: CallInfo, hangupType: number): void {
    const payload = this.plugin.callInfoMap(callInfo);
    payload.set('hangupType', hangupType);
    this.plugin.emit('callReleased', payload);
  }

  onCallFailed(callInfo: CallInfo, errorCode: number, errorMsg: string): void {
    const payload = this.plugin.callInfoMap(callInfo);
    payload.set('errorCode', errorCode);
    payload.set('errorMsg', errorMsg);
    this.plugin.emit('callFailed', payload);
  }

  onDtmfReceived(callInfo: CallInfo, dtmf: string): void {
    const payload = this.plugin.callInfoMap(callInfo);
    payload.set('dtmf', dtmf);
    this.plugin.emit('dtmfReceived', payload);
  }
}

class PluginServerCallListener implements OnServerCallListener {
  private plugin: JjCallkitPlugin;

  constructor(plugin: JjCallkitPlugin) {
    this.plugin = plugin;
  }

  onServerCall(callInfo: CallInfo): void {
    this.plugin.emit('serverCall', this.plugin.callInfoMap(callInfo));
  }
}

class PluginAudioRouteListener implements AudioRouteChangeListener {
  private plugin: JjCallkitPlugin;

  constructor(plugin: JjCallkitPlugin) {
    this.plugin = plugin;
  }

  onAudioRouteChanged(route: AudioRoute): void {
    const payload = new HashMap<string, Object | null>();
    payload.set('route', this.plugin.routeName(route));
    this.plugin.emit('audioRouteChanged', payload);
  }
}

class PluginInitListener implements InitListener {
  private plugin: JjCallkitPlugin;

  constructor(plugin: JjCallkitPlugin) {
    this.plugin = plugin;
  }

  onInitSuccess(): void {
    this.plugin.completeInitSuccess();
  }

  onInitFailed(errorCode: number, errorMsg: string | null): void {
    this.plugin.completeInitFailed(errorCode, errorMsg);
  }
}

class PluginMakeCallCallback implements MakeCallCallback {
  private plugin: JjCallkitPlugin;
  private result: MethodResult;
  private replied: boolean = false;

  constructor(plugin: JjCallkitPlugin, result: MethodResult) {
    this.plugin = plugin;
    this.result = result;
  }

  onSuccess(callInfo: CallInfo): void {
    if (this.replied) {
      return;
    }
    this.replied = true;
    this.plugin.emit('callCalling', this.plugin.callInfoMap(callInfo));
    this.result.success(this.plugin.hashMapToCodecMap(this.plugin.callInfoMap(callInfo)));
  }

  onFailed(errorCode: number, errorMsg: string): void {
    if (this.replied) {
      return;
    }
    this.replied = true;
    this.result.error(`${errorCode}`, errorMsg, null);
  }
}

class PluginAgentConfigListener implements AgentConfigListener {
  private result: MethodResult;
  private plugin: JjCallkitPlugin;
  private returnConfig: boolean;

  constructor(result: MethodResult, plugin: JjCallkitPlugin, returnConfig: boolean) {
    this.result = result;
    this.plugin = plugin;
    this.returnConfig = returnConfig;
  }

  onSuccess(config: AgentConfig | null): void {
    if (this.returnConfig) {
      this.result.success(this.plugin.hashMapToCodecMap(this.plugin.agentConfigMap(config)));
    } else {
      this.result.success(null);
    }
  }

  onFailed(errorMsg: string | null): void {
    this.result.error('-4002', errorMsg, null);
  }
}

class PluginDisplayNumberListener implements DisplayNumberListListener {
  private result: MethodResult;
  private plugin: JjCallkitPlugin;

  constructor(result: MethodResult, plugin: JjCallkitPlugin) {
    this.result = result;
    this.plugin = plugin;
  }

  onSuccess(numbers: DisplayNumber[] | null): void {
    const list: HashMap<string, Object | null>[] = [];
    const src = numbers ?? [];
    for (let i = 0; i < src.length; i++) {
      list.push(this.plugin.displayNumberMap(src[i]));
    }
    this.result.success(this.plugin.hashMapListToCodec(list));
  }

  onFailed(errorMsg: string | null): void {
    this.result.error('-4002', errorMsg, null);
  }
}

class PluginNumberGroupListener implements NumberGroupListListener {
  private result: MethodResult;
  private plugin: JjCallkitPlugin;

  constructor(result: MethodResult, plugin: JjCallkitPlugin) {
    this.result = result;
    this.plugin = plugin;
  }

  onSuccess(response: NumberGroupListResponse | null): void {
    const groups: HashMap<string, Object | null>[] = [];
    const src = response?.list ?? [];
    for (let i = 0; i < src.length; i++) {
      groups.push(this.plugin.numberGroupMap(src[i]));
    }
    const page = response?.page;
    const pageInfo = new Map<string, Object>();
    pageInfo.set('pageSize', page?.pageSize ?? 0);
    pageInfo.set('pageNumber', page?.pageNumber ?? 0);
    pageInfo.set('totalPage', page?.totalPage ?? 0);
    pageInfo.set('total', page?.total ?? 0);
    const out = new Map<string, Object>();
    out.set('list', this.plugin.hashMapListToCodec(groups));
    out.set('pageInfo', pageInfo);
    this.result.success(out);
  }

  onFailed(errorMsg: string | null): void {
    this.result.error('-4002', errorMsg, null);
  }
}
