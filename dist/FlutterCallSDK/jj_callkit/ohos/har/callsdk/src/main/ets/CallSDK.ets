import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { SDKConfig } from './config/SDKConfig';
import { ErrorCode } from './constant/ErrorCode';
import { CallInfo } from './model/CallInfo';
import { LoginInfo, AgentConfig } from './model/SdkModels';
import {
  AgentConfigListener,
  AudioRoute,
  AudioRouteChangeListener,
  CallStateListener,
  DisplayNumberListListener,
  InitListener,
  MakeCallCallback,
  NumberGroupListListener,
  OnServerCallListener
} from './listener/SdkListeners';
import { CallManager } from './manager/CallManager';
import { DisplayNumberManager } from './manager/DisplayNumberManager';
import { NumberGroupManager } from './manager/NumberGroupManager';
import { LoginManager, SavedCredentials } from './manager/LoginManager';
import { SocketManager } from './manager/SocketManager';
import { HttpManager } from './http/HttpManager';
import { PjsipService } from './native/PjsipService';
import { AudioRouteManager } from './utils/AudioRouteManager';
import { CryptoUtils } from './utils/CryptoUtils';
import { PreferencesUtil } from './utils/PreferencesUtil';
import { SdkLogger } from './utils/SdkLogger';
import { SdkCodedError } from './utils/SdkCodedError';
import { SdkCallEventHandler, SdkKickHandler, SdkLoginBridge } from './internal/SdkInternalHandlers';

/**
 * CallSDK 主入口（对齐 Android CallSDK.kt）
 */
export class CallSDK {
  private static initialized: boolean = false;
  private static sdkConfig: SDKConfig | null = null;
  private static appContext: common.Context | null = null;
  private static callStateListeners: CallStateListener[] = [];
  private static onServerCallListener: OnServerCallListener | null = null;
  private static onKickedListener: (() => void) | null = null;
  private static currentCallInfo: CallInfo | null = null;

  static init(context: common.Context, config: SDKConfig, initListener: InitListener): void {
    if (config.username.trim().length === 0) {
      CallSDK.postToMain(() => {
        initListener.onInitFailed(ErrorCode.ACCOUNT_EMPTY, ErrorCode.getErrorMessage(ErrorCode.ACCOUNT_EMPTY));
      });
      return;
    }
    if ((config.password === null || config.password.trim().length === 0) &&
      (config.passwordPk === null || config.passwordPk.trim().length === 0)) {
      CallSDK.postToMain(() => {
        initListener.onInitFailed(ErrorCode.PASSWORD_EMPTY, ErrorCode.getErrorMessage(ErrorCode.PASSWORD_EMPTY));
      });
      return;
    }
    if (config.baseUrl.trim().length === 0) {
      CallSDK.postToMain(() => {
        initListener.onInitFailed(ErrorCode.SERVER_URL_EMPTY, ErrorCode.getErrorMessage(ErrorCode.SERVER_URL_EMPTY));
      });
      return;
    }

    CallSDK.sdkConfig = config;
    CallSDK.appContext = context.getApplicationContext();
    try {
      PreferencesUtil.getInstance().init(CallSDK.appContext);
      HttpManager.getInstance().setBaseUrl(config.baseUrl);
      SdkLogger.configure(
        config.logConfig.enableLog,
        config.logConfig.consoleLogEnabled,
        config.logConfig.fileLoggingEnabled,
        config.logConfig.logLevel,
        config.logConfig.logFilePath
      );
      SdkLogger.init(CallSDK.appContext);
      CallManager.setupNetworkMonitor();
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      CallSDK.postToMain(() => {
        initListener.onInitFailed(ErrorCode.SDK_INIT_FAILED, `SDK 初始化失败: ${msg}`);
      });
      return;
    }

    CallSDK.initialized = true;
    SdkLogger.info('CallSDK', `SDK initialized, enableLog: ${config.logConfig.enableLog}`);

    const eventHandler = new SdkCallEventHandler(
      (action) => { CallSDK.notifyCallState(action); },
      (block) => { CallSDK.postToMain(block); },
      (info) => { CallSDK.currentCallInfo = info; },
      (info) => { CallSDK.onServerCallListener?.onServerCall(info); },
      () => { CallSDK.currentCallInfo = null; }
    );
    CallManager.getInstance().setEventHandler(eventHandler);

    SocketManager.getInstance().setKickHandler(new SdkKickHandler(() => {
      CallSDK.postToMain(() => { CallSDK.onKickedListener?.(); });
    }));

    const loginBridge = new SdkLoginBridge(
      initListener,
      (block) => { CallSDK.postToMain(block); }
    );
    void LoginManager.login(config.username, config.password, config.passwordPk, loginBridge);
  }

  static logout(): void {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'SDK not initialized, skip logout');
      return;
    }
    // 先切断回调，避免销毁过程中 WS/SIP 事件再进业务
    CallSDK.initialized = false;
    try {
      CallManager.getInstance().setEventHandler(null);
      SocketManager.getInstance().setKickHandler(null);
      CallSDK.safeHangup();
      AudioRouteManager.stop();
      LoginManager.logout();
      CallSDK.currentCallInfo = null;
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.error('CallSDK', `logout error: ${msg}`);
      CallSDK.currentCallInfo = null;
    }
  }

  static release(): void {
    if (!CallSDK.initialized) {
      // 仍清理监听器，保证压测/重复 release 安全
      CallSDK.callStateListeners = [];
      CallSDK.onServerCallListener = null;
      CallSDK.onKickedListener = null;
      AudioRouteManager.setAudioRouteChangeListener(null);
      SdkLogger.warn('CallSDK', 'SDK not initialized, skip release core');
      return;
    }
    try {
      CallSDK.logout();
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.error('CallSDK', `release logout error: ${msg}`);
      CallSDK.initialized = false;
    }
    CallSDK.callStateListeners = [];
    CallSDK.onServerCallListener = null;
    CallSDK.onKickedListener = null;
    AudioRouteManager.setAudioRouteChangeListener(null);
    CallSDK.sdkConfig = null;
    CallSDK.appContext = null;
  }

  /** 注销/释放时挂断：吞掉异常，避免 native 异常拖垮宿主 */
  private static safeHangup(): void {
    try {
      CallManager.getInstance().hangupLocal();
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallSDK', `safeHangup: ${msg}`);
    }
  }

  /** 读取上次成功登录的账号密码（logout/release 后仍可用，供 Demo 登录页回填） */
  static getSavedCredentials(context: common.Context): SavedCredentials {
    PreferencesUtil.getInstance().init(context.getApplicationContext());
    return LoginManager.getSavedCredentials();
  }

  static setOnServerCallListener(listener: OnServerCallListener | null): void {
    // 允许 init 前挂载：插件在 CallSDK.init 之前就会 registerPersistentListeners
    CallSDK.onServerCallListener = listener;
  }

  static setOnKickedListener(listener: (() => void) | null): void {
    CallSDK.onKickedListener = listener;
  }

  static addCallStateListener(listener: CallStateListener): void {
    if (!CallSDK.callStateListeners.includes(listener)) {
      CallSDK.callStateListeners.push(listener);
    }
  }

  static removeCallStateListener(listener: CallStateListener): void {
    const idx = CallSDK.callStateListeners.indexOf(listener);
    if (idx >= 0) {
      CallSDK.callStateListeners.splice(idx, 1);
    }
  }

  static setAudioRouteChangeListener(listener: AudioRouteChangeListener | null): void {
    AudioRouteManager.setAudioRouteChangeListener(listener);
  }

  static getCurrentAudioRoute(): AudioRoute {
    return AudioRouteManager.getCurrentRoute();
  }

  static getCurrentCallInfo(): CallInfo | null {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'getCurrentCallInfo called but SDK not initialized');
      return null;
    }
    return CallSDK.currentCallInfo ?? CallManager.readCurrentCall();
  }

  static getCurrentCallId(): string | null {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'getCurrentCallId called but SDK not initialized');
      return null;
    }
    const info = CallSDK.getCurrentCallInfo();
    return info !== null && info.callId !== null && info.callId.length > 0 ? info.callId : null;
  }

  static getLoginInfo(): LoginInfo | null {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'getLoginInfo called but SDK not initialized');
      return null;
    }
    return LoginManager.getLoginInfo();
  }

  static getConfig(): SDKConfig | null {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'getConfig called but SDK not initialized');
      return null;
    }
    return CallSDK.sdkConfig;
  }

  static makeCall(
    phoneNumber: string,
    second: MakeCallCallback | Record<string, Object> | null,
    third?: MakeCallCallback
  ): void {
    let callback: MakeCallCallback;
    let userData: Record<string, Object> | null = null;
    if (third !== undefined) {
      userData = second as Record<string, Object> | null;
      callback = third;
    } else {
      callback = second as MakeCallCallback;
    }
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'makeCall called but SDK not initialized');
      CallSDK.postToMain(() => {
        callback.onFailed(ErrorCode.SDK_NOT_INITIALIZED, ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    if (phoneNumber.trim().length === 0) {
      CallSDK.postToMain(() => {
        callback.onFailed(ErrorCode.CALL_NUMBER_EMPTY, ErrorCode.getErrorMessage(ErrorCode.CALL_NUMBER_EMPTY));
      });
      return;
    }
    if (LoginManager.getLoginInfo() === null) {
      CallSDK.postToMain(() => {
        callback.onFailed(ErrorCode.CALL_NOT_LOGGED_IN, ErrorCode.getErrorMessage(ErrorCode.CALL_NOT_LOGGED_IN));
      });
      return;
    }

    let userDataEncoded: string | null = null;
    if (userData !== null) {
      try {
        const jsonStr = JSON.stringify(userData);
        const bytes = new util.TextEncoder().encode(jsonStr);
        if (bytes.length > 255) {
          CallSDK.postToMain(() => {
            callback.onFailed(ErrorCode.CALL_FAILED_USERDATA_TOO_LARGE,
              ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED_USERDATA_TOO_LARGE));
          });
          return;
        }
        userDataEncoded = CryptoUtils.base64EncodeFromUint8(bytes);
      } catch (e) {
        const msg = (e instanceof Error) ? e.message : String(e);
        CallSDK.postToMain(() => {
          callback.onFailed(ErrorCode.CALL_FAILED_USERDATA_TOO_LARGE, `userData 转换失败: ${msg}`);
        });
        return;
      }
    }

    void CallManager.getInstance().makeOutboundCall(phoneNumber, userDataEncoded).then((info: CallInfo) => {
      CallSDK.currentCallInfo = info;
      CallSDK.postToMain(() => callback.onSuccess(info));
    }).catch((e: Object) => {
      if (e instanceof SdkCodedError) {
        CallSDK.postToMain(() => callback.onFailed(e.code, e.message));
        return;
      }
      const msg = (e instanceof Error) ? e.message : String(e);
      CallSDK.postToMain(() => {
        callback.onFailed(ErrorCode.CALL_FAILED, msg.length > 0 ? msg : ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED));
      });
    });
  }

  static hangupCall(): number {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'hangupCall called but SDK not initialized');
      return ErrorCode.SDK_NOT_INITIALIZED;
    }
    CallManager.getInstance().hangupLocal();
    return 0;
  }

  static sendDTMF(dtmfNumber: string): number {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'sendDTMF called but SDK not initialized');
      return ErrorCode.SDK_NOT_INITIALIZED;
    }
    if (dtmfNumber.length === 0) {
      SdkLogger.warn('CallSDK', 'DTMF number is empty');
      return -1;
    }
    const callId = CallSDK.getCurrentCallId();
    if (callId === null || callId.length === 0) {
      SdkLogger.warn('CallSDK', 'No active call to send DTMF');
      return -1;
    }
    PjsipService.getInstance().sendDtmf(dtmfNumber.charAt(0));
    return 0;
  }

  /**
   * 切换扬声器：只做 OH 系统热切（setDefaultOutputDevice + setCommunicationDevice）。
   * 同步 native g_speakerOn，不 reopen OpenSL（reopen 易把已切好的路由打乱；热切在 NEXT 上已够用）。
   */
  static openLoudSpeaker(open: boolean): number {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'openLoudSpeaker called but SDK not initialized');
      return ErrorCode.SDK_NOT_INITIALIZED;
    }
    void CallSDK.applyLoudSpeakerAsync(open);
    return 0;
  }

  private static async applyLoudSpeakerAsync(open: boolean): Promise<void> {
    try {
      if (open) {
        AudioRouteManager.beginUserSpeakerOn();
        await AudioRouteManager.switchRoute(AudioRoute.SPEAKER);
      } else {
        AudioRouteManager.beginUserSpeakerOff();
        await AudioRouteManager.switchToDetectedRoute();
      }
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.warn('CallSDK', `applyLoudSpeakerAsync OH route: ${msg}`);
    }
    // 只同步标志，避免 setSpeaker 触发 OpenSL reopen
    PjsipService.getInstance().syncSpeakerState(open);
  }

  static isLoudSpeakerOn(): boolean {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'isLoudSpeakerOn called but SDK not initialized');
      return false;
    }
    return AudioRouteManager.getCurrentRoute() === AudioRoute.SPEAKER;
  }

  static openMute(open: boolean): number {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'openMute called but SDK not initialized');
      return ErrorCode.SDK_NOT_INITIALIZED;
    }
    PjsipService.getInstance().setMute(open);
    return 0;
  }

  static isMuteOn(): boolean {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'isMuteOn called but SDK not initialized');
      return false;
    }
    return PjsipService.getInstance().isMuted();
  }

  static disconnectFromCCP(): number {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'disconnectFromCCP called but SDK not initialized');
      return ErrorCode.SDK_NOT_INITIALIZED;
    }
    PjsipService.getInstance().shutdownStack();
    return 0;
  }

  static queryDisplayNumberList(listener: DisplayNumberListListener): void {
    if (!CallSDK.initialized) {
      SdkLogger.warn('CallSDK', 'queryDisplayNumberList called but SDK not initialized');
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    void DisplayNumberManager.getInstance().fetchDisplayNumberList().then((list) => {
      CallSDK.postToMain(() => listener.onSuccess(list));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  static updateAgentSelectNumber(selectNumber: string, listener: AgentConfigListener): void {
    if (!CallSDK.initialized) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    void DisplayNumberManager.getInstance().updateSelectNumber(selectNumber).then((config) => {
      CallSDK.postToMain(() => listener.onSuccess(config));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  static getAgentConfig(listener: AgentConfigListener): void {
    if (!CallSDK.initialized) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    if (LoginManager.getAgentId().length === 0) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.DISPLAY_NUMBER_AGENT_ID_EMPTY));
      });
      return;
    }
    void DisplayNumberManager.getInstance().fetchAgentCallConfig().then((config) => {
      CallSDK.postToMain(() => listener.onSuccess(config));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  static queryNumberGroupList(
    page: number = -1,
    pageSize: number = 999,
    listener: NumberGroupListListener
  ): void {
    if (!CallSDK.initialized) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    void NumberGroupManager.getInstance().fetchNumberGroupList(page, pageSize).then((response) => {
      CallSDK.postToMain(() => listener.onSuccess(response));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  static updateAgentNumberGroupById(numberGroupId: string, listener: AgentConfigListener): void {
    if (!CallSDK.initialized) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    if (LoginManager.getAgentId().length === 0) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.DISPLAY_NUMBER_AGENT_ID_EMPTY));
      });
      return;
    }
    void NumberGroupManager.getInstance().updateNumberGroupById(numberGroupId).then((config) => {
      CallSDK.postToMain(() => listener.onSuccess(config));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  static updateAgentNumberGroupByName(numberGroupName: string, listener: AgentConfigListener): void {
    if (!CallSDK.initialized) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.SDK_NOT_INITIALIZED));
      });
      return;
    }
    if (LoginManager.getAgentId().length === 0) {
      CallSDK.postToMain(() => {
        listener.onFailed(ErrorCode.getErrorMessage(ErrorCode.DISPLAY_NUMBER_AGENT_ID_EMPTY));
      });
      return;
    }
    void NumberGroupManager.getInstance().updateNumberGroupByName(numberGroupName).then((config) => {
      CallSDK.postToMain(() => listener.onSuccess(config));
    }).catch((e: Error) => {
      CallSDK.postToMain(() => listener.onFailed(e.message));
    });
  }

  /** 内部：登录成功后连接 CCP，用于接听来电（对齐 Android connectToCCPInternalForIncoming） */
  private static connectToCCPInternalForIncoming(): void {
    void CallManager.prepareSipForIncoming();
  }

  private static notifyCallState(action: (l: CallStateListener) => void): void {
    const snapshot = CallSDK.callStateListeners.slice();
    CallSDK.postToMain(() => {
      for (let i = 0; i < snapshot.length; i++) {
        action(snapshot[i]);
      }
    });
  }

  private static postToMain(block: () => void): void {
    setTimeout(block, 0);
  }
}
