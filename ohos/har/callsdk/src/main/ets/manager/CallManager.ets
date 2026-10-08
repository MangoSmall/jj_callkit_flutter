import { ApiConstants } from '../constant/ApiConstants';
import { ErrorCode } from '../constant/ErrorCode';
import { SdkConstants } from '../constant/SdkConstants';
import { CallDirection, CallInfo, CallState } from '../model/CallInfo';
import connection from '@ohos.net.connection';
import { HttpManager, HttpTextResult } from '../http/HttpManager';
import { PjsipService } from '../native/PjsipService';
import { AudioRouteManager } from '../utils/AudioRouteManager';
import { CallAudioUtil } from '../utils/CallAudioUtil';
import { getCallFailMessage } from '../utils/CallErrorUtil';
import { SdkCodedError } from '../utils/SdkCodedError';
import { MicPermissionUtil } from '../utils/MicPermissionUtil';
import { NetworkUtil } from '../utils/NetworkUtil';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SdkLogger } from '../utils/SdkLogger';

interface SipDialParams {
  addr: string;
  port: number;
  sipUser: string;
  ctPassword: string;
}

interface RegistrarHostPort {
  addr: string;
  port: number;
}

export interface CallEventHandler {
  onCallAlerting(callInfo: CallInfo): void;
  onCallAnswered(callInfo: CallInfo): void;
  onCallReleased(callInfo: CallInfo, hangupType: number): void;
  onCallFailed(callInfo: CallInfo, errorCode: number, errorMsg: string): void;
  onServerCallIncoming(callInfo: CallInfo): void;
  onDtmfReceived?(callInfo: CallInfo, dtmf: string): void;
}

export interface RemoteCallEventPayload {
  eventType: string;
  callId: string;
  phoneNumber: string;
}

/**
 * 对齐 callsdk CallManager：外呼、Socket 通话状态、SIP 栈管理。
 */
export class CallManager {
  private static instance: CallManager | null = null;
  private static netConn: connection.NetConnection | null = null;
  private static netRegistered: boolean = false;
  private static isNetworkAvailable: boolean = true;
  private static networkLostTimer: number = -1;

  private outboundInProgress: boolean = false;
  private isServerCall: boolean = false;
  private isLocalHangup: boolean = false;
  private eventHandler: CallEventHandler | null = null;

  static getInstance(): CallManager {
    if (CallManager.instance === null) {
      CallManager.instance = new CallManager();
    }
    return CallManager.instance;
  }

  setEventHandler(handler: CallEventHandler | null): void {
    this.eventHandler = handler;
  }

  isOutboundInProgress(): boolean {
    return this.outboundInProgress;
  }

  /** 登录后或来电前预注册 SIP，不发起外呼（内部使用，对齐 Android connectToCCPInternalForIncoming） */
  static async prepareSipForIncoming(): Promise<void> {
    try {
      await CallManager.ensureSipStackReady(false);
      SdkLogger.info('CallManager', 'prepareSipForIncoming ok');
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallManager', `prepareSipForIncoming: ${msg}`);
    }
  }

  static isSipRegistered(): boolean {
    return PjsipService.getInstance().isSipRegistered();
  }

  /** 登录后注册网络监听，通话中断网 3 秒宽限期后触发 onCallFailed */
  static setupNetworkMonitor(): void {
    if (CallManager.netRegistered) {
      return;
    }
    try {
      const nc = connection.createNetConnection();
      nc.register(() => {});
      nc.on('netAvailable', () => {
        CallManager.handleNetworkAvailable();
      });
      nc.on('netLost', () => {
        CallManager.handleNetworkLost();
      });
      CallManager.netConn = nc;
      CallManager.netRegistered = true;
      CallManager.isNetworkAvailable = NetworkUtil.isNetworkConnected();
      SdkLogger.info('CallManager', 'network monitor registered');
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallManager', `setupNetworkMonitor failed: ${msg}`);
    }
  }

  private static handleNetworkLost(): void {
    SdkLogger.warn('CallManager', 'network lost detected');
    CallManager.isNetworkAvailable = false;
    CallManager.scheduleNetworkLostCheck();
  }

  private static handleNetworkAvailable(): void {
    SdkLogger.info('CallManager', 'network available detected');
    CallManager.isNetworkAvailable = true;
    CallManager.cancelNetworkLostCheck();
  }

  private static scheduleNetworkLostCheck(): void {
    CallManager.cancelNetworkLostCheck();
    CallManager.networkLostTimer = setTimeout(() => {
      CallManager.networkLostTimer = -1;
      if (!CallManager.isNetworkAvailable) {
        CallManager.handleCallNetworkLost();
      }
    }, 3000);
  }

  private static cancelNetworkLostCheck(): void {
    if (CallManager.networkLostTimer >= 0) {
      clearTimeout(CallManager.networkLostTimer);
      CallManager.networkLostTimer = -1;
    }
  }

  private static handleCallNetworkLost(): void {
    const current = CallManager.readCurrentCall();
    if (current === null) {
      return;
    }
    if (current.state === CallState.RELEASED || current.state === CallState.FAILED) {
      return;
    }
    const callId = current.callId;
    const errorCode = ErrorCode.CALL_NETWORK_LOST;
    const errorMsg = ErrorCode.getErrorMessage(errorCode);
    SdkLogger.warn('CallManager', `trigger call failed by network lost: callId=${callId}`);
    CallManager.getInstance().finishCallFailed(callId ?? '', errorCode, errorMsg);
  }

  hangupLocal(): void {
    SdkLogger.info('CallManager', 'hangupLocal');
    const cur = CallManager.readCurrentCall();
    if (cur === null) {
      return;
    }
    if (cur.state === CallState.RELEASED || cur.state === CallState.FAILED) {
      PreferencesUtil.getInstance().remove(SdkConstants.KEY_CURRENT_CALL_JSON);
      return;
    }
    this.isLocalHangup = true;
    try {
      PjsipService.getInstance().releaseCall();
    } catch (_) {
      this.finishReleased(cur.callId ?? '', 0);
    }
  }

  async makeOutboundCall(phoneNumber: string, userData: string | null = null): Promise<CallInfo> {
    const raw = phoneNumber.trim();
    if (raw.length === 0) {
      throw new SdkCodedError(ErrorCode.CALL_NUMBER_EMPTY, ErrorCode.getErrorMessage(ErrorCode.CALL_NUMBER_EMPTY));
    }
    this.outboundInProgress = true;
    this.isServerCall = false;
    this.isLocalHangup = false;
    try {
      await CallManager.checkBlackList(raw);
      await CallManager.riskQuery(raw);
      const micOk = await MicPermissionUtil.ensureMicGranted();
      if (!micOk) {
        throw new SdkCodedError(ErrorCode.CALL_PERMISSION_DENIED, ErrorCode.getErrorMessage(ErrorCode.CALL_PERMISSION_DENIED));
      }
      const sip = await CallManager.ensureSipStackReady(true);
      const dest = `sip:${raw}@${sip.addr}:${sip.port}`;
      const callId = PjsipService.getInstance().callMake(dest, userData);
      const info: CallInfo = {
        callId: callId,
        phoneNumber: raw,
        direction: CallDirection.APP,
        state: CallState.CALLING,
        startTime: Date.now()
      };
      PreferencesUtil.getInstance().putString(SdkConstants.KEY_CURRENT_CALL_JSON, JSON.stringify(info));
      SdkLogger.info('CallManager', `makeOutboundCall phone=${raw} callId=${callId}`);
      PjsipService.getInstance().setMute(false);
      void AudioRouteManager.start();
      return info;
    } catch (e) {
      this.outboundInProgress = false;
      if (e instanceof SdkCodedError) {
        throw e;
      }
      const msg = (e instanceof Error) ? e.message : String(e);
      throw new SdkCodedError(ErrorCode.CALL_FAILED, msg.length > 0 ? msg : ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED));
    }
  }

  /**
   * Socket 通话事件。与 Android CallManager.handleServerCallStatus 对齐：
   * - 外呼：状态只信 PJSIP；Socket 除 hangup 外一律忽略，hangup 仅清 outbound 标记
   * - 来电：calling/ring/link/hangup 由 Socket 驱动
   */
  applyRemoteCallEvent(data: RemoteCallEventPayload | undefined): void {
    if (data === undefined) {
      return;
    }
    const eventType = data.eventType;
    const callId = data.callId;
    const phoneNumber = data.phoneNumber;
    if (this.outboundInProgress && eventType !== 'hangup') {
      SdkLogger.info('CallManager', `ignore socket event during outbound: ${eventType}`);
      return;
    }
    if (eventType === 'calling') {
      void CallManager.prepareSipForIncoming();
      this.isServerCall = true;
      const info: CallInfo = {
        callId: callId.length > 0 ? callId : null,
        phoneNumber: phoneNumber.length > 0 ? phoneNumber : null,
        direction: CallDirection.SERVER,
        state: CallState.CALLING,
        startTime: Date.now()
      };
      PreferencesUtil.getInstance().putString(SdkConstants.KEY_CURRENT_CALL_JSON, JSON.stringify(info));
      this.eventHandler?.onServerCallIncoming(info);
      return;
    }
    if (eventType === 'ring') {
      const info = this.updateStoredCallState(CallState.ALERTING, callId);
      if (info !== null) {
        this.eventHandler?.onCallAlerting(info);
      }
      return;
    }
    if (eventType === 'link') {
      void AudioRouteManager.start();
      const info = this.updateStoredCallState(CallState.ANSWERED, callId, true);
      if (info !== null) {
        this.eventHandler?.onCallAnswered(info);
      }
      return;
    }
    if (eventType === 'hangup') {
      AudioRouteManager.stop();
      if (this.outboundInProgress) {
        // 外呼挂断以 PJSIP DISCONNECTED 为准（对齐 Android isMakeCall 分支）
        this.outboundInProgress = false;
        SdkLogger.info('CallManager', `socket hangup during outbound, wait PJSIP callId=${callId}`);
        return;
      }
      if (this.isServerCall) {
        const info = this.snapshotCallWithState(CallState.RELEASED, callId);
        this.isServerCall = false;
        if (info !== null) {
          this.eventHandler?.onCallReleased(info, 1);
        }
      }
    }
  }

  /** PJSIP 原生状态回调 —— 外呼接通/挂断的权威来源 */
  onPjsipStateChanged(callId: string, state: CallState, lastStatus: number): void {
    if (state === CallState.RELEASED) {
      const hangupType = this.isLocalHangup ? 0 : 1;
      this.finishReleased(callId, hangupType);
      return;
    }
    if (state === CallState.FAILED) {
      const sdkCode = ErrorCode.convertCallErrorCode(lastStatus);
      const errorCode = sdkCode !== ErrorCode.UNKNOWN_ERROR ? sdkCode : ErrorCode.CALL_FAILED;
      const errorMsg = sdkCode !== ErrorCode.UNKNOWN_ERROR
        ? ErrorCode.getErrorMessage(sdkCode)
        : getCallFailMessage(lastStatus);
      this.finishCallFailed(callId, errorCode, errorMsg);
      return;
    }
    if (state === CallState.ALERTING) {
      void AudioRouteManager.start();
      const info = this.updateStoredCallState(CallState.ALERTING, callId);
      if (info !== null) {
        SdkLogger.info('CallManager', `ALERTING callId=${callId}`);
        this.eventHandler?.onCallAlerting(info);
      }
      return;
    }
    if (state === CallState.ANSWERED) {
      const info = this.updateStoredCallState(CallState.ANSWERED, callId, true);
      if (info !== null) {
        SdkLogger.info('CallManager', `ANSWERED callId=${callId}`);
        this.eventHandler?.onCallAnswered(info);
      }
    }
  }

  onPjsipDtmfReceived(callId: string, dtmf: string): void {
    const cur = CallManager.readCurrentCall();
    if (cur === null || dtmf.length === 0) {
      return;
    }
    const info: CallInfo = {
      callId: callId.length > 0 ? callId : cur.callId,
      phoneNumber: cur.phoneNumber,
      direction: cur.direction,
      state: cur.state,
      startTime: cur.startTime
    };
    this.eventHandler?.onDtmfReceived?.(info, dtmf);
  }

  private finishReleased(callId: string, hangupType: number): void {
    const info = this.snapshotCallWithState(CallState.RELEASED, callId);
    this.outboundInProgress = false;
    this.isServerCall = false;
    this.isLocalHangup = false;
    AudioRouteManager.stop();
    if (info !== null) {
      SdkLogger.info('CallManager', `RELEASED callId=${callId} hangupType=${hangupType}`);
      this.eventHandler?.onCallReleased(info, hangupType);
    }
  }

  private finishCallFailed(callId: string, errorCode: number, errorMsg: string): void {
    const info = this.snapshotCallWithState(CallState.FAILED, callId);
    this.outboundInProgress = false;
    this.isServerCall = false;
    this.isLocalHangup = false;
    AudioRouteManager.stop();
    try {
      PjsipService.getInstance().releaseCall();
    } catch (_) {
    }
    if (info !== null) {
      SdkLogger.info('CallManager', `FAILED callId=${callId} code=${errorCode}`);
      this.eventHandler?.onCallFailed(info, errorCode, errorMsg);
    }
  }

  private snapshotCallWithState(finalState: CallState, callId: string): CallInfo | null {
    const cur = CallManager.readCurrentCall();
    if (cur === null) {
      return null;
    }
    const info: CallInfo = {
      callId: callId.length > 0 ? callId : cur.callId,
      phoneNumber: cur.phoneNumber,
      direction: cur.direction,
      state: finalState,
      startTime: cur.startTime
    };
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_CURRENT_CALL_JSON);
    return info;
  }

  private updateStoredCallState(state: CallState, callId: string, resetStartTime: boolean = false): CallInfo | null {
    const cur = CallManager.readCurrentCall();
    if (cur === null) {
      return null;
    }
    const info: CallInfo = {
      callId: callId.length > 0 ? callId : cur.callId,
      phoneNumber: cur.phoneNumber,
      direction: cur.direction,
      state: state,
      startTime: resetStartTime ? Date.now() : cur.startTime
    };
    PreferencesUtil.getInstance().putString(SdkConstants.KEY_CURRENT_CALL_JSON, JSON.stringify(info));
    return info;
  }

  onPjsipIncoming(callId: string): void {
    const raw = PreferencesUtil.getInstance().getString(SdkConstants.KEY_CURRENT_CALL_JSON, '');
    if (raw.length === 0) {
      const info: CallInfo = {
        callId: callId,
        phoneNumber: null,
        direction: CallDirection.SERVER,
        state: CallState.CALLING,
        startTime: Date.now()
      };
      PreferencesUtil.getInstance().putString(SdkConstants.KEY_CURRENT_CALL_JSON, JSON.stringify(info));
      this.eventHandler?.onServerCallIncoming(info);
    }
    SdkLogger.info('CallManager', `SIP INCOMING callId=${callId} -> auto accept`);
    void CallManager.autoAcceptIncoming(callId);
  }

  private static async autoAcceptIncoming(callId: string): Promise<void> {
    const micOk = await MicPermissionUtil.ensureMicGranted();
    if (!micOk) {
      SdkLogger.warn('CallManager', 'mic permission denied, skip auto accept');
      return;
    }
    try {
      await CallManager.ensureSipStackReady(false);
      PjsipService.getInstance().callAnswer(200);
      SdkLogger.info('CallManager', `auto accept sent 200 OK callId=${callId}`);
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallManager', `auto accept failed: ${msg}`);
    }
  }

  static readCurrentCall(): CallInfo | null {
    const raw = PreferencesUtil.getInstance().getString(SdkConstants.KEY_CURRENT_CALL_JSON, '');
    if (raw.length === 0) {
      return null;
    }
    try {
      const o = JSON.parse(raw) as Record<string, string | number>;
      const callIdRaw = String(o['callId'] ?? '');
      const phoneRaw = String(o['phoneNumber'] ?? '');
      return {
        callId: callIdRaw.length > 0 ? callIdRaw : null,
        phoneNumber: phoneRaw.length > 0 ? phoneRaw : null,
        direction: (String(o['direction'] ?? 'SERVER') === 'APP') ? CallDirection.APP : CallDirection.SERVER,
        state: CallManager.parseCallState(String(o['state'] ?? 'CALLING')),
        startTime: Number(o['startTime'] ?? Date.now())
      };
    } catch (_) {
      return null;
    }
  }

  private static parseCallState(s: string): CallState {
    switch (s) {
      case CallState.ALERTING:
        return CallState.ALERTING;
      case CallState.ANSWERED:
        return CallState.ANSWERED;
      case CallState.RELEASED:
        return CallState.RELEASED;
      case CallState.FAILED:
        return CallState.FAILED;
      default:
        return CallState.CALLING;
    }
  }

  private static async checkBlackList(phoneNum: string): Promise<void> {
    const body = JSON.stringify({ page: 1, pageSize: 20, number: phoneNum, type: 'outBlackNum' });
    let res: HttpTextResult;
    try {
      res = await HttpManager.getInstance().post(ApiConstants.REQUEST_BLACK_NUM_LIST, body, true);
    } catch {
      return;
    }
    if (res.code < 200 || res.code >= 300) {
      return;
    }
    try {
      const jsonObject = JSON.parse(res.body) as Record<string, Object>;
      if (!CallManager.isApiSuccess(jsonObject)) {
        return;
      }
      const data = jsonObject['data'] as Record<string, Object> | undefined;
      const list = data?.['list'] as Object[] | undefined;
      if (list === undefined || !Array.isArray(list)) {
        return;
      }
      for (let i = 0; i < list.length; i++) {
        const item = list[i] as Record<string, string>;
        if ((item['number'] ?? '') === phoneNum && (item['type'] ?? '') === 'outBlackNum') {
          throw new SdkCodedError(
            ErrorCode.CALL_FAILED_BLACKLIST,
            ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED_BLACKLIST)
          );
        }
      }
    } catch (e) {
      if (e instanceof SdkCodedError) {
        throw e;
      }
    }
  }

  private static async riskQuery(phoneNum: string): Promise<void> {
    const body = JSON.stringify({ number: phoneNum });
    const res = await HttpManager.getInstance().post(ApiConstants.REQUEST_RISK_QUERY, body, true);
    if (res.code < 200 || res.code >= 300) {
      return;
    }
    let jsonObject: Record<string, string | boolean>;
    try {
      jsonObject = JSON.parse(res.body) as Record<string, string | boolean>;
    } catch {
      return;
    }
    const success = jsonObject['success'] === true || jsonObject['Succeed'] === true;
    const code = String(jsonObject['code'] ?? '');
    if (success && code === '200') {
      return;
    }
    const msg = String(jsonObject['message'] ?? jsonObject['Message'] ?? '');
    throw new SdkCodedError(
      ErrorCode.CALL_FAILED_RISK_LIMIT,
      msg.length > 0 ? msg : ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED_RISK_LIMIT)
    );
  }

  static async ensureSipStackReady(refreshAudio: boolean): Promise<SipDialParams> {
    const sip = await CallManager.fetchWebRtcSipParams();
    const pjsip = PjsipService.getInstance();
    if (!pjsip.isReady()) {
      pjsip.epInit(4, 4);
      pjsip.epStart(0);
      pjsip.accAdd(`${sip.addr}:${sip.port}`, sip.sipUser, sip.ctPassword);
    }
    pjsip.applyCallAudioConfigFromPreferences();
    await CallAudioUtil.prepareVoipAudio(false);
    if (refreshAudio) {
      pjsip.epRefreshAudio();
    }
    if (!pjsip.isSipRegistered()) {
      await pjsip.waitForSipRegistration(15000);
    }
    return sip;
  }

  private static async fetchWebRtcSipParams(): Promise<SipDialParams> {
    const res = await HttpManager.getInstance().get(ApiConstants.REQUEST_WEB_RTC_INFO, true);
    if (res.code < 200 || res.code >= 300) {
      throw new SdkCodedError(
        ErrorCode.SIP_CONFIG_FAILED,
        `获取 SIP 配置失败: HTTP ${res.code}`
      );
    }
    const parsed = CallManager.parseSipParamsFromWebRtcBody(res.body);
    if (parsed === null) {
      throw new SdkCodedError(
        ErrorCode.SIP_CONFIG_INCOMPLETE,
        ErrorCode.getErrorMessage(ErrorCode.SIP_CONFIG_INCOMPLETE)
      );
    }
    return parsed;
  }

  private static parseSipParamsFromWebRtcBody(responseStr: string): SipDialParams | null {
    if (responseStr.length === 0) {
      return null;
    }
    let jsonObject: Record<string, string | number | boolean | Object | null | undefined>;
    try {
      jsonObject = JSON.parse(responseStr) as Record<string, string | number | boolean | Object | null | undefined>;
    } catch (_) {
      return null;
    }
    const dataObject = CallManager.extractWebRtcConfigObject(jsonObject);
    if (dataObject === null) {
      return null;
    }
    const sip = CallManager.readScalarString(dataObject, 'sip');
    const ctPassword = CallManager.readScalarString(dataObject, 'ctPassword');
    let registrar = CallManager.readScalarString(dataObject, 'extranalUrl');
    if (registrar.length === 0) {
      registrar = CallManager.readScalarString(dataObject, 'externalUrl');
    }
    if (registrar.length === 0) {
      registrar = CallManager.readScalarString(dataObject, 'registerUrl');
    }
    if (registrar.length === 0) {
      return null;
    }
    const hostPort = CallManager.parseRegistrarHostPort(registrar);
    if (hostPort === null) {
      return null;
    }
    return { addr: hostPort.addr, port: hostPort.port, sipUser: sip, ctPassword: ctPassword };
  }

  private static isWebRtcResponseSuccess(
    obj: Record<string, string | number | boolean | Object | null | undefined>
  ): boolean {
    if (obj['success'] === true || obj['Succeed'] === true) {
      return true;
    }
    const code = obj['code'];
    return code === '200' || code === 200;
  }

  private static extractWebRtcConfigObject(
    jsonObject: Record<string, string | number | boolean | Object | null | undefined>
  ): Record<string, string | number | boolean> | null {
    const hasRootSipShape =
      jsonObject['registerUrl'] !== undefined ||
      jsonObject['sip'] !== undefined ||
      jsonObject['extranalUrl'] !== undefined ||
      jsonObject['externalUrl'] !== undefined;
    if (!CallManager.isWebRtcResponseSuccess(jsonObject)) {
      return hasRootSipShape ? CallManager.collectScalarFields(jsonObject) : null;
    }
    const d = jsonObject['data'];
    if (typeof d === 'string' && d.length > 0) {
      try {
        const inner = JSON.parse(d) as Record<string, string | number | boolean | Object | null | undefined>;
        return CallManager.collectScalarFields(inner);
      } catch (_) {
        return null;
      }
    }
    if (typeof d === 'object' && d !== null && !Array.isArray(d)) {
      return CallManager.collectScalarFields(d as Record<string, string | number | boolean | Object | null | undefined>);
    }
    return hasRootSipShape ? CallManager.collectScalarFields(jsonObject) : null;
  }

  private static collectScalarFields(
    src: Record<string, string | number | boolean | Object | null | undefined>
  ): Record<string, string | number | boolean> {
    const out: Record<string, string | number | boolean> = {};
    const keys = Object.keys(src);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = src[k];
      if (v !== undefined && v !== null && typeof v !== 'object') {
        out[k] = v as string | number | boolean;
      }
    }
    return out;
  }

  private static readScalarString(obj: Record<string, string | number | boolean>, key: string): string {
    const v = obj[key];
    return v === undefined || v === null ? '' : String(v);
  }

  private static parseRegistrarHostPort(raw: string): RegistrarHostPort | null {
    let s = raw.trim();
    if (s.length === 0) {
      return null;
    }
    const lower = s.toLowerCase();
    if (lower.startsWith('sip:')) {
      s = s.substring(4);
    } else if (lower.startsWith('sips:')) {
      s = s.substring(5);
    }
    const semi = s.indexOf(';');
    if (semi >= 0) {
      s = s.substring(0, semi);
    }
    const lastColon = s.lastIndexOf(':');
    if (lastColon <= 0 || lastColon >= s.length - 1) {
      return null;
    }
    const port = Number(s.substring(lastColon + 1));
    if (Number.isNaN(port)) {
      return null;
    }
    let hostPart = s.substring(0, lastColon);
    const at = hostPart.lastIndexOf('@');
    if (at >= 0) {
      hostPart = hostPart.substring(at + 1);
    }
    if (hostPart.length === 0) {
      return null;
    }
    return { addr: hostPart, port: port };
  }

  private static isApiSuccess(o: Record<string, Object>): boolean {
    return o['success'] === true || o['Succeed'] === true;
  }
}
