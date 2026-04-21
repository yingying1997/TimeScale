export class AppLogger {
  private static readonly ENABLE_INFO_LOGS: boolean = false

  static info(tag: string, message: string): void {
    if (!AppLogger.ENABLE_INFO_LOGS) {
      return
    }
    console.info(`[${tag}] ${message}`)
  }

  static warn(tag: string, message: string): void {
    console.warn(`[${tag}] ${message}`)
  }

  static error(tag: string, message: string): void {
    console.error(`[${tag}] ${message}`)
  }
}
