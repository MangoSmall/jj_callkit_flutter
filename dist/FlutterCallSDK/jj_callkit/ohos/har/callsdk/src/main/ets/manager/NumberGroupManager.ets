import { ApiConstants } from '../constant/ApiConstants';
import { SdkConstants } from '../constant/SdkConstants';
import { AgentConfig, NumberGroup, NumberGroupListResponse, PageInfo } from '../model/SdkModels';
import { AgentConfigParser } from '../utils/AgentConfigParser';
import { httpGetMessage, httpGetSuccess } from '../utils/HttpResponseUtil';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { HttpManager } from '../http/HttpManager';
import { LoginManager } from './LoginManager';

interface NumberGroupQueryBody {
  page: number;
  pageSize: number;
}

interface AgentNumberGroupBody {
  numberGroup?: string;
  numberGroupName?: string;
}

interface AgentUpdateNumberGroupRequest {
  _id: string;
  agentCallConfig: AgentNumberGroupBody;
}

export class NumberGroupManager {
  private static instance: NumberGroupManager | null = null;

  static getInstance(): NumberGroupManager {
    if (NumberGroupManager.instance === null) {
      NumberGroupManager.instance = new NumberGroupManager();
    }
    return NumberGroupManager.instance;
  }

  async fetchNumberGroupList(page: number = -1, pageSize: number = 999): Promise<NumberGroupListResponse> {
    const req: NumberGroupQueryBody = { page: page, pageSize: pageSize };
    const body = JSON.stringify(req);
    const res = await HttpManager.getInstance().post(ApiConstants.REQUEST_NUMBER_GROUP_QUERY, body, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '获取号码组列表失败'));
    }
    return NumberGroupManager.parseListBody(res.body);
  }

  async updateNumberGroupById(numberGroupId: string): Promise<AgentConfig> {
    const agentId = LoginManager.getAgentId();
    if (agentId.length === 0) {
      throw new Error('无法获取坐席 ID');
    }
    const callConfig: AgentNumberGroupBody = { numberGroup: numberGroupId };
    const updateReq: AgentUpdateNumberGroupRequest = { _id: agentId, agentCallConfig: callConfig };
    const body = JSON.stringify(updateReq);
    const res = await HttpManager.getInstance().post(ApiConstants.REQUEST_AGENT_UPDATE, body, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '设置号码组失败'));
    }
    PreferencesUtil.getInstance().putString(SdkConstants.KEY_AGENT_NUMBER_GROUP_ID, numberGroupId);
    return AgentConfigParser.parseFromResponseBody(res.body);
  }

  async updateNumberGroupByName(numberGroupName: string): Promise<AgentConfig> {
    const agentId = LoginManager.getAgentId();
    if (agentId.length === 0) {
      throw new Error('无法获取坐席 ID');
    }
    const callConfig: AgentNumberGroupBody = { numberGroupName: numberGroupName };
    const updateReq: AgentUpdateNumberGroupRequest = { _id: agentId, agentCallConfig: callConfig };
    const body = JSON.stringify(updateReq);
    const res = await HttpManager.getInstance().post(ApiConstants.REQUEST_AGENT_UPDATE, body, true);
    if (res.code < 200 || res.code >= 300 || !httpGetSuccess(res.body)) {
      throw new Error(httpGetMessage(res.body, '设置号码组失败'));
    }
    PreferencesUtil.getInstance().putString(SdkConstants.KEY_AGENT_NUMBER_GROUP_NAME, numberGroupName);
    return AgentConfigParser.parseFromResponseBody(res.body);
  }

  private static parseListBody(body: string): NumberGroupListResponse {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'] as Record<string, Object> | undefined;
    if (data === undefined) {
      return { list: [], page: null };
    }
    const listRaw = data['list'];
    const pageRaw = data['page'] as Record<string, number> | undefined;
    const list: NumberGroup[] = [];
    if (Array.isArray(listRaw)) {
      for (let i = 0; i < listRaw.length; i++) {
        const row = listRaw[i] as Record<string, string | string[] | number>;
        const id = String(row['id'] ?? '');
        if (id.length === 0) {
          continue;
        }
        list.push({
          id: id,
          accountId: NumberGroupManager.strOrNull(row['accountId']),
          numberList: NumberGroupManager.strListOrNull(row['numberList']),
          strategy: NumberGroupManager.strOrNull(row['strategy']),
          createTime: NumberGroupManager.strOrNull(row['createTime']),
          createAgent: NumberGroupManager.strOrNull(row['createAgent']),
          updateTime: NumberGroupManager.strOrNull(row['updateTime']),
          updateAgent: NumberGroupManager.strOrNull(row['updateAgent']),
          groupName: NumberGroupManager.strOrNull(row['groupName'] ?? row['name']),
          remark: NumberGroupManager.strOrNull(row['remark']),
          city: NumberGroupManager.strOrNull(row['city']),
          areaCode: NumberGroupManager.strOrNull(row['areaCode']),
          defaultNumberList: NumberGroupManager.strListOrNull(row['defaultNumberList']),
          overflowGroupId: NumberGroupManager.strOrNull(row['overflowGroupId'])
        });
      }
    }
    let page: PageInfo | null = null;
    if (pageRaw !== undefined) {
      page = {
        pageSize: NumberGroupManager.intOrNull(pageRaw['pageSize']),
        pageNumber: NumberGroupManager.intOrNull(pageRaw['pageNumber']),
        totalPage: NumberGroupManager.intOrNull(pageRaw['totalPage']),
        total: NumberGroupManager.intOrNull(pageRaw['total'])
      };
    }
    return { list: list, page: page };
  }

  private static strOrNull(v: string | number | string[] | undefined): string | null {
    if (v === undefined || v === null || Array.isArray(v)) {
      return null;
    }
    const s = String(v);
    return s.length > 0 ? s : null;
  }

  private static intOrNull(v: number | undefined): number | null {
    if (v === undefined || v === null) {
      return null;
    }
    return Number.isNaN(v) ? null : v;
  }

  private static strListOrNull(v: string | string[] | number | undefined): string[] | null {
    if (!Array.isArray(v)) {
      return null;
    }
    const out: string[] = [];
    for (let i = 0; i < v.length; i++) {
      out.push(String(v[i]));
    }
    return out;
  }
}
