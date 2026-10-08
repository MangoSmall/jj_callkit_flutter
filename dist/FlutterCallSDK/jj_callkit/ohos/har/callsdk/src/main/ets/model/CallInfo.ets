export enum CallDirection {
  APP = 'APP',
  SERVER = 'SERVER'
}

export enum CallState {
  CALLING = 'CALLING',
  ALERTING = 'ALERTING',
  ANSWERED = 'ANSWERED',
  RELEASED = 'RELEASED',
  FAILED = 'FAILED'
}

/** 对齐 Android CallInfo */
export interface CallInfo {
  callId: string | null;
  phoneNumber: string | null;
  direction: CallDirection;
  state: CallState;
  startTime: number;
}
