import { ErrorCode } from '../constant/ErrorCode';

/** 携带 SDK 错误码的异常（ArkTS 须继承 Error 方可 throw） */
export class SdkCodedError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }

  static fromApiBody(body: string, fallbackCode: number, fallbackMsg: string): SdkCodedError {
    try {
      const o = JSON.parse(body) as Record<string, string>;
      const serverCode = String(o['code'] ?? '');
      const msg = String(o['message'] ?? o['Message'] ?? '');
      const sdkCode = ErrorCode.convertErrorCode(serverCode);
      const finalCode = sdkCode !== ErrorCode.UNKNOWN_ERROR ? sdkCode : fallbackCode;
      const finalMsg = msg.length > 0 ? msg : ErrorCode.getErrorMessage(finalCode);
      return new SdkCodedError(finalCode, finalMsg);
    } catch (_) {
      return new SdkCodedError(fallbackCode, fallbackMsg);
    }
  }
}
