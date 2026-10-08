/** 对齐 callsdk Environment */

export enum EnvironmentType {
  PRODUCTION = 'PRODUCTION',
  DEBUG = 'DEBUG'
}

export class Environment {
  static readonly PRODUCTION: string = 'https://app.useasy.cn';
  static readonly DEBUG: string = 'https://dev1.useasy.cn';

  static getUrl(type: EnvironmentType): string {
    if (type === EnvironmentType.DEBUG) {
      return Environment.DEBUG;
    }
    return Environment.PRODUCTION;
  }
}
