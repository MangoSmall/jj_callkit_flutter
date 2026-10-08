import http from '@ohos.net.http';
import { SdkConstants } from '../constant/SdkConstants';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { SdkLogger } from '../utils/SdkLogger';
import { httpGetMessage, httpGetSuccess } from '../utils/HttpResponseUtil';

export interface HttpTextResult {
  readonly code: number;
  readonly body: string;
}

export class HttpManager {
  private static instance: HttpManager | null = null;
  private baseUrl: string = SdkConstants.DEFAULT_BASE_URL;
  private contextPath: string = '';

  static getInstance(): HttpManager {
    if (HttpManager.instance === null) {
      HttpManager.instance = new HttpManager();
    }
    return HttpManager.instance;
  }

  setBaseUrl(url: string): void {
    let u = url.trim();
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    this.baseUrl = u;
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  setContextPath(path: string): void {
    let p = path.trim();
    if (p.length === 0) {
      this.contextPath = '';
      return;
    }
    if (!p.startsWith('/')) {
      p = `/${p}`;
    }
    if (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    this.contextPath = p;
  }

  clearContextPath(): void {
    this.contextPath = '';
  }

  private resolveUrl(pathOrUrl: string): string {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    const path = pathOrUrl.startsWith('/') ? pathOrUrl : `/${pathOrUrl}`;
    return `${this.baseUrl}${this.contextPath}${path}`;
  }

  private buildAuthHeaders(): Record<string, string> {
    const loginToken = PreferencesUtil.getInstance().getString(SdkConstants.KEY_LOGIN_TOKEN, '');
    const sessionId = PreferencesUtil.getInstance().getString(SdkConstants.KEY_SESSION_ID, '');
    const clientType = String(PreferencesUtil.getInstance().getInt(SdkConstants.KEY_CLIENT_TYPE, 2));
    return {
      'Connection': 'keep-alive',
      'logintoken': loginToken,
      'sessionid': sessionId,
      'clienttype': clientType,
      'Accept-Language': 'zh-CN'
    };
  }

  async get(pathOrUrl: string, withAuth: boolean = true): Promise<HttpTextResult> {
    const url = this.resolveUrl(pathOrUrl);
    const headers: Record<string, string> = withAuth ? this.buildAuthHeaders() : {
      'Connection': 'keep-alive',
      'Accept-Language': 'zh-CN'
    };
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      });
      const body = typeof resp.result === 'string' ? resp.result : String(resp.result);
      return { code: resp.responseCode, body: body };
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.error('HttpManager', `GET error: ${msg}`);
      throw new Error(msg);
    } finally {
      req.destroy();
    }
  }

  async post(pathOrUrl: string, jsonBody: string, withAuth: boolean = true): Promise<HttpTextResult> {
    const url = this.resolveUrl(pathOrUrl);
    const headers: Record<string, string> = withAuth ? this.buildAuthHeaders() : {
      'Connection': 'keep-alive',
      'Accept-Language': 'zh-CN'
    };
    headers['Content-Type'] = 'application/json; charset=utf-8';
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: jsonBody,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000
      });
      const body = typeof resp.result === 'string' ? resp.result : String(resp.result);
      return { code: resp.responseCode, body: body };
    } catch (e) {
      const msg = (e instanceof Error) ? e.message : String(e);
      SdkLogger.error('HttpManager', `POST error: ${msg}`);
      throw new Error(msg);
    } finally {
      req.destroy();
    }
  }

  async postObject(pathOrUrl: string, body: ESObject, withAuth: boolean = true): Promise<HttpTextResult> {
    return await this.post(pathOrUrl, JSON.stringify(body), withAuth);
  }
}
