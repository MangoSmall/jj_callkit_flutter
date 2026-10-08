import { ApiConstants } from '../constant/ApiConstants';
import { AgentConfig, DisplayNumber } from '../model/SdkModels';
import { AgentConfigParser } from '../utils/AgentConfigParser';
import { httpGetMessage, httpGetSuccess } from '../utils/HttpResponseUtil';
import { HttpManager } from '../http/HttpManager';
import { LoginManager } from './LoginManager';

interface AgentCallConfigBody {
  selectNumber: string;
}

interface AgentUpdateRequest {
  _id: string;
  agentCallConfig: AgentCallConfigBody;
}

export class DisplayNumberManager {
  private static instance: DisplayNumberManager | null = null;

  static getInstance(): DisplayNumberManager {
    if (DisplayNumberManager.instance === null) {
      DisplayNumberManager.instance = new DisplayNumberManager();
    }
    return DisplayNumberManager.instance;
  }

  async fetchDisplayNumberList(): Promise<DisplayNumber[]> {
    const res = await HttpManager.getInstance().get(ApiConstants.REQUEST_DISPLAY_NUMBER_LIST, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '获取外显号码失败'));
    }
    return DisplayNumberManager.parseListBody(res.body);
  }

  async fetchAgentCallConfig(): Promise<AgentConfig> {
    const agentId = LoginManager.getAgentId();
    if (agentId.length === 0) {
      throw new Error('无法获取坐席 ID');
    }
    const url = `${ApiConstants.REQUEST_AGENT_GET_FULL}?agentId=${encodeURIComponent(agentId)}`;
    const res = await HttpManager.getInstance().get(url, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '获取座席配置失败'));
    }
    return AgentConfigParser.parseFromResponseBody(res.body);
  }

  async updateSelectNumber(selectNumber: string): Promise<AgentConfig> {
    const agentId = LoginManager.getAgentId();
    if (agentId.length === 0) {
      throw new Error('无法获取坐席 ID');
    }
    const callConfig: AgentCallConfigBody = { selectNumber: selectNumber };
    const updateReq: AgentUpdateRequest = { _id: agentId, agentCallConfig: callConfig };
    const body = JSON.stringify(updateReq);
    const res = await HttpManager.getInstance().post(ApiConstants.REQUEST_AGENT_UPDATE, body, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '设置外显号码失败'));
    }
    return AgentConfigParser.parseFromResponseBody(res.body);
  }

  private static parseListBody(body: string): DisplayNumber[] {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'];
    if (!Array.isArray(data)) {
      return [];
    }
    const out: DisplayNumber[] = [];
    for (let i = 0; i < data.length; i++) {
      const row = data[i] as Record<string, string | number>;
      const number = String(row['number'] ?? '');
      const id = String(row['id'] ?? number);
      if (number.length === 0 && id.length === 0) {
        continue;
      }
      out.push({
        id: id.length > 0 ? id : null,
        status: DisplayNumberManager.strOrNull(row['status']),
        number: number.length > 0 ? number : (id.length > 0 ? id : null),
        ivrId: DisplayNumberManager.strOrNull(row['ivrId']),
        province: DisplayNumberManager.strOrNull(row['province']),
        city: DisplayNumberManager.strOrNull(row['city']),
        line: DisplayNumberManager.strOrNull(row['line']),
        lineState: DisplayNumberManager.intOrNull(row['lineState']),
        abbreviation: DisplayNumberManager.strOrNull(row['abbreviation'])
      });
    }
    return out;
  }

  private static strOrNull(v: string | number | undefined): string | null {
    if (v === undefined || v === null) {
      return null;
    }
    const s = String(v);
    return s.length > 0 ? s : null;
  }

  private static intOrNull(v: string | number | undefined): number | null {
    if (v === undefined || v === null) {
      return null;
    }
    const n = Number(v);
    return Number.isNaN(n) ? null : n;
  }
}
