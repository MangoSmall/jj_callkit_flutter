/** 对齐 callsdk HttpManager API 路径（SDK 子集） */

export class ApiConstants {
  static readonly REQUEST_CLOUD_CONFIG: string = '/api/platform/public/cloudConfig';
  static readonly REQUEST_LOGIN_PRE: string = '/api/platform/public/loginPre';
  static readonly REQUEST_LOGIN: string = '/api/platform/public/login';
  static readonly REQUEST_LOGIN_INFO: string = '/api/platform/action/loginInfo';
  static readonly REQUEST_REFRESH_WS_TOKEN: string = '/api/platform/action/refreshWsToken/';
  static readonly REQUEST_RISK_QUERY: string = '/api/call/api/risk/query';
  static readonly REQUEST_WEB_RTC_INFO: string = '/api/call/api/sip/webrtc/config/query/';
  static readonly REQUEST_NUMBER_GROUP_QUERY: string =
    '/api/call/web/call/action/config/number/group/v1/query';
  static readonly REQUEST_DISPLAY_NUMBER_LIST: string = '/api/call/web/config/number/display/cache';
  static readonly REQUEST_AGENT_UPDATE: string = '/api/platform/action/agent/update';
  static readonly REQUEST_AGENT_GET_FULL: string = '/api/platform/action/agent/getFullAgent';
  static readonly REQUEST_BLACK_NUM_LIST: string = '/api/call/web/blackNum/list';
}
