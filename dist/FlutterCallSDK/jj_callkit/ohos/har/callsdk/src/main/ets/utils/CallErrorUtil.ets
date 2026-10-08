import { ErrorCode } from '../constant/ErrorCode';

/** 对齐 Android ErrorCode.convertCallErrorCode + getErrorMessage */
export function getCallFailMessage(lastStatus: number): string {
  const sdkCode = ErrorCode.convertCallErrorCode(lastStatus);
  if (sdkCode !== ErrorCode.UNKNOWN_ERROR) {
    return ErrorCode.getErrorMessage(sdkCode);
  }
  let sipCode = lastStatus;
  if (lastStatus >= 175000 && lastStatus <= 175999) {
    sipCode = lastStatus - 175000;
  }
  if (sipCode >= 400) {
    return ErrorCode.sipStatusDescription(sipCode);
  }
  return ErrorCode.getErrorMessage(ErrorCode.CALL_FAILED);
}
