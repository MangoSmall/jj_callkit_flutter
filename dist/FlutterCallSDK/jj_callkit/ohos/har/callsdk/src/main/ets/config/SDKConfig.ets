import { LogConfig } from './LogConfig';

/** 对齐 callsdk SDKConfig */

export class SDKConfig {
  username: string;
  password: string | null;
  passwordPk: string | null;
  baseUrl: string;
  logConfig: LogConfig;

  constructor(
    username: string,
    password: string | null = null,
    passwordPk: string | null = null,
    baseUrl: string = 'https://app.useasy.cn',
    logConfig: LogConfig = new LogConfig()
  ) {
    this.username = username;
    this.password = password;
    this.passwordPk = passwordPk;
    this.baseUrl = baseUrl;
    this.logConfig = logConfig;
  }
}
