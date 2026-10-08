/** 日志配置 */

export class LogConfig {
  /** 总开关；为 false 时控制台与文件日志均关闭 */
  enableLog: boolean = false;
  /** 日志级别过滤（数值越小越详细，默认 3） */
  logLevel: number = 3;
  /**
   * 文件日志目录；null 时使用默认路径 `filesDir/logs`。
   * 日志文件名为该目录下的 `callsdk.log`。
   */
  logFilePath: string | null = null;
  /** 是否写入文件（需同时开启 enableLog） */
  fileLoggingEnabled: boolean = false;
  /** 是否输出到 hilog 控制台（需同时开启 enableLog） */
  consoleLogEnabled: boolean = false;
}
