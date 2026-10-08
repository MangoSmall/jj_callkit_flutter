import { CallInfo } from '../model/CallInfo';
import { AgentConfig, DisplayNumber, NumberGroupListResponse } from '../model/SdkModels';

export interface InitListener {
  onInitSuccess(): void;
  onInitFailed(errorCode: number, errorMsg: string | null): void;
}

export interface MakeCallCallback {
  onSuccess(callInfo: CallInfo): void;
  onFailed(errorCode: number, errorMsg: string): void;
}

/** 对齐 Android CallStateListener：默认空实现用可选方法 */
export interface CallStateListener {
  onCallAlerting?(callInfo: CallInfo): void;
  onCallAnswered?(callInfo: CallInfo): void;
  onCallReleased?(callInfo: CallInfo, hangupType: number): void;
  onCallFailed?(callInfo: CallInfo, errorCode: number, errorMsg: string): void;
  onDtmfReceived?(callInfo: CallInfo, dtmf: string): void;
}

export interface OnServerCallListener {
  onServerCall(callInfo: CallInfo): void;
}

export interface DisplayNumberListListener {
  onSuccess(numbers: DisplayNumber[] | null): void;
  onFailed(errorMsg: string | null): void;
}

export interface NumberGroupListListener {
  onSuccess(response: NumberGroupListResponse | null): void;
  onFailed(errorMsg: string | null): void;
}

export interface AgentConfigListener {
  onSuccess(config: AgentConfig | null): void;
  onFailed(errorMsg: string | null): void;
}

export enum AudioRoute {
  RECEIVER = 'RECEIVER',
  SPEAKER = 'SPEAKER',
  BLUETOOTH = 'BLUETOOTH'
}

export interface AudioRouteChangeListener {
  onAudioRouteChanged(route: AudioRoute): void;
}
