import { LunarDateService } from '../services/LunarDateService'

export interface EventStatusInfo {
  status: 'future' | 'today' | 'past'
  days: number
  text: string
  color: string
}

export class DateUtils {
  private static readonly CHINESE_DIGITS: string[] = ['\u96f6', '\u4e00', '\u4e8c', '\u4e09', '\u56db', '\u4e94', '\u516d', '\u4e03', '\u516b', '\u4e5d']

  static formatSolarDate(targetTimestamp: number): string {
    const date = new Date(targetTimestamp)
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    return `${date.getFullYear()}.${month}.${day}`
  }

  static formatLunarDate(targetTimestamp: number): string {
    const info = LunarDateService.getLunarDateInfo(targetTimestamp)
    const leapText = info.isLeapMonth ? '\u95f0' : ''
    return `${DateUtils.formatChineseYear(info.lunarYear)}\u5e74${leapText}${info.monthLabel}${info.dayLabel}`
  }

  private static formatChineseYear(year: number): string {
    return `${year}`.split('').map((digit: string) => {
      const value = Number(digit)
      return Number.isNaN(value) ? digit : DateUtils.CHINESE_DIGITS[value]
    }).join('')
  }

  static calculateStatus(targetTimestamp: number, baseDate: Date = new Date()): EventStatusInfo {
    const baseDay = DateUtils.toLocalDayNumber(baseDate)
    const targetDay = DateUtils.toLocalDayNumber(new Date(targetTimestamp))
    const diffDays = targetDay - baseDay

    if (diffDays === 0) {
      return { status: 'today', days: 0, text: '\u4eca\u5929', color: '#FF5252' }
    }

    if (diffDays > 0) {
      return { status: 'future', days: diffDays, text: `\u8fd8\u6709 ${diffDays} \u5929`, color: '#007DFF' }
    }

    const pastDays = Math.abs(diffDays)
    return {
      status: 'past',
      days: pastDays,
      text: `\u5df2\u8fc7 ${pastDays} \u5929`,
      color: '#9C27B0'
    }
  }

  private static dayMs(): number {
    return 1000 * 60 * 60 * 24
  }

  private static toLocalDayNumber(date: Date): number {
    return Math.floor(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) / DateUtils.dayMs())
  }
}
