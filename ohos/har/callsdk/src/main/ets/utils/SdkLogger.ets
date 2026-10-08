import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';

const DOMAIN: number = 0x3200;
const LOG_PREFIX: string = 'callsdk';

/**
 * SDK 日志：hilog + 可选文件。
 */
export class SdkLogger {
  private static fileLogEnabled: boolean = false;
  private static consoleEnabled: boolean = true;
  private static minLevel: number = 3;
  private static logDir: string = '';
  private static customLogDir: string | null = null;

  static configure(
    enableLog: boolean,
    consoleEnabled: boolean,
    fileEnabled: boolean,
    level: number,
    logFilePath: string | null = null
  ): void {
    SdkLogger.fileLogEnabled = enableLog && fileEnabled;
    SdkLogger.consoleEnabled = enableLog && consoleEnabled;
    SdkLogger.minLevel = level;
    if (logFilePath !== null && logFilePath.trim().length > 0) {
      SdkLogger.customLogDir = logFilePath.trim();
    } else {
      SdkLogger.customLogDir = null;
    }
  }

  static init(context: common.Context): void {
    if (SdkLogger.customLogDir !== null) {
      SdkLogger.logDir = SdkLogger.customLogDir;
    } else {
      SdkLogger.logDir = `${context.filesDir}/logs`;
    }
    SdkLogger.ensureLogDir();
    SdkLogger.info('SdkLogger', `init logDir=${SdkLogger.logDir}`);
  }

  static getLogDirectory(): string {
    return SdkLogger.logDir;
  }

  static debug(tag: string, msg: string): void {
    if (SdkLogger.consoleEnabled && SdkLogger.minLevel <= 3) {
      hilog.debug(DOMAIN, `${LOG_PREFIX}-${tag}`, '%{public}s', msg);
    }
    SdkLogger.appendFile('D', tag, msg);
  }

  static info(tag: string, msg: string): void {
    if (SdkLogger.consoleEnabled && SdkLogger.minLevel <= 4) {
      hilog.info(DOMAIN, `${LOG_PREFIX}-${tag}`, '%{public}s', msg);
    }
    SdkLogger.appendFile('I', tag, msg);
  }

  static warn(tag: string, msg: string): void {
    if (SdkLogger.consoleEnabled) {
      hilog.warn(DOMAIN, `${LOG_PREFIX}-${tag}`, '%{public}s', msg);
    }
    SdkLogger.appendFile('W', tag, msg);
  }

  static error(tag: string, msg: string): void {
    if (SdkLogger.consoleEnabled) {
      hilog.error(DOMAIN, `${LOG_PREFIX}-${tag}`, '%{public}s', msg);
    }
    SdkLogger.appendFile('E', tag, msg);
  }

  private static ensureLogDir(): void {
    if (SdkLogger.logDir.length === 0) {
      return;
    }
    try {
      fs.accessSync(SdkLogger.logDir);
    } catch (_) {
      try {
        fs.mkdirSync(SdkLogger.logDir, true);
      } catch (_) {
      }
    }
  }

  private static appendFile(level: string, tag: string, msg: string): void {
    if (!SdkLogger.fileLogEnabled || SdkLogger.logDir.length === 0) {
      return;
    }
    SdkLogger.ensureLogDir();
    const now = new Date();
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    const ts = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ` +
      `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    const line = `${ts} [${level}] ${LOG_PREFIX}-${tag}: ${msg}\n`;
    const path = `${SdkLogger.logDir}/callsdk.log`;
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND);
      fs.writeSync(file.fd, line);
      fs.closeSync(file);
    } catch (_) {
    }
  }
}
