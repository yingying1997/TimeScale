import { describe, it, expect } from '@ohos/hypium'
import { EventItem } from '../main/ets/model/EventItem'
import { EventOccurrenceService } from '../main/ets/services/EventOccurrenceService'
import { ReminderOccurrenceGenerator } from '../main/ets/services/ReminderOccurrenceGenerator'

function makeSolarEvent(
  month: number,
  day: number,
  repeatType: 'none' | 'monthly' | 'yearly',
  reminderType: 'on_day' | 'one_day_before' = 'on_day',
  reminderHour: number = 9,
  reminderMinute: number = 0,
  year: number = 2026
): EventItem {
  return {
    id: 1,
    title: 'Test Event',
    targetDate: new Date(year, month - 1, day).getTime(),
    sortIndex: 0,
    themeColor: '#2563EB',
    isLunarDate: false,
    note: '',
    reminderType,
    reminderHour,
    reminderMinute,
    createTime: new Date(2026, 0, 1).getTime(),
    repeatType,
    calendarType: 'solar',
    solarMonth: month,
    solarDay: day
  }
}

function makeLunarEvent(
  targetDate: Date,
  lunarMonth: number,
  lunarDay: number,
  isLeapMonth: boolean,
  repeatType: 'none' | 'monthly' | 'yearly',
  reminderType: 'on_day' | 'one_day_before' = 'on_day',
  reminderHour: number = 9,
  reminderMinute: number = 0
): EventItem {
  return {
    id: 2,
    title: 'Lunar Test Event',
    targetDate: targetDate.getTime(),
    sortIndex: 0,
    themeColor: '#2563EB',
    isLunarDate: true,
    note: '',
    reminderType,
    reminderHour,
    reminderMinute,
    createTime: new Date(2026, 0, 1).getTime(),
    repeatType,
    calendarType: 'lunar',
    lunarMonth,
    lunarDay,
    isLeapMonth
  }
}

function assertDateParts(
  date: Date,
  year: number,
  month: number,
  day: number,
  hour: number = 0,
  minute: number = 0
): void {
  expect(date.getFullYear()).assertEqual(year)
  expect(date.getMonth() + 1).assertEqual(month)
  expect(date.getDate()).assertEqual(day)
  expect(date.getHours()).assertEqual(hour)
  expect(date.getMinutes()).assertEqual(minute)
}

export default function reminderOccurrenceTest() {
  describe('reminderOccurrenceTest', () => {
    it('oneDayBeforeReminderUsesPreviousDay', 0, () => {
      const event = makeSolarEvent(4, 20, 'none', 'one_day_before', 12, 30)
      const reminderDate = EventOccurrenceService.getReminderDate(event, new Date(2026, 0, 1))

      assertDateParts(reminderDate, 2026, 4, 19, 12, 30)
    })

    it('pastOneTimeReminderGeneratesNoOccurrence', 0, () => {
      const event = makeSolarEvent(4, 20, 'none', 'on_day', 9, 0)
      const occurrences = ReminderOccurrenceGenerator.generateFutureOccurrences(
        event,
        new Date(2026, 3, 20, 15, 0)
      )

      expect(occurrences.length).assertEqual(0)
    })

    it('futureOneTimeReminderGeneratesOneOccurrence', 0, () => {
      const event = makeSolarEvent(5, 10, 'none', 'on_day', 9, 0)
      const occurrences = ReminderOccurrenceGenerator.generateFutureOccurrences(
        event,
        new Date(2026, 3, 20, 8, 0)
      )

      expect(occurrences.length).assertEqual(1)
      assertDateParts(occurrences[0].occurrenceDate, 2026, 5, 10)
      assertDateParts(occurrences[0].reminderDate, 2026, 5, 10, 9, 0)
    })

    it('monthlyThirtyFirstClampsToLastDayOfShortMonth', 0, () => {
      const event = makeSolarEvent(1, 31, 'monthly')
      const febOccurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2026, 1, 1))
      const aprOccurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2026, 3, 1))
      const mayOccurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2026, 4, 1))

      assertDateParts(febOccurrence, 2026, 2, 28)
      assertDateParts(aprOccurrence, 2026, 4, 30)
      assertDateParts(mayOccurrence, 2026, 5, 31)
    })

    it('yearlyLeapDayClampsInNonLeapYears', 0, () => {
      const event = makeSolarEvent(2, 29, 'yearly', 'on_day', 9, 0, 2024)
      const nonLeapOccurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2025, 0, 1))
      const nextLeapOccurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2028, 0, 1))

      assertDateParts(nonLeapOccurrence, 2025, 2, 28)
      assertDateParts(nextLeapOccurrence, 2028, 2, 29)
    })

    it('monthlyRepeatedReminderGeneratesTwelveFutureOccurrences', 0, () => {
      const event = makeSolarEvent(1, 31, 'monthly', 'on_day', 9, 0)
      const occurrences = ReminderOccurrenceGenerator.generateFutureOccurrences(
        event,
        new Date(2026, 0, 1, 8, 0)
      )

      expect(occurrences.length).assertEqual(12)
      assertDateParts(occurrences[0].occurrenceDate, 2026, 1, 31)
      assertDateParts(occurrences[1].occurrenceDate, 2026, 2, 28)
      assertDateParts(occurrences[11].occurrenceDate, 2026, 12, 31)
    })

    it('yearlyRepeatedReminderGeneratesThreeFutureOccurrences', 0, () => {
      const event = makeSolarEvent(2, 29, 'yearly', 'on_day', 9, 0, 2024)
      const occurrences = ReminderOccurrenceGenerator.generateFutureOccurrences(
        event,
        new Date(2025, 0, 1, 8, 0)
      )

      expect(occurrences.length).assertEqual(3)
      assertDateParts(occurrences[0].occurrenceDate, 2025, 2, 28)
      assertDateParts(occurrences[1].occurrenceDate, 2026, 2, 28)
      assertDateParts(occurrences[2].occurrenceDate, 2027, 2, 28)
    })

    it('lunarYearlyRepeatFindsNextLunarNewYear', 0, () => {
      const event = makeLunarEvent(new Date(2026, 1, 17), 1, 1, false, 'yearly')
      const occurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2026, 0, 1))

      assertDateParts(occurrence, 2026, 2, 17)
    })

    it('lunarOneDayBeforeReminderUsesPreviousSolarDay', 0, () => {
      const event = makeLunarEvent(new Date(2026, 1, 17), 1, 1, false, 'yearly', 'one_day_before', 8, 15)
      const reminderDate = EventOccurrenceService.getReminderDate(event, new Date(2026, 0, 1))

      assertDateParts(reminderDate, 2026, 2, 16, 8, 15)
    })

    it('lunarLeapMonthAnchorUsesLeapMonthWhenAvailable', 0, () => {
      const event = makeLunarEvent(new Date(2023, 2, 22), 2, 1, true, 'yearly')
      const occurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2023, 0, 1))

      assertDateParts(occurrence, 2023, 3, 22)
    })

    it('lunarLeapMonthAnchorFallsBackToRegularMonthWhenUnavailable', 0, () => {
      const event = makeLunarEvent(new Date(2023, 2, 22), 2, 1, true, 'yearly')
      const occurrence = EventOccurrenceService.resolveOccurrenceDate(event, new Date(2024, 0, 1))

      assertDateParts(occurrence, 2024, 3, 10)
    })
  })
}
