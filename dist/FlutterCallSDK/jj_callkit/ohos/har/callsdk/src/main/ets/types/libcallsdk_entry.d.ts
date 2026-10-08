/** HAR 内 libcallsdk_entry.so：dlopen libpjsua2_ohos.so 并 re-export 全部 PJSIP N-API */
declare module 'libcallsdk_entry.so' {
  interface Pjsua2OhosLib {
    epInit(logLevel: number, consoleLevel: number): number;
    epStart(udpPort: number): number;
    epRefreshAudio(): number;
    epApplyAudioConfig(ecOn: boolean, nsOn: boolean, agcOn: boolean): number;
    epDestroy(): number;
    accAdd(sipServerHostPort: string, sipUser: string, password: string): number;
    accDel(): number;
    callMake(destSipUri: string, userData?: string): string;
    callAnswer(statusCode?: number): number;
    callHangup(): number;
    setSpeaker(speaker: boolean): number;
    setMute(mute: boolean): number;
    sendDtmf(digits: string): number;
    bindPjsipEvents(cb: (json: string) => void): number;
    onPjsipJsonEvent(cb: (json: string) => void): number;
  }
  const lib: Pjsua2OhosLib;
  export default lib;
}

export {};
