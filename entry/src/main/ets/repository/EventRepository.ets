import relationalStore from '@ohos.data.relationalStore'
import { RdbManager } from '../database/RdbManager'
import { EventItem } from '../model/EventItem'
import { AppLogger } from '../utils/AppLogger'
import { LunarDateService } from '../services/LunarDateService'

export class EventRepository {
  private static readonly DEFAULT_THEME_COLOR: string = '#2563EB'

  static async getAllEvents(context: Context): Promise<EventItem[]> {
    const rdb = await RdbManager.getRdb(context)
    const result = await rdb.querySql('SELECT * FROM events ORDER BY sortIndex ASC')
    const events: EventItem[] = []

    try {
      while (result.goToNextRow()) {
        const getNullableLong = (col: number): number | undefined => {
          if (col === -1) return undefined
          const value = result.getLong(col)
          return value === null ? undefined : value
        }

        const getNullableString = (col: number): string | undefined => {
          if (col === -1) return undefined
          const value = result.getString(col)
          return value === null ? undefined : value
        }

        events.push({
          id: result.getLong(result.getColumnIndex('id')),
          title: result.getString(result.getColumnIndex('title')) || '',
          targetDate: result.getLong(result.getColumnIndex('targetDate')),
          sortIndex: result.getLong(result.getColumnIndex('sortIndex')),
          themeColor: getNullableString(result.getColumnIndex('themeColor')) ?? EventRepository.DEFAULT_THEME_COLOR,
          isLunarDate: getNullableLong(result.getColumnIndex('isLunarDate')) === 1,
          note: getNullableString(result.getColumnIndex('note')),
          reminderType: getNullableString(result.getColumnIndex('reminderType')) as 'on_day' | 'one_day_before' | 'none',
          reminderHour: getNullableLong(result.getColumnIndex('reminderHour')),
          reminderMinute: getNullableLong(result.getColumnIndex('reminderMinute')),
          createTime: getNullableLong(result.getColumnIndex('createTime')) || Date.now(),
          repeatType: getNullableString(result.getColumnIndex('repeatType')) as 'none' | 'monthly' | 'yearly',
          calendarEventId: getNullableLong(result.getColumnIndex('calendarEventId')),
          agentReminderId: getNullableLong(result.getColumnIndex('agentReminderId')),
          calendarType: (getNullableString(result.getColumnIndex('calendarType')) as 'solar' | 'lunar' | undefined)
            ?? (getNullableLong(result.getColumnIndex('isLunarDate')) === 1 ? 'lunar' : 'solar'),
          solarMonth: getNullableLong(result.getColumnIndex('solarMonth')),
          solarDay: getNullableLong(result.getColumnIndex('solarDay')),
          lunarMonth: getNullableLong(result.getColumnIndex('lunarMonth')),
          lunarDay: getNullableLong(result.getColumnIndex('lunarDay')),
          isLeapMonth: (() => {
            const value = getNullableLong(result.getColumnIndex('isLeapMonth'))
            return value === undefined ? undefined : value === 1
          })(),
        })
      }
    } finally {
      result.close()
    }

    EventRepository.normalizeLegacyFields(events)
    events.sort((a, b) => a.sortIndex - b.sortIndex)
    return events
  }

  static async getEventById(context: Context, id: number): Promise<EventItem | undefined> {
    const events = await EventRepository.getAllEvents(context)
    for (let i = 0; i < events.length; i++) {
      if (events[i].id === id) {
        return events[i]
      }
    }
    return undefined
  }

  static async addEvent(context: Context, event: EventItem): Promise<number> {
    const rdb = await RdbManager.getRdb(context)
    const list = await EventRepository.getAllEvents(context)
    const rowId = await rdb.insert('events', {
      title: event.title,
      targetDate: event.targetDate,
      sortIndex: list.length,
      themeColor: event.themeColor ?? EventRepository.DEFAULT_THEME_COLOR,
      isLunarDate: event.isLunarDate ? 1 : 0,
      note: event.note,
      reminderType: event.reminderType,
      reminderHour: event.reminderHour,
      reminderMinute: event.reminderMinute,
      createTime: event.createTime || Date.now(),
      repeatType: event.repeatType,
      calendarEventId: event.calendarEventId,
      agentReminderId: event.agentReminderId,
      calendarType: event.calendarType ?? (event.isLunarDate ? 'lunar' : 'solar'),
      solarMonth: event.solarMonth,
      solarDay: event.solarDay,
      lunarMonth: event.lunarMonth,
      lunarDay: event.lunarDay,
      isLeapMonth: event.isLeapMonth ? 1 : 0,
    })
    return Number(rowId)
  }

  static async updateEvent(context: Context, event: EventItem): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates('events')
    predicates.equalTo('id', event.id)
    await rdb.update({
      title: event.title,
      targetDate: event.targetDate,
      sortIndex: event.sortIndex,
      themeColor: event.themeColor ?? EventRepository.DEFAULT_THEME_COLOR,
      isLunarDate: event.isLunarDate ? 1 : 0,
      note: event.note,
      reminderType: event.reminderType,
      reminderHour: event.reminderHour,
      reminderMinute: event.reminderMinute,
      createTime: event.createTime,
      repeatType: event.repeatType,
      calendarEventId: event.calendarEventId,
      agentReminderId: event.agentReminderId,
      calendarType: event.calendarType ?? (event.isLunarDate ? 'lunar' : 'solar'),
      solarMonth: event.solarMonth,
      solarDay: event.solarDay,
      lunarMonth: event.lunarMonth,
      lunarDay: event.lunarDay,
      isLeapMonth: event.isLeapMonth ? 1 : 0,
    }, predicates)
  }

  static async deleteEvent(context: Context, id: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates('events')
    predicates.equalTo('id', id)
    await rdb.delete(predicates)
  }

  static async moveItem(context: Context, from: number, to: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const list = await EventRepository.getAllEvents(context)
    if (from < 0 || from >= list.length || to < 0 || to >= list.length) {
      return
    }

    const item = list[from]
    list.splice(from, 1)
    list.splice(to, 0, item)

    await rdb.executeSql('BEGIN TRANSACTION')
    try {
      for (let i = 0; i < list.length; i++) {
        list[i].sortIndex = i
        const predicates = new relationalStore.RdbPredicates('events')
        predicates.equalTo('id', list[i].id)
        await rdb.update({ sortIndex: list[i].sortIndex }, predicates)
      }
      await rdb.executeSql('COMMIT')
    } catch (error) {
      await rdb.executeSql('ROLLBACK')
      throw new Error(`${error}`)
    }
  }

  static async saveSortOrder(context: Context, list: EventItem[]): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    let transactionOpened: boolean = false
    try {
      await rdb.executeSql('BEGIN TRANSACTION')
      transactionOpened = true
    } catch (error) {
      AppLogger.warn('EventRepository',
        `transaction not supported, fallback to non-transaction updates: ${error instanceof Error ? error.message : `${error}`}`)
    }

    try {
      for (let i = 0; i < list.length; i++) {
        const predicates = new relationalStore.RdbPredicates('events')
        predicates.equalTo('id', list[i].id)
        await rdb.update({ sortIndex: i }, predicates)
      }
      if (transactionOpened) {
        await rdb.executeSql('COMMIT')
      }
    } catch (error) {
      if (transactionOpened) {
        await rdb.executeSql('ROLLBACK')
        AppLogger.error('EventRepository',
          `saveSortOrder rollback: ${error instanceof Error ? error.message : `${error}`}`)
      }
      throw new Error(`${error}`)
    }
  }

  private static normalizeLegacyFields(events: EventItem[]): void {
    events.forEach((event: EventItem) => {
      const targetDate = new Date(event.targetDate)
      event.calendarType = event.calendarType ?? (event.isLunarDate ? 'lunar' : 'solar')
      event.solarMonth = event.solarMonth ?? (targetDate.getMonth() + 1)
      event.solarDay = event.solarDay ?? targetDate.getDate()
      if (event.calendarType === 'lunar' && (event.lunarMonth === undefined || event.lunarDay === undefined)) {
        const lunarInfo = LunarDateService.getLunarDateInfo(targetDate)
        event.lunarMonth = lunarInfo.lunarMonth
        event.lunarDay = lunarInfo.lunarDay
        event.isLeapMonth = event.isLeapMonth ?? lunarInfo.isLeapMonth
      }
    })
  }
}
