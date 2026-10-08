import { SdkConstants } from '../constant/SdkConstants';
import { AgentCallConfig, AgentConfig, AgentImConfig } from '../model/SdkModels';
import { PreferencesUtil } from './PreferencesUtil';

export class AgentConfigParser {
  static parseFromResponseBody(body: string): AgentConfig {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'] as Record<string, Object> | undefined;
    if (data === undefined) {
      return AgentConfigParser.emptyConfig();
    }
    return AgentConfigParser.parseFromAgentData(data);
  }

  static parseFromAgentData(data: Record<string, Object>): AgentConfig {
    const callCfg = AgentConfigParser.parseAgentCallConfig(
      data['agentCallConfig'] as Record<string, Object | string[] | boolean | number | null | undefined> | undefined
    );
    const imCfg = AgentConfigParser.parseAgentImConfig(
      data['agentImConfig'] as Record<string, Object | number | string | null | undefined> | undefined
    );
    if (callCfg !== null) {
      if (callCfg.selectNumber !== null && callCfg.selectNumber.length > 0) {
        PreferencesUtil.getInstance().putString(SdkConstants.KEY_AGENT_SELECT_NUMBER, callCfg.selectNumber);
      }
      if (callCfg.numberGroup !== null && callCfg.numberGroup.length > 0) {
        PreferencesUtil.getInstance().putString(SdkConstants.KEY_AGENT_NUMBER_GROUP_ID, callCfg.numberGroup);
      }
    }
    return {
      _id: AgentConfigParser.readString(data['_id']),
      accountId: AgentConfigParser.readString(data['accountId']),
      agentName: AgentConfigParser.readString(data['agentName']),
      icon: AgentConfigParser.readString(data['icon']),
      mobile: AgentConfigParser.readString(data['mobile']),
      email: AgentConfigParser.readString(data['email']),
      agentNumber: AgentConfigParser.readString(data['agentNumber']),
      pinyin: AgentConfigParser.readString(data['pinyin']),
      status: AgentConfigParser.readInt(data['status']),
      agentCallConfig: callCfg,
      agentImConfig: imCfg,
      groups: AgentConfigParser.readStringList(data['groups']),
      roles: AgentConfigParser.readStringList(data['roles']),
      versionId: AgentConfigParser.readString(data['versionId']),
      crmId: AgentConfigParser.readString(data['crmId']),
      createTime: AgentConfigParser.readString(data['createTime']),
      createAgent: AgentConfigParser.readString(data['createAgent']),
      updateTime: AgentConfigParser.readString(data['updateTime']),
      updateAgent: AgentConfigParser.readString(data['updateAgent'])
    };
  }

  private static parseAgentCallConfig(
    raw: Record<string, Object | string[] | boolean | number | null | undefined> | undefined
  ): AgentCallConfig | null {
    if (raw === undefined) {
      return null;
    }
    return {
      loginType: AgentConfigParser.readStringList(raw['loginType']),
      restTime: AgentConfigParser.readInt(raw['restTime']),
      numbers: AgentConfigParser.readStringList(raw['numbers']),
      numberSelect: AgentConfigParser.readBool(raw['numberSelect']),
      selectNumber: AgentConfigParser.readString(raw['selectNumber']),
      numberGroup: AgentConfigParser.readString(raw['numberGroup']),
      sipNumber: AgentConfigParser.readString(raw['sipNumber']),
      callerStrategy: AgentConfigParser.readStringList(raw['callerStrategy']),
      offlineAnswer: AgentConfigParser.readBool(raw['offlineAnswer']),
      autoAnswer: AgentConfigParser.readBool(raw['autoAnswer']),
      autoAnswerTime: AgentConfigParser.readInt(raw['autoAnswerTime']),
      rememberMe: AgentConfigParser.readBool(raw['rememberMe']),
      rememberState: AgentConfigParser.readBool(raw['rememberState']),
      initLoginType: AgentConfigParser.readString(raw['initLoginType']),
      initStatus: AgentConfigParser.readString(raw['initStatus']),
      callinAnswerType: AgentConfigParser.readString(raw['callinAnswerType']),
      optimizeVoice: AgentConfigParser.readBool(raw['optimizeVoice'])
    };
  }

  private static parseAgentImConfig(
    raw: Record<string, Object | number | string | null | undefined> | undefined
  ): AgentImConfig | null {
    if (raw === undefined) {
      return null;
    }
    return {
      agentNickName: AgentConfigParser.readString(raw['agentNickName']),
      minLimit: AgentConfigParser.readInt(raw['minLimit']),
      maxLimit: AgentConfigParser.readInt(raw['maxLimit']),
      emailMinLimit: AgentConfigParser.readInt(raw['emailMinLimit']),
      emailMaxLimit: AgentConfigParser.readInt(raw['emailMaxLimit'])
    };
  }

  private static readString(raw: Object | string | number | boolean | null | undefined): string | null {
    if (raw === undefined || raw === null) {
      return null;
    }
    const s = String(raw);
    return s.length > 0 ? s : null;
  }

  private static readInt(raw: Object | string | number | boolean | null | undefined): number | null {
    if (raw === undefined || raw === null) {
      return null;
    }
    if (typeof raw === 'number') {
      return raw;
    }
    const n = Number(raw);
    return Number.isNaN(n) ? null : n;
  }

  private static readBool(raw: Object | string | number | boolean | null | undefined): boolean | null {
    if (raw === undefined || raw === null) {
      return null;
    }
    if (typeof raw === 'boolean') {
      return raw;
    }
    if (raw === 'true' || raw === 1) {
      return true;
    }
    if (raw === 'false' || raw === 0) {
      return false;
    }
    return null;
  }

  private static readStringList(raw: Object | string[] | null | undefined): string[] | null {
    if (!Array.isArray(raw)) {
      return null;
    }
    const out: string[] = [];
    for (let i = 0; i < raw.length; i++) {
      out.push(String(raw[i]));
    }
    return out;
  }

  private static emptyConfig(): AgentConfig {
    return {
      _id: null,
      accountId: null,
      agentName: null,
      icon: null,
      mobile: null,
      email: null,
      agentNumber: null,
      pinyin: null,
      status: null,
      agentCallConfig: null,
      agentImConfig: null,
      groups: null,
      roles: null,
      versionId: null,
      crmId: null,
      createTime: null,
      createAgent: null,
      updateTime: null,
      updateAgent: null
    };
  }
}
