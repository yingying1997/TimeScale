import { EventItem } from '../model/EventItem'
import { DateUtils, EventStatusInfo } from '../utils/DateUtils'
import { LunarDateInfo, LunarDateService } from './LunarDateService'

export class EventOccurrenceService {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000

  static resolveOccurrenceDate(item: EventItem, fromDate: Date = new Date()): Date {
    const baseDate = LunarDateService.startOfDay(fromDate)
    const calendarType = item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')
    if (calendarType === 'lunar') {
      return EventOccurrenceService.resolveLunarOccurrence(item, baseDate)
    }
    return EventOccurrenceService.resolveSolarOccurrence(item, baseDate)
  }

  static resolveStatusInfo(item: EventItem, fromDate: Date = new Date()): EventStatusInfo {
    const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(item, fromDate)
    return DateUtils.calculateStatus(occurrenceDate.getTime(), fromDate)
  }

  static formatEventDateText(item: EventItem): string {
    const calendarType = item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')
    if (calendarType === 'lunar') {
      const info = EventOccurrenceService.getLunarAnchor(item)
      return LunarDateService.buildDisplayText(info)
    }
    return DateUtils.formatSolarDate(item.targetDate)
  }

  static formatPrimaryDateText(item: EventItem): string {
    const calendarType = item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')
    if (calendarType === 'lunar') {
      return DateUtils.formatLunarDate(item.targetDate).replace(/^\u519c\u5386/, '')
    }
    return DateUtils.formatSolarDate(item.targetDate)
  }

  static formatSecondaryDateText(item: EventItem): string {
    const calendarType = item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')
    if (calendarType === 'lunar') {
      return DateUtils.formatSolarDate(item.targetDate)
    }
    return ''
  }

  static isLunarEvent(item: EventItem): boolean {
    return (item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')) === 'lunar'
  }

  static getReminderDate(item: EventItem, fromDate: Date = new Date()): Date {
    const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(item, fromDate)
    occurrenceDate.setHours(item.reminderHour ?? 12, item.reminderMinute ?? 0, 0, 0)
    if (item.reminderType === 'one_day_before') {
      occurrenceDate.setDate(occurrenceDate.getDate() - 1)
    }
    return occurrenceDate
  }

  private static resolveSolarOccurrence(item: EventItem, baseDate: Date): Date {
    if (item.repeatType !== 'monthly' && item.repeatType !== 'yearly') {
      return LunarDateService.startOfDay(item.targetDate)
    }

    const referenceDate = new Date(item.targetDate)
    const solarMonth = item.solarMonth ?? (referenceDate.getMonth() + 1)
    const solarDay = item.solarDay ?? referenceDate.getDate()

    if (item.repeatType === 'yearly') {
      let year = baseDate.getFullYear()
      let candidate = EventOccurrenceService.buildClampedSolarDate(year, solarMonth, solarDay)
      if (candidate.getTime() < baseDate.getTime()) {
        candidate = EventOccurrenceService.buildClampedSolarDate(year + 1, solarMonth, solarDay)
      }
      return candidate
    }

    let year = baseDate.getFullYear()
    let month = baseDate.getMonth() + 1
    let candidate = EventOccurrenceService.buildClampedSolarDate(year, month, solarDay)
    if (candidate.getTime() < baseDate.getTime()) {
      const nextMonth = new Date(year, month, 1)
      year = nextMonth.getFullYear()
      month = nextMonth.getMonth() + 1
      candidate = EventOccurrenceService.buildClampedSolarDate(year, month, solarDay)
    }
    return candidate
  }

  private static resolveLunarOccurrence(item: EventItem, baseDate: Date): Date {
    if (item.repeatType === 'none' || item.repeatType === undefined) {
      return LunarDateService.startOfDay(item.targetDate)
    }

    const anchor = EventOccurrenceService.getLunarAnchor(item)
    const searchLimit = item.repeatType === 'monthly' ? 450 : 2200
    let cursor = new Date(baseDate.getTime())
    for (let index = 0; index < searchLimit; index++) {
      const info = LunarDateService.getLunarDateInfo(cursor)
      if (item.repeatType === 'monthly') {
        if (info.lunarDay === anchor.lunarDay) {
          return cursor
        }
      } else if (info.lunarMonth === anchor.lunarMonth && info.lunarDay === anchor.lunarDay) {
        if (anchor.isLeapMonth) {
          if (info.isLeapMonth) {
            return cursor
          }
          if (!LunarDateService.hasLeapMonthInYear(info.lunarYear, anchor.lunarMonth)) {
            return cursor
          }
        } else if (!info.isLeapMonth) {
          return cursor
        }
      }
      cursor = new Date(cursor.getTime() + EventOccurrenceService.DAY_MS)
    }

    return LunarDateService.startOfDay(item.targetDate)
  }

  private static getLunarAnchor(item: EventItem): LunarDateInfo {
    const source = LunarDateService.getLunarDateInfo(item.targetDate)
    return {
      lunarYear: source.lunarYear,
      lunarMonth: item.lunarMonth ?? source.lunarMonth,
      lunarDay: item.lunarDay ?? source.lunarDay,
      isLeapMonth: item.isLeapMonth ?? source.isLeapMonth,
      monthLabel: source.monthLabel,
      dayLabel: source.dayLabel
    }
  }

  private static buildClampedSolarDate(year: number, month: number, day: number): Date {
    const lastDay = new Date(year, month, 0).getDate()
    return new Date(year, month - 1, Math.min(day, lastDay))
  }
}
