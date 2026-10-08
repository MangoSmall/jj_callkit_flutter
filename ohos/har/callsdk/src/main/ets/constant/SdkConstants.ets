/** SDK 内部常量，对齐 Android callsdk EasyConstant */

export class SdkConstants {
  static readonly PREFERENCES_NAME: string = 'callsdk_sp';

  static readonly ENV_PRODUCTION: string = 'production';
  static readonly ENV_DEV: string = 'dev';

  static readonly DEFAULT_BASE_URL: string = 'https://app.useasy.cn';
  static readonly DEV_BASE_URL: string = 'https://dev1.useasy.cn';

  static readonly CLOUD_SERVER_BJHKDX: string = 'bjhkdx';
  static readonly CLOUD_CONTEXT_PATH_BJHKDX: string = '/ykf/cc';

  static readonly KEY_SESSION_ID: string = 'sessionId';
  static readonly KEY_LOGIN_TOKEN: string = 'loginToken';
  static readonly KEY_ACCOUNT_ID: string = 'accountId';
  static readonly KEY_CLIENT_TYPE: string = 'clientType';
  static readonly KEY_WS_TOKEN: string = 'wsToken';
  static readonly KEY_WS_TIMESTAMP: string = 'timestamp';
  static readonly KEY_WS_HOST: string = 'WS_HOST';
  static readonly KEY_SDK_LOGIN_INFO: string = 'sdk_login_info';
  static readonly KEY_CURRENT_CALL_JSON: string = 'current_call_json';
  /** 对齐主 App / Android SP：退出登录保留，供登录页回填 */
  static readonly KEY_USER_NAME: string = 'userName';
  static readonly KEY_USER_PASSWORD: string = 'user_password';

  static readonly KEY_AUDIO_AGC_ENABLED: string = 'audio_agc_enabled';
  static readonly KEY_AUDIO_EC_ENABLED: string = 'audio_ec_enabled';
  static readonly KEY_AUDIO_NS_ENABLED: string = 'audio_ns_enabled';
  static readonly KEY_AUDIO_AGC_MODE: string = 'audio_agc_mode';
  static readonly KEY_AUDIO_EC_MODE: string = 'audio_ec_mode';
  static readonly KEY_AUDIO_NS_MODE: string = 'audio_ns_mode';
  static readonly KEY_AGENT_SELECT_NUMBER: string = 'agent_select_number';
  static readonly KEY_AGENT_NUMBER_GROUP_ID: string = 'agent_number_group_id';
  static readonly KEY_AGENT_NUMBER_GROUP_NAME: string = 'agent_number_group_name';
}
