import { EventItem } from '../model/EventItem'
import { EventOccurrenceService } from './EventOccurrenceService'
import { LunarDateService } from './LunarDateService'

export class ReminderOccurrence {
  occurrenceDate: Date = new Date()
  reminderDate: Date = new Date()
}

export class ReminderOccurrenceGenerator {
  static readonly MONTHLY_WINDOW_COUNT: number = 12
  static readonly YEARLY_WINDOW_COUNT: number = 3

  static generateFutureOccurrences(event: EventItem, fromDate: Date = new Date()): ReminderOccurrence[] {
    if (event.reminderType === 'none' || event.reminderHour === undefined || event.reminderMinute === undefined) {
      return []
    }

    if (event.repeatType === 'monthly') {
      return ReminderOccurrenceGenerator.generateRepeatedOccurrences(
        event,
        ReminderOccurrenceGenerator.MONTHLY_WINDOW_COUNT,
        fromDate
      )
    }

    if (event.repeatType === 'yearly') {
      return ReminderOccurrenceGenerator.generateRepeatedOccurrences(
        event,
        ReminderOccurrenceGenerator.YEARLY_WINDOW_COUNT,
        fromDate
      )
    }

    const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(event, fromDate)
    const reminderDate = EventOccurrenceService.getReminderDate(event, fromDate)
    if (reminderDate.getTime() <= fromDate.getTime()) {
      return []
    }

    return [ReminderOccurrenceGenerator.buildOccurrence(occurrenceDate, reminderDate)]
  }

  private static generateRepeatedOccurrences(
    event: EventItem,
    count: number,
    fromDate: Date
  ): ReminderOccurrence[] {
    const occurrences: ReminderOccurrence[] = []
    const seenReminderTimes: Set<number> = new Set<number>()
    let cursor = LunarDateService.startOfDay(fromDate)
    const referenceTime = fromDate.getTime()
    let guard = 0

    while (occurrences.length < count && guard < count * 450) {
      const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(event, cursor)
      const reminderDate = EventOccurrenceService.getReminderDate(event, cursor)
      const reminderTime = reminderDate.getTime()

      if (reminderTime > referenceTime && !seenReminderTimes.has(reminderTime)) {
        seenReminderTimes.add(reminderTime)
        occurrences.push(ReminderOccurrenceGenerator.buildOccurrence(occurrenceDate, reminderDate))
      }

      cursor = ReminderOccurrenceGenerator.nextSearchBaseDate(occurrenceDate)
      guard++
    }

    return occurrences
  }

  private static buildOccurrence(occurrenceDate: Date, reminderDate: Date): ReminderOccurrence {
    const occurrence = new ReminderOccurrence()
    occurrence.occurrenceDate = occurrenceDate
    occurrence.reminderDate = reminderDate
    return occurrence
  }

  private static nextSearchBaseDate(occurrenceDate: Date): Date {
    const baseDate = LunarDateService.startOfDay(occurrenceDate)
    baseDate.setDate(baseDate.getDate() + 1)
    return baseDate
  }
}
