/// <reference path="../types/libcallsdk_entry.d.ts" />

import callsdkEntryNative from 'libcallsdk_entry.so';
import { SdkConstants } from '../constant/SdkConstants';
import { CallDirection, CallInfo, CallState } from '../model/CallInfo';
import { CallManager } from '../manager/CallManager';
import { CallAudioUtil } from '../utils/CallAudioUtil';
import { getCallFailMessage } from '../utils/CallErrorUtil';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SdkLogger } from '../utils/SdkLogger';

interface Pjsua2NativeApi {
  epInit(logLevel: number, consoleLevel: number): number;
  epStart(udpPort: number): number;
  epRefreshAudio(): number;
  epApplyAudioConfig(ecOn: boolean, nsOn: boolean, agcOn: boolean): number;
  epDestroy(): number;
  accAdd(sipServerHostPort: string, sipUser: string, password: string): number;
  callMake(destSipUri: string, userData?: string): string;
  callAnswer(statusCode?: number): number;
  callHangup(): number;
  setSpeaker(speaker: boolean): number;
  setMute(mute: boolean): number;
  sendDtmf(digits: string): number;
  bindPjsipEvents(cb: (json: string) => void): number;
  onPjsipJsonEvent(cb: (json: string) => void): number;
}

interface RegWaitEntry {
  resolve: () => void;
  reject: (err: Error) => void;
}

export class PjsipService {
  private static instance: PjsipService | null = null;
  /** 进程内只绑定一次，shutdown 后仍保留供 epInit 复用 */
  private static boundNativeModule: Pjsua2NativeApi | null = null;
  private initialized: boolean = false;
  private accountReady: boolean = false;
  private sipRegistered: boolean = false;
  private wasRegistered: boolean = false;
  private sipReconnectTimer: number = -1;
  private nativeBound: boolean = false;
  private muted: boolean = false;
  private speakerOn: boolean = false;
  private regWaiters: RegWaitEntry[] = [];

  static getInstance(): PjsipService {
    if (PjsipService.instance === null) {
      PjsipService.instance = new PjsipService();
    }
    return PjsipService.instance;
  }

  /**
   * 可选：手动注入 Native（一般无需调用）。
   * 默认由 HAR 内 `libcallsdk_entry.so` 自动加载并 re-export。
   */
  static bindPjsipNativeModule(mod: Object): void {
    PjsipService.boundNativeModule = PjsipService.validateNative(mod);
  }

  private static validateNative(mod: Object): Pjsua2NativeApi {
    const rec = mod as Record<string, Object | string>;
    if (typeof rec['epInit'] !== 'function') {
      throw new Error('PJSIP 原生库导出不完整（libcallsdk_entry.so / libpjsua2_ohos.so）');
    }
    return mod as Pjsua2NativeApi;
  }

  private static obtainNative(): Pjsua2NativeApi {
    if (PjsipService.boundNativeModule !== null) {
      return PjsipService.boundNativeModule;
    }
    // HAR 自带 stub：import 时已 dlopen pjsua2 并挂上 N-API
    PjsipService.boundNativeModule = PjsipService.validateNative(callsdkEntryNative as Object);
    return PjsipService.boundNativeModule;
  }

  private static tryGetNative(): Pjsua2NativeApi | null {
    try {
      return PjsipService.obtainNative();
    } catch (_) {
      return null;
    }
  }

  epInit(workerCnt: number, ioqueueCnt: number): void {
    const p = PjsipService.obtainNative();
    this.ensureEventListener(p);
    p.epInit(workerCnt, ioqueueCnt);
    this.initialized = true;
  }

  epStart(startFlags: number): void {
    PjsipService.obtainNative().epStart(startFlags);
  }

  epRefreshAudio(): void {
    try {
      PjsipService.obtainNative().epRefreshAudio();
    } catch (e) {
      SdkLogger.warn('PjsipService', `epRefreshAudio: ${(e instanceof Error) ? e.message : String(e)}`);
    }
  }

  applyCallAudioConfigFromPreferences(): void {
    const p = PjsipService.obtainNative();
    const prefs = PreferencesUtil.getInstance();
    try {
      p.epApplyAudioConfig(
        prefs.getBoolean(SdkConstants.KEY_AUDIO_EC_ENABLED, true),
        prefs.getBoolean(SdkConstants.KEY_AUDIO_NS_ENABLED, true),
        prefs.getBoolean(SdkConstants.KEY_AUDIO_AGC_ENABLED, true)
      );
    } catch (_) {
    }
  }

  accAdd(registrarHostPort: string, sipUser: string, ctPassword: string): void {
    this.sipRegistered = false;
    this.rejectRegWaiters(new Error('SIP 账号重新注册'));
    PjsipService.obtainNative().accAdd(registrarHostPort, sipUser, ctPassword);
    this.accountReady = true;
  }

  isSipRegistered(): boolean {
    return this.sipRegistered;
  }

  waitForSipRegistration(timeoutMs: number = 15000): Promise<void> {
    if (this.sipRegistered) {
      return Promise.resolve();
    }
    return new Promise((resolve, reject) => {
      const entry: RegWaitEntry = {
        resolve: (): void => {
          clearTimeout(timerId);
          resolve();
        },
        reject: (err: Error): void => {
          clearTimeout(timerId);
          reject(err);
        }
      };
      this.regWaiters.push(entry);
      const timerId = setTimeout((): void => {
        this.removeRegWaiter(entry);
        reject(new Error('SIP 注册超时，请检查网络后重试'));
      }, timeoutMs);
    });
  }

  callAnswer(statusCode: number = 200): void {
    const rc = PjsipService.obtainNative().callAnswer(statusCode);
    if (rc !== 0) {
      throw new Error(`callAnswer failed: ${rc}`);
    }
  }

  callMake(sipUri: string, userData: string | null = null): string {
    const p = PjsipService.obtainNative();
    if (userData !== null && userData.length > 0) {
      return p.callMake(sipUri, userData);
    }
    return p.callMake(sipUri);
  }

  releaseCall(): void {
    const p = PjsipService.tryGetNative();
    if (p === null) {
      return;
    }
    try {
      p.callHangup();
      this.muted = false;
      this.speakerOn = false;
      void CallAudioUtil.endVoipSession();
    } catch (_) {
    }
  }

  setMute(mute: boolean): void {
    this.muted = mute;
    const p = PjsipService.tryGetNative();
    if (p !== null) {
      try {
        p.setMute(mute);
      } catch (_) {
      }
    }
  }

  isMuted(): boolean {
    return this.muted;
  }

  sendDtmf(digits: string): void {
    const p = PjsipService.tryGetNative();
    if (p !== null) {
      try {
        p.sendDtmf(digits);
      } catch (_) {
      }
    }
  }

  applyNativeSpeaker(speaker: boolean): void {
    const p = PjsipService.tryGetNative();
    if (p !== null) {
      try {
        // 新 so：OH 上仅同步 g_speakerOn / setDefaultOutputDevice，不再 reopen
        p.setSpeaker(speaker);
      } catch (_) {
      }
    }
    this.speakerOn = speaker;
  }

  async setSpeakerRoute(speaker: boolean): Promise<boolean> {
    const ok = await CallAudioUtil.setSpeakerRoute(speaker);
    // OH 路由失败时仍走 Native（模拟器常见 system error）
    this.applyNativeSpeaker(speaker);
    return ok;
  }

  isSpeakerOn(): boolean {
    return this.speakerOn;
  }

  syncSpeakerState(speaker: boolean): void {
    this.speakerOn = speaker;
  }

  shutdownStack(): void {
    // 先停重连，避免 epDestroy 后定时器仍触发 prepareSipForIncoming
    this.clearSipReconnectTimer();
    this.wasRegistered = false;
    this.sipRegistered = false;
    this.initialized = false;
    this.accountReady = false;
    this.rejectRegWaiters(new Error('SIP 栈已关闭'));

    const p = PjsipService.tryGetNative();
    if (p !== null) {
      try {
        p.epDestroy();
      } catch (_) {
      }
    }
    this.nativeBound = false;
    this.muted = false;
    this.speakerOn = false;
    try {
      void CallAudioUtil.endVoipSession();
    } catch (_) {
    }
  }

  private clearSipReconnectTimer(): void {
    if (this.sipReconnectTimer >= 0) {
      clearTimeout(this.sipReconnectTimer);
      this.sipReconnectTimer = -1;
    }
  }

  isReady(): boolean {
    return this.initialized && this.accountReady;
  }

  private ensureEventListener(p: Pjsua2NativeApi): void {
    if (this.nativeBound) {
      return;
    }
    const onJson = (json: string): void => {
      PjsipService.getInstance().onNativeEventJson(json);
    };
    try {
      p.onPjsipJsonEvent(onJson);
      this.nativeBound = true;
      return;
    } catch (_) {
    }
    try {
      p.bindPjsipEvents(onJson);
      this.nativeBound = true;
    } catch (_) {
    }
  }

  private onNativeEventJson(json: string): void {
    if (json.length === 0) {
      return;
    }
    let root: Record<string, string | number | boolean>;
    try {
      root = JSON.parse(json) as Record<string, string | number | boolean>;
    } catch (_) {
      return;
    }
    const t = String(root['type'] ?? '');
    if (t === 'reg_state') {
      this.onRegStateChanged(root['active'] === true, Number(root['status'] ?? 0));
      return;
    }
    if (t !== 'call_state') {
      if (t === 'dtmf') {
        const callId = String(root['callId'] ?? '');
        const dtmf = String(root['digit'] ?? root['dtmf'] ?? '');
        CallManager.getInstance().onPjsipDtmfReceived(callId, dtmf);
      }
      return;
    }
    const callId = String(root['callId'] ?? '');
    // 兼容字段名：正式 JSON 用 pjsipState，部分日志/旧路径可能用 state
    const pjsipState = String(root['pjsipState'] ?? root['state'] ?? '');
    const lastStatus = Number(root['lastStatus'] ?? 0);
    SdkLogger.info('PjsipService', `call_state callId=${callId} pjsipState=${pjsipState} lastStatus=${lastStatus}`);
    if (pjsipState === 'INCOMING') {
      CallManager.getInstance().onPjsipIncoming(callId);
      return;
    }
    const mapped = PjsipService.mapPjsipToCallState(pjsipState, lastStatus);
    if (mapped !== null) {
      CallManager.getInstance().onPjsipStateChanged(callId, mapped, lastStatus);
    }
  }

  private scheduleSipReconnect(): void {
    if (this.sipReconnectTimer >= 0) {
      return;
    }
    if (!this.initialized || !this.wasRegistered) {
      return;
    }
    SdkLogger.warn('PjsipService', 'SIP registration lost, schedule reconnect in 3s');
    this.sipReconnectTimer = setTimeout((): void => {
      this.sipReconnectTimer = -1;
      if (!this.initialized || this.sipRegistered) {
        return;
      }
      SdkLogger.info('PjsipService', 'SIP auto reconnect');
      void CallManager.prepareSipForIncoming();
    }, 3000);
  }

  private onRegStateChanged(active: boolean, status: number): void {
    const codeClass = Math.floor(status / 100);
    SdkLogger.info('PjsipService', `reg_state active=${active} status=${status}`);
    if (active && codeClass === 2) {
      this.sipRegistered = true;
      this.wasRegistered = true;
      this.resolveRegWaiters();
      return;
    }
    this.sipRegistered = false;
    if (status === 0) {
      return;
    }
    if (this.wasRegistered && !active) {
      this.scheduleSipReconnect();
    }
    if (codeClass >= 4 || (codeClass === 3 && this.regWaiters.length > 0)) {
      this.rejectRegWaiters(new Error(`SIP 注册失败 (${status})`));
    }
  }

  private resolveRegWaiters(): void {
    const pending = this.regWaiters;
    this.regWaiters = [];
    for (let i = 0; i < pending.length; i++) {
      pending[i].resolve();
    }
  }

  private rejectRegWaiters(err: Error): void {
    const pending = this.regWaiters;
    this.regWaiters = [];
    for (let i = 0; i < pending.length; i++) {
      pending[i].reject(err);
    }
  }

  private removeRegWaiter(entry: RegWaitEntry): void {
    const next: RegWaitEntry[] = [];
    for (let i = 0; i < this.regWaiters.length; i++) {
      if (this.regWaiters[i] !== entry) {
        next.push(this.regWaiters[i]);
      }
    }
    this.regWaiters = next;
  }

  private static mapPjsipToCallState(pjsipState: string, lastStatus: number): CallState | null {
    switch (pjsipState) {
      case 'CALLING':
        return CallState.CALLING;
      case 'EARLY':
        return CallState.ALERTING;
      case 'CONNECTING':
      case 'CONFIRMED':
        return CallState.ANSWERED;
      case 'DISCONNECTED':
        return PjsipService.isNormalDisconnect(lastStatus) ? CallState.RELEASED : CallState.FAILED;
      default:
        return null;
    }
  }

  /** 对齐 Android：200/487/603 为正常结束 */
  private static isNormalDisconnect(lastStatus: number): boolean {
    if (lastStatus === 0 || lastStatus === 200) {
      return true;
    }
    let sipCode = lastStatus;
    if (lastStatus >= 175000 && lastStatus <= 175999) {
      sipCode = lastStatus - 175000;
    }
    return sipCode === 200 || sipCode === 487 || sipCode === 603;
  }
}
