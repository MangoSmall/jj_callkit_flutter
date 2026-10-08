/**
 * 错误码常量（与 Android callsdk / iOS JJCallKit 对齐）
 */

export class ErrorCode {
  static readonly UNKNOWN_ERROR: number = -9999;

  static readonly SDK_INIT_FAILED: number = -1;
  static readonly SDK_NOT_INITIALIZED: number = -2;
  static readonly PJSIP_CREATE_FAILED: number = -3;
  static readonly PJSIP_INIT_FAILED: number = -4;
  static readonly TRANSPORT_CREATE_FAILED: number = -5;
  static readonly PJSIP_START_FAILED: number = -6;

  static readonly INVALID_ACCOUNT: number = -100;
  static readonly INVALID_PASSWORD: number = -101;
  static readonly ACCOUNT_FORMAT_ERROR: number = -104;
  static readonly ACCOUNT_EMPTY: number = -105;
  static readonly PASSWORD_EMPTY: number = -106;
  static readonly SERVER_URL_EMPTY: number = -107;
  static readonly TOKEN_EMPTY: number = -108;

  static readonly LOGIN_REQUEST_FAILED: number = -200;
  static readonly LOGIN_AUTH_FAILED: number = -201;
  static readonly LOGIN_FAILED_WRONG_CREDENTIALS: number = -202;
  static readonly SOCKET_CONNECT_FAILED: number = -203;
  static readonly SIP_CONFIG_FAILED: number = -205;
  static readonly SIP_CONFIG_INCOMPLETE: number = -206;
  static readonly SIP_REGISTER_FAILED: number = -207;
  static readonly SIP_REGISTER_REJECTED: number = -209;
  static readonly LOGIN_FAILED_ACCOUNT_FROZEN: number = -210;
  static readonly AGENT_DISABLED: number = -211;
  static readonly ACCOUNT_NOT_FOUND: number = -212;
  static readonly AGENT_NOT_FOUND: number = -213;
  static readonly SIP_REGISTER_NOT_FOUND: number = -215;
  static readonly SIP_REGISTER_SERVER_ERROR: number = -216;
  static readonly GET_PUBLIC_KEY_FAILED: number = -217;

  static readonly CALL_FAILED: number = -300;
  static readonly CALL_PERMISSION_DENIED: number = -301;
  static readonly CALL_NOT_LOGGED_IN: number = -302;
  static readonly CALL_NUMBER_EMPTY: number = -303;
  static readonly CALL_REJECTED: number = -304;
  static readonly CALL_NUMBER_NOT_FOUND: number = -305;
  static readonly CALL_USER_BUSY: number = -306;
  static readonly CALL_REQUEST_TERMINATED: number = -307;
  static readonly CALL_TIMEOUT: number = -308;
  static readonly CALL_TEMPORARILY_UNAVAILABLE: number = -309;
  static readonly CALL_FAILED_BLACKLIST: number = -310;
  static readonly CALL_FAILED_RISK_LIMIT: number = -311;
  static readonly CALL_FAILED_USERDATA_TOO_LARGE: number = -312;
  static readonly CALL_NOT_ACCEPTABLE: number = -313;
  static readonly CALL_REGISTRATION_DROPPED: number = -314;
  static readonly CALL_NOT_EXIST: number = -315;
  static readonly CALL_ADDRESS_INCOMPLETE: number = -316;
  static readonly CALL_DECLINED: number = -317;
  static readonly CALL_BUSY_EVERYWHERE: number = -318;
  static readonly CALL_SERVER_ERROR: number = -319;
  static readonly CALL_BAD_GATEWAY: number = -320;
  static readonly CALL_SERVICE_UNAVAILABLE: number = -321;
  static readonly CALL_SERVER_TIMEOUT: number = -322;
  static readonly CALL_NETWORK_LOST: number = -323;

  static readonly NETWORK_TIMEOUT: number = -401;

  static readonly HTTP_INVALID_URL: number = -2001;
  static readonly HTTP_ERROR: number = -2007;
  static readonly HTTP_EMPTY_RESPONSE: number = -2008;
  static readonly HTTP_JSON_PARSE_FAILED: number = -2009;

  static readonly WS_INVALID_URL: number = -2100;
  static readonly WS_CONNECT_FAILED: number = -2101;

  static readonly DISPLAY_NUMBER_AGENT_ID_EMPTY: number = -4001;
  static readonly DISPLAY_NUMBER_CONFIG_FAILED: number = -4002;

  private static readonly loginErrorCodeMap: Map<string, number> = new Map([
    ['02010022', ErrorCode.LOGIN_FAILED_WRONG_CREDENTIALS],
    ['02010036', ErrorCode.LOGIN_FAILED_ACCOUNT_FROZEN],
    ['02010026', ErrorCode.AGENT_DISABLED],
    ['02010024', ErrorCode.ACCOUNT_NOT_FOUND],
    ['02010025', ErrorCode.AGENT_NOT_FOUND]
  ]);

  private static readonly sipCodeMap: Map<number, number> = new Map([
    [400, ErrorCode.CALL_FAILED],
    [401, ErrorCode.CALL_FAILED],
    [403, ErrorCode.CALL_REJECTED],
    [404, ErrorCode.CALL_NUMBER_NOT_FOUND],
    [408, ErrorCode.CALL_TIMEOUT],
    [477, ErrorCode.CALL_REGISTRATION_DROPPED],
    [480, ErrorCode.CALL_TEMPORARILY_UNAVAILABLE],
    [481, ErrorCode.CALL_NOT_EXIST],
    [484, ErrorCode.CALL_ADDRESS_INCOMPLETE],
    [486, ErrorCode.CALL_USER_BUSY],
    [487, ErrorCode.CALL_REQUEST_TERMINATED],
    [488, ErrorCode.CALL_NOT_ACCEPTABLE],
    [500, ErrorCode.CALL_SERVER_ERROR],
    [502, ErrorCode.CALL_BAD_GATEWAY],
    [503, ErrorCode.CALL_SERVICE_UNAVAILABLE],
    [504, ErrorCode.CALL_SERVER_TIMEOUT],
    [600, ErrorCode.CALL_BUSY_EVERYWHERE],
    [603, ErrorCode.CALL_DECLINED]
  ]);

  private static readonly errorMessageMap: Map<number, string> = new Map([
    [ErrorCode.UNKNOWN_ERROR, '未知错误'],
    [ErrorCode.SDK_INIT_FAILED, 'SDK 初始化失败'],
    [ErrorCode.SDK_NOT_INITIALIZED, 'SDK 未初始化'],
    [ErrorCode.PJSIP_CREATE_FAILED, 'PJSIP 创建失败'],
    [ErrorCode.PJSIP_INIT_FAILED, 'PJSIP 初始化失败'],
    [ErrorCode.TRANSPORT_CREATE_FAILED, '传输层创建失败'],
    [ErrorCode.PJSIP_START_FAILED, 'PJSIP 启动失败'],
    [ErrorCode.INVALID_ACCOUNT, '账号无效'],
    [ErrorCode.INVALID_PASSWORD, '密码无效'],
    [ErrorCode.ACCOUNT_FORMAT_ERROR, '账号格式错误'],
    [ErrorCode.ACCOUNT_EMPTY, '账号为空'],
    [ErrorCode.PASSWORD_EMPTY, '密码为空'],
    [ErrorCode.SERVER_URL_EMPTY, '服务器 URL 为空'],
    [ErrorCode.TOKEN_EMPTY, 'Token 为空'],
    [ErrorCode.LOGIN_REQUEST_FAILED, '登录请求失败'],
    [ErrorCode.LOGIN_AUTH_FAILED, '登录认证失败'],
    [ErrorCode.LOGIN_FAILED_WRONG_CREDENTIALS, '登录失败，账号或密码错误'],
    [ErrorCode.SOCKET_CONNECT_FAILED, 'Socket 连接失败'],
    [ErrorCode.SIP_CONFIG_FAILED, '获取 SIP 配置失败'],
    [ErrorCode.SIP_CONFIG_INCOMPLETE, 'SIP 配置信息不完整'],
    [ErrorCode.SIP_REGISTER_FAILED, 'SIP 注册失败'],
    [ErrorCode.SIP_REGISTER_REJECTED, 'SIP 注册被拒绝'],
    [ErrorCode.LOGIN_FAILED_ACCOUNT_FROZEN, '由于多次登录失败，您的账号已被冻结，请联系管理员解冻'],
    [ErrorCode.AGENT_DISABLED, '坐席已停用'],
    [ErrorCode.ACCOUNT_NOT_FOUND, '账户未找到'],
    [ErrorCode.AGENT_NOT_FOUND, '坐席未找到'],
    [ErrorCode.SIP_REGISTER_NOT_FOUND, 'SIP 注册未找到'],
    [ErrorCode.SIP_REGISTER_SERVER_ERROR, 'SIP 注册服务器错误'],
    [ErrorCode.GET_PUBLIC_KEY_FAILED, '获取公钥失败'],
    [ErrorCode.CALL_FAILED, '呼叫失败'],
    [ErrorCode.CALL_PERMISSION_DENIED, '通话权限被拒绝'],
    [ErrorCode.CALL_NOT_LOGGED_IN, '未登录无法呼叫'],
    [ErrorCode.CALL_NUMBER_EMPTY, '呼叫号码为空'],
    [ErrorCode.CALL_REJECTED, '呼叫被拒绝'],
    [ErrorCode.CALL_NUMBER_NOT_FOUND, '号码不存在'],
    [ErrorCode.CALL_USER_BUSY, '用户忙线'],
    [ErrorCode.CALL_REQUEST_TERMINATED, '对方拒接或手机软件拦截'],
    [ErrorCode.CALL_TIMEOUT, '呼叫超时'],
    [ErrorCode.CALL_TEMPORARILY_UNAVAILABLE, '被叫暂时不可用'],
    [ErrorCode.CALL_FAILED_BLACKLIST, '号码在黑名单中，无法拨打'],
    [ErrorCode.CALL_FAILED_RISK_LIMIT, '呼叫次数已达上限'],
    [ErrorCode.CALL_FAILED_USERDATA_TOO_LARGE, 'userData 超过 255 字节限制'],
    [ErrorCode.CALL_NOT_ACCEPTABLE, '媒体协商失败'],
    [ErrorCode.CALL_REGISTRATION_DROPPED, 'SIP 注册掉线'],
    [ErrorCode.CALL_NOT_EXIST, '通话不存在'],
    [ErrorCode.CALL_ADDRESS_INCOMPLETE, '号码不完整'],
    [ErrorCode.CALL_DECLINED, '对方拒绝接听'],
    [ErrorCode.CALL_BUSY_EVERYWHERE, '全局忙线'],
    [ErrorCode.CALL_SERVER_ERROR, '服务器内部错误'],
    [ErrorCode.CALL_BAD_GATEWAY, '网关错误'],
    [ErrorCode.CALL_SERVICE_UNAVAILABLE, '服务不可用'],
    [ErrorCode.CALL_SERVER_TIMEOUT, '服务器超时'],
    [ErrorCode.CALL_NETWORK_LOST, '通话中网络中断'],
    [ErrorCode.NETWORK_TIMEOUT, '网络超时'],
    [ErrorCode.HTTP_INVALID_URL, '无效 URL'],
    [ErrorCode.HTTP_ERROR, 'HTTP 请求错误'],
    [ErrorCode.HTTP_EMPTY_RESPONSE, '空响应数据'],
    [ErrorCode.HTTP_JSON_PARSE_FAILED, 'JSON 解析失败'],
    [ErrorCode.WS_INVALID_URL, '无效的 CallSdkWebSocket URL'],
    [ErrorCode.WS_CONNECT_FAILED, 'CallSdkWebSocket 连接失败'],
    [ErrorCode.DISPLAY_NUMBER_AGENT_ID_EMPTY, '坐席 ID 为空'],
    [ErrorCode.DISPLAY_NUMBER_CONFIG_FAILED, '获取外显号码配置失败']
  ]);

  static convertErrorCode(serverCode: string | null | undefined): number {
    if (serverCode === null || serverCode === undefined || serverCode.length === 0) {
      return ErrorCode.UNKNOWN_ERROR;
    }
    const mapped = ErrorCode.loginErrorCodeMap.get(serverCode);
    return mapped !== undefined ? mapped : ErrorCode.UNKNOWN_ERROR;
  }

  static convertCallErrorCode(reasonCode: number | null | undefined): number {
    if (reasonCode === null || reasonCode === undefined) {
      return ErrorCode.UNKNOWN_ERROR;
    }
    const direct = ErrorCode.sipCodeMap.get(reasonCode);
    if (direct !== undefined) {
      return direct;
    }
    if (reasonCode >= 175000 && reasonCode <= 175999) {
      const sipCode = reasonCode - 175000;
      const mapped = ErrorCode.sipCodeMap.get(sipCode);
      if (mapped !== undefined) {
        return mapped;
      }
    }
    return ErrorCode.UNKNOWN_ERROR;
  }

  static getErrorMessage(errorCode: number): string {
    const msg = ErrorCode.errorMessageMap.get(errorCode);
    return msg !== undefined ? msg : '未知错误';
  }

  static sipStatusDescription(sipCode: number): string {
    switch (sipCode) {
      case 100:
        return '100 Trying - 正在尝试';
      case 180:
        return '180 Ringing - 振铃中';
      case 200:
        return '200 OK - 成功';
      case 400:
        return '400 Bad CallSdkRequest - 请求格式错误';
      case 401:
        return '401 Unauthorized - 认证失败';
      case 403:
        return '403 Forbidden - 禁止访问';
      case 404:
        return '404 Not Found - 未找到';
      case 408:
        return '408 CallSdkRequest Timeout - 请求超时';
      case 477:
        return '477 Registration Dropped - SIP 注册掉线';
      case 480:
        return '480 Temporarily Unavailable - 暂时不可用';
      case 481:
        return '481 Call/Transaction Does Not Exist - 通话不存在';
      case 484:
        return '484 Address Incomplete - 号码不完整';
      case 486:
        return '486 Busy Here - 用户忙线';
      case 487:
        return '487 CallSdkRequest Terminated - 请求已终止';
      case 488:
        return '488 Not Acceptable Here - 媒体协商失败';
      case 500:
        return '500 Internal Server Error - 服务器内部错误';
      case 502:
        return '502 Bad Gateway - 网关错误';
      case 503:
        return '503 Service Unavailable - 服务不可用';
      case 504:
        return '504 Server Timeout - 服务器超时';
      case 600:
        return '600 Busy Everywhere - 全局忙线';
      case 603:
        return '603 Decline - 拒绝接听';
      default:
        return `${sipCode} Unknown - 未知状态码`;
    }
  }
}
