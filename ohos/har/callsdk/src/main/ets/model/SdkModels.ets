/** 对齐 Android bean 包模型 */

export interface AgentSummary {
  _id: string | null;
  agentNumber: string | null;
  mobile: string | null;
}

export interface AccountSummary {
  _id: string | null;
}

export interface PushServerSummary {
  url: string | null;
}

/** 对齐 Android UccLoginSession */
export interface LoginInfo {
  loginToken: string | null;
  agent?: AgentSummary;
  account?: AccountSummary;
  timestamp: number | null;
  clientType: number | null;
  pushServer?: PushServerSummary[];
}

/** Android 别名 */
export type UccLoginSession = LoginInfo;

/** 对齐 Android DisplayNumber */
export interface DisplayNumber {
  id: string | null;
  status: string | null;
  number: string | null;
  ivrId: string | null;
  province: string | null;
  city: string | null;
  line: string | null;
  lineState: number | null;
  abbreviation: string | null;
}

export type DisplayNumberItem = DisplayNumber;

export interface NumberGroup {
  id: string | null;
  accountId: string | null;
  numberList: string[] | null;
  strategy: string | null;
  createTime: string | null;
  createAgent: string | null;
  updateTime: string | null;
  updateAgent: string | null;
  groupName: string | null;
  remark: string | null;
  city: string | null;
  areaCode: string | null;
  defaultNumberList: string[] | null;
  overflowGroupId: string | null;
}

export type NumberGroupItem = NumberGroup;

export interface PageInfo {
  pageSize: number | null;
  pageNumber: number | null;
  totalPage: number | null;
  total: number | null;
}

export interface NumberGroupListResponse {
  list: NumberGroup[] | null;
  page: PageInfo | null;
}

export interface AgentCallConfig {
  loginType: string[] | null;
  restTime: number | null;
  numbers: string[] | null;
  numberSelect: boolean | null;
  selectNumber: string | null;
  numberGroup: string | null;
  sipNumber: string | null;
  callerStrategy: string[] | null;
  offlineAnswer: boolean | null;
  autoAnswer: boolean | null;
  autoAnswerTime: number | null;
  rememberMe: boolean | null;
  rememberState: boolean | null;
  initLoginType: string | null;
  initStatus: string | null;
  callinAnswerType: string | null;
  optimizeVoice: boolean | null;
}

export interface AgentImConfig {
  agentNickName: string | null;
  minLimit: number | null;
  maxLimit: number | null;
  emailMinLimit: number | null;
  emailMaxLimit: number | null;
}

/** 对齐 Android AgentConfig */
export interface AgentConfig {
  _id: string | null;
  accountId: string | null;
  agentName: string | null;
  icon: string | null;
  mobile: string | null;
  email: string | null;
  agentNumber: string | null;
  pinyin: string | null;
  status: number | null;
  agentCallConfig: AgentCallConfig | null;
  agentImConfig: AgentImConfig | null;
  groups: string[] | null;
  roles: string[] | null;
  versionId: string | null;
  crmId: string | null;
  createTime: string | null;
  createAgent: string | null;
  updateTime: string | null;
  updateAgent: string | null;
}
