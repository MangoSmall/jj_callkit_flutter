import { ApiConstants } from '../constant/ApiConstants';
import { SdkConstants } from '../constant/SdkConstants';
import { ErrorCode } from '../constant/ErrorCode';
import { LoginInfo, AgentSummary, AccountSummary, PushServerSummary } from '../model/SdkModels';
import { CryptoUtils } from '../utils/CryptoUtils';
import { DeviceUtils } from '../utils/DeviceUtils';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SdkLogger } from '../utils/SdkLogger';
import { SdkCodedError } from '../utils/SdkCodedError';
import { HttpManager } from '../http/HttpManager';
import { PjsipService } from '../native/PjsipService';
import { SocketManager } from '../manager/SocketManager';

export interface LoginListener {
  onSuccess(): void;
  onFailed(errorCode: number, errorMsg: string): void;
}

export interface SavedCredentials {
  username: string;
  password: string;
}

/**
 * 对齐 callsdk LoginManager：cloudConfig → loginPre → login → loginInfo → refreshWsToken。
 */
export class LoginManager {
  private static loginInfoCache: LoginInfo | null = null;

  static async login(
    username: string,
    password: string | null,
    passwordPk: string | null,
    listener: LoginListener
  ): Promise<void> {
    try {
      const plainPassword = password ?? passwordPk ?? '';
      if (plainPassword.length === 0) {
        listener.onFailed(ErrorCode.PASSWORD_EMPTY, ErrorCode.getErrorMessage(ErrorCode.PASSWORD_EMPTY));
        return;
      }
      const trimmedUsername = username.trim();
      await LoginManager.runLoginChain(trimmedUsername, plainPassword);
      LoginManager.saveCredentials(trimmedUsername, plainPassword);
      LoginManager.loginInfoCache = LoginManager.readLoginInfoFromPrefs();
      SocketManager.getInstance().connect();
      listener.onSuccess();
    } catch (e) {
      if (e instanceof SdkCodedError) {
        SdkLogger.error('LoginManager', e.message);
        listener.onFailed(e.code, e.message);
        return;
      }
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.error('LoginManager', msg);
      listener.onFailed(ErrorCode.SDK_INIT_FAILED, msg);
    }
  }

  static saveCredentials(username: string, password: string): void {
    const prefs = PreferencesUtil.getInstance();
    prefs.putString(SdkConstants.KEY_USER_NAME, username);
    prefs.putString(SdkConstants.KEY_USER_PASSWORD, password);
  }

  static getSavedCredentials(): SavedCredentials {
    const prefs = PreferencesUtil.getInstance();
    const creds: SavedCredentials = {
      username: prefs.getString(SdkConstants.KEY_USER_NAME, ''),
      password: prefs.getString(SdkConstants.KEY_USER_PASSWORD, '')
    };
    return creds;
  }

  static logout(): void {
    SdkLogger.info('LoginManager', 'logout');
    SocketManager.getInstance().disconnectManual();
    try {
      PjsipService.getInstance().shutdownStack();
    } catch (_) {
    }
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_LOGIN_TOKEN);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_SESSION_ID);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_ACCOUNT_ID);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_CLIENT_TYPE);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_WS_TOKEN);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_WS_TIMESTAMP);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_WS_HOST);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_CURRENT_CALL_JSON);
    PreferencesUtil.getInstance().remove(SdkConstants.KEY_SDK_LOGIN_INFO);
    LoginManager.loginInfoCache = null;
  }

  static getLoginInfo(): LoginInfo | null {
    if (LoginManager.loginInfoCache !== null) {
      return LoginManager.loginInfoCache;
    }
    return LoginManager.readLoginInfoFromPrefs();
  }

  static getAgentId(): string {
    const agent = LoginManager.readLoginAgentObject();
    if (agent === null) {
      return '';
    }
    return String(agent['_id'] ?? '');
  }

  static getAccountId(): string {
    const data = LoginManager.readLoginDataObject();
    if (data === null) {
      return '';
    }
    const accountObj = data['account'] as Record<string, Object> | undefined;
    if (accountObj === undefined) {
      return '';
    }
    return String(accountObj['_id'] ?? '');
  }

  private static async runLoginChain(loginName: string, plainPassword: string): Promise<void> {
    const accountName = LoginManager.extractAccountName(loginName);
    await LoginManager.stepCloudConfig(accountName);
    const pk = await LoginManager.stepLoginPre();
    const enc = await CryptoUtils.parsePasswordWithServerPk(pk, plainPassword);
    await LoginManager.stepLoginPost(loginName, enc);
    const loginInfoBody = await LoginManager.stepLoginInfo();
    LoginManager.persistLoginInfo(loginInfoBody);
    await LoginManager.stepRefreshWsToken();
  }

  private static extractAccountName(loginName: string): string {
    const at = loginName.indexOf('@');
    return at >= 0 ? loginName.substring(at + 1) : loginName;
  }

  private static async stepCloudConfig(accountName: string): Promise<void> {
    HttpManager.getInstance().clearContextPath();
    const q = encodeURIComponent(accountName);
    const path = `${ApiConstants.REQUEST_CLOUD_CONFIG}?accountName=${q}`;
    const res = await HttpManager.getInstance().get(path, false);
    if (res.code < 200 || res.code >= 300) {
      throw new Error(`获取云配置失败: HTTP ${res.code}`);
    }
    if (!LoginManager.isApiSuccess(res.body)) {
      throw new Error(LoginManager.getApiMessage(res.body, '获取云配置失败'));
    }
    const dataRaw = LoginManager.getApiDataRaw(res.body);
    const inner = LoginManager.parseJsonObject(dataRaw);
    if (inner !== null) {
      const server = LoginManager.readString(inner, 'server');
      if (server === SdkConstants.CLOUD_SERVER_BJHKDX) {
        HttpManager.getInstance().setContextPath(SdkConstants.CLOUD_CONTEXT_PATH_BJHKDX);
      } else {
        HttpManager.getInstance().clearContextPath();
      }
      let baseURL = LoginManager.readString(inner, 'baseURL');
      if (baseURL.length > 0) {
        if (!baseURL.includes('https://') && !baseURL.includes('http://')) {
          baseURL = `https://${baseURL}`;
        }
        HttpManager.getInstance().setBaseUrl(baseURL);
      }
    }
  }

  private static async stepLoginPre(): Promise<string> {
    const res = await HttpManager.getInstance().get(ApiConstants.REQUEST_LOGIN_PRE, false);
    if (res.code < 200 || res.code >= 300) {
      throw new SdkCodedError(ErrorCode.GET_PUBLIC_KEY_FAILED, `获取公钥失败: HTTP ${res.code}`);
    }
    if (!LoginManager.isApiSuccess(res.body)) {
      throw SdkCodedError.fromApiBody(res.body, ErrorCode.GET_PUBLIC_KEY_FAILED, '获取公钥失败');
    }
    const dataRaw = LoginManager.getApiDataRaw(res.body);
    const inner = LoginManager.parseJsonObject(dataRaw);
    if (inner === null) {
      throw new Error('获取公钥失败: 数据为空');
    }
    const pk = LoginManager.readString(inner, 'pk');
    if (pk.length === 0) {
      throw new Error('获取公钥失败');
    }
    return pk;
  }

  private static async stepLoginPost(loginName: string, encryptedPassword: string): Promise<void> {
    const body: ESObject = {
      'loginName': loginName,
      'clientType': 2,
      'password': encryptedPassword,
      'loginDevice': DeviceUtils.getLoginDevice()
    };
    const res = await HttpManager.getInstance().postObject(ApiConstants.REQUEST_LOGIN, body, false);
    if (res.code < 200 || res.code >= 300) {
      throw new SdkCodedError(ErrorCode.LOGIN_REQUEST_FAILED, `登录请求失败: HTTP ${res.code}`);
    }
    if (!LoginManager.isApiSuccess(res.body)) {
      throw SdkCodedError.fromApiBody(res.body, ErrorCode.LOGIN_AUTH_FAILED, '登录失败');
    }
    const dataRaw = LoginManager.getApiDataRaw(res.body);
    const dataObj = LoginManager.parseJsonObject(dataRaw);
    if (dataObj === null) {
      throw new Error('解析登录响应失败');
    }
    const prefs = PreferencesUtil.getInstance();
    prefs.putString(SdkConstants.KEY_LOGIN_TOKEN, LoginManager.readString(dataObj, SdkConstants.KEY_LOGIN_TOKEN));
    prefs.putString(SdkConstants.KEY_SESSION_ID, LoginManager.readString(dataObj, SdkConstants.KEY_SESSION_ID));
    prefs.putString(SdkConstants.KEY_ACCOUNT_ID, LoginManager.readString(dataObj, SdkConstants.KEY_ACCOUNT_ID));
    prefs.putInt(SdkConstants.KEY_CLIENT_TYPE, LoginManager.readNumber(dataObj, SdkConstants.KEY_CLIENT_TYPE, 2));
  }

  private static async stepLoginInfo(): Promise<string> {
    const res = await HttpManager.getInstance().get(ApiConstants.REQUEST_LOGIN_INFO, true);
    if (res.code < 200 || res.code >= 300) {
      throw new Error(`获取登录信息失败: HTTP ${res.code}`);
    }
    if (!LoginManager.isApiSuccess(res.body)) {
      throw new Error(LoginManager.getApiMessage(res.body, '获取登录信息失败'));
    }
    const dataRaw = LoginManager.getApiDataRaw(res.body);
    const inner = LoginManager.parseJsonObject(dataRaw);
    if (inner !== null) {
      const ps = inner['pushServer'];
      if (Array.isArray(ps) && ps.length > 0) {
        const first = ps[0] as Record<string, string>;
        const wsUrl = first['url'] ?? '';
        if (wsUrl.length > 0) {
          PreferencesUtil.getInstance().putString(SdkConstants.KEY_WS_HOST, wsUrl);
        }
      }
    }
    return res.body;
  }

  private static persistLoginInfo(loginInfoResponseBody: string): void {
    PreferencesUtil.getInstance().putString(SdkConstants.KEY_SDK_LOGIN_INFO, loginInfoResponseBody);
  }

  private static readLoginInfoFromPrefs(): LoginInfo | null {
    const data = LoginManager.readLoginDataObject();
    if (data === null) {
      return null;
    }
    const agentObj = data['agent'] as Record<string, string> | undefined;
    const accountObj = data['account'] as Record<string, string> | undefined;
    let agent: AgentSummary | undefined = undefined;
    if (agentObj !== undefined) {
      agent = {
        _id: String(agentObj['_id'] ?? ''),
        agentNumber: String(agentObj['agentNumber'] ?? ''),
        mobile: String(agentObj['mobile'] ?? '')
      };
    }
    let account: AccountSummary | undefined = undefined;
    if (accountObj !== undefined) {
      account = { _id: String(accountObj['_id'] ?? '') };
    }
    const pushServerRaw = data['pushServer'];
    let pushServer: PushServerSummary[] | undefined = undefined;
    if (Array.isArray(pushServerRaw)) {
      const ps: PushServerSummary[] = [];
      for (let i = 0; i < pushServerRaw.length; i++) {
        const row = pushServerRaw[i] as Record<string, string>;
        ps.push({ url: String(row['url'] ?? '') });
      }
      pushServer = ps;
    }
    return {
      loginToken: String(data['loginToken'] ?? ''),
      agent: agent,
      account: account,
      timestamp: Number(data['timestamp'] ?? 0),
      clientType: Number(data['clientType'] ?? 2),
      pushServer: pushServer
    };
  }

  private static async stepRefreshWsToken(): Promise<void> {
    try {
      const res = await HttpManager.getInstance().get(ApiConstants.REQUEST_REFRESH_WS_TOKEN, true);
      if (res.code < 200 || res.code >= 300 || !LoginManager.isApiSuccess(res.body)) {
        return;
      }
      const dataRaw = LoginManager.getApiDataRaw(res.body);
      const inner = LoginManager.parseJsonObject(dataRaw);
      if (inner === null) {
        return;
      }
      const wsToken = LoginManager.readString(inner, 'wsToken');
      const timestamp = LoginManager.readString(inner, 'timestamp');
      if (wsToken.length > 0 && timestamp.length > 0) {
        const prefs = PreferencesUtil.getInstance();
        prefs.putString(SdkConstants.KEY_WS_TOKEN, wsToken);
        prefs.putString(SdkConstants.KEY_WS_TIMESTAMP, timestamp);
      }
    } catch (e) {
      SdkLogger.warn('LoginManager', `refreshWsToken: ${(e instanceof Error) ? e.message : String(e)}`);
    }
  }

  private static readLoginDataObject(): Record<string, Object> | null {
    try {
      const raw = PreferencesUtil.getInstance().getString(SdkConstants.KEY_SDK_LOGIN_INFO, '');
      if (raw.length === 0) {
        return null;
      }
      const root = JSON.parse(raw) as Record<string, Object>;
      const dataRaw: Object | string | null | undefined = root['data'];
      if (typeof dataRaw === 'string' && dataRaw.length > 0) {
        return JSON.parse(dataRaw) as Record<string, Object>;
      }
      if (typeof dataRaw === 'object' && dataRaw !== null) {
        return dataRaw as Record<string, Object>;
      }
      return root;
    } catch (_) {
      return null;
    }
  }

  private static readLoginAgentObject(): Record<string, Object> | null {
    const data = LoginManager.readLoginDataObject();
    if (data === null) {
      return null;
    }
    const agentObj = data['agent'] as Record<string, Object> | undefined;
    return agentObj ?? null;
  }

  private static isApiSuccess(body: string): boolean {
    try {
      const o = JSON.parse(body) as Record<string, boolean | string | number | Object>;
      return o['success'] === true || o['Succeed'] === true;
    } catch (_) {
      return false;
    }
  }

  private static getApiMessage(body: string, fallback: string): string {
    try {
      const o = JSON.parse(body) as Record<string, string>;
      const m = o['message'] ?? o['Message'] ?? '';
      return m.length > 0 ? m : fallback;
    } catch (_) {
      return fallback;
    }
  }

  private static getApiDataRaw(body: string): string {
    try {
      const o = JSON.parse(body) as Record<string, Object | string>;
      const d = o['data'];
      if (typeof d === 'string') {
        return d;
      }
      if (typeof d === 'object' && d !== null) {
        return JSON.stringify(d);
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  private static parseJsonObject(raw: string): Record<string, Object> | null {
    if (raw.length === 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as Record<string, Object>;
    } catch (_) {
      return null;
    }
  }

  private static readString(o: Record<string, Object>, key: string): string {
    const v = o[key];
    if (typeof v === 'string') {
      return v;
    }
    if (typeof v === 'number') {
      return String(v);
    }
    return '';
  }

  private static readNumber(o: Record<string, Object>, key: string, def: number): number {
    const v = o[key];
    if (typeof v === 'number') {
      return v;
    }
    if (typeof v === 'string') {
      const n = Number(v);
      return Number.isNaN(n) ? def : n;
    }
    return def;
  }
}
