import { CallEventHandler, CallManager } from '../manager/CallManager';
import { LoginListener } from '../manager/LoginManager';
import { SocketKickHandler } from '../manager/SocketManager';
import { CallInfo } from '../model/CallInfo';
import { CallStateListener, InitListener } from '../listener/SdkListeners';
import { SdkLogger } from '../utils/SdkLogger';

export class SdkCallEventHandler implements CallEventHandler {
  private readonly notifyCallState: (action: (l: CallStateListener) => void) => void;
  private readonly postToMain: (block: () => void) => void;
  private readonly setCurrentCall: (info: CallInfo) => void;
  private readonly notifyServerCall: (info: CallInfo) => void;
  private readonly clearCurrentCall: () => void;

  constructor(
    notifyCallState: (action: (l: CallStateListener) => void) => void,
    postToMain: (block: () => void) => void,
    setCurrentCall: (info: CallInfo) => void,
    notifyServerCall: (info: CallInfo) => void,
    clearCurrentCall: () => void
  ) {
    this.notifyCallState = notifyCallState;
    this.postToMain = postToMain;
    this.setCurrentCall = setCurrentCall;
    this.notifyServerCall = notifyServerCall;
    this.clearCurrentCall = clearCurrentCall;
  }

  onCallAlerting(callInfo: CallInfo): void {
    this.setCurrentCall(callInfo);
    this.notifyCallState((l: CallStateListener) => {
      l.onCallAlerting(callInfo);
    });
  }

  onCallAnswered(callInfo: CallInfo): void {
    this.setCurrentCall(callInfo);
    this.notifyCallState((l: CallStateListener) => {
      l.onCallAnswered(callInfo);
    });
  }

  onCallReleased(callInfo: CallInfo, hangupType: number): void {
    this.clearCurrentCall();
    this.notifyCallState((l: CallStateListener) => {
      l.onCallReleased(callInfo, hangupType);
    });
  }

  onCallFailed(callInfo: CallInfo, errorCode: number, errorMsg: string): void {
    this.clearCurrentCall();
    this.notifyCallState((l: CallStateListener) => {
      l.onCallFailed(callInfo, errorCode, errorMsg);
    });
  }

  onServerCallIncoming(callInfo: CallInfo): void {
    this.setCurrentCall(callInfo);
    this.postToMain(() => { this.notifyServerCall(callInfo); });
  }

  onDtmfReceived(callInfo: CallInfo, dtmf: string): void {
    this.notifyCallState((l: CallStateListener) => {
      l.onDtmfReceived(callInfo, dtmf);
    });
  }
}

export class SdkKickHandler implements SocketKickHandler {
  private readonly kicked: () => void;

  constructor(kicked: () => void) {
    this.kicked = kicked;
  }

  onKicked(): void {
    this.kicked();
  }
}

export class SdkLoginBridge implements LoginListener {
  private readonly initListener: InitListener;
  private readonly postToMain: (block: () => void) => void;

  constructor(
    initListener: InitListener,
    postToMain: (block: () => void) => void
  ) {
    this.initListener = initListener;
    this.postToMain = postToMain;
  }

  onSuccess(): void {
    // 与文档一致：init Future 等到 SIP 预注册完成（失败仅打日志，不挡登录成功）
    void (async () => {
      try {
        await CallManager.prepareSipForIncoming();
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        SdkLogger.warn('SdkLoginBridge', `prepareSipForIncoming after login: ${msg}`);
      }
      this.postToMain(() => { this.initListener.onInitSuccess(); });
    })();
  }

  onFailed(errorCode: number, errorMsg: string): void {
    this.postToMain(() => { this.initListener.onInitFailed(errorCode, errorMsg); });
  }
}
