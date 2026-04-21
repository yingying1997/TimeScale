import relationalStore from '@ohos.data.relationalStore'
import { RdbManager } from '../database/RdbManager'
import { EventItem } from '../model/EventItem'
import { AppLogger } from '../utils/AppLogger'
import { LunarDateService } from '../services/LunarDateService'

export class EventRepository {
  private static readonly DEFAULT_THEME_COLOR: string = '#2563EB'

  static async getAllEvents(context: Context): Promise<EventItem[]> {
    const rdb = await RdbManager.getRdb(context)
    let result: relationalStore.ResultSet | undefined = undefined
    const events: EventItem[] = []

    try {
      result = await rdb.querySql('SELECT * FROM events ORDER BY sortIndex ASC')
      while (EventRepository.goToNextRow(result)) {
        const isLunarDate = EventRepository.getNullableLong(result, 'isLunarDate') === 1

        events.push({
          id: EventRepository.getRequiredLong(result, 'id'),
          title: EventRepository.getNullableString(result, 'title') || '',
          targetDate: EventRepository.getRequiredLong(result, 'targetDate'),
          sortIndex: EventRepository.getRequiredLong(result, 'sortIndex'),
          themeColor: EventRepository.getNullableString(result, 'themeColor') ?? EventRepository.DEFAULT_THEME_COLOR,
          isLunarDate: isLunarDate,
          note: EventRepository.getNullableString(result, 'note'),
          reminderType: EventRepository.getNullableString(result, 'reminderType') as 'on_day' | 'one_day_before' | 'none',
          reminderHour: EventRepository.getNullableLong(result, 'reminderHour'),
          reminderMinute: EventRepository.getNullableLong(result, 'reminderMinute'),
          createTime: EventRepository.getNullableLong(result, 'createTime') || Date.now(),
          repeatType: EventRepository.getNullableString(result, 'repeatType') as 'none' | 'monthly' | 'yearly',
          calendarEventId: EventRepository.getNullableLong(result, 'calendarEventId'),
          agentReminderId: EventRepository.getNullableLong(result, 'agentReminderId'),
          calendarType: (EventRepository.getNullableString(result, 'calendarType') as 'solar' | 'lunar' | undefined)
            ?? (isLunarDate ? 'lunar' : 'solar'),
          solarMonth: EventRepository.getNullableLong(result, 'solarMonth'),
          solarDay: EventRepository.getNullableLong(result, 'solarDay'),
          lunarMonth: EventRepository.getNullableLong(result, 'lunarMonth'),
          lunarDay: EventRepository.getNullableLong(result, 'lunarDay'),
          isLeapMonth: (() => {
            const value = EventRepository.getNullableLong(result, 'isLeapMonth')
            return value === undefined ? undefined : value === 1
          })(),
        })
      }
    } catch (error) {
      AppLogger.error('EventRepository', `Failed to query events: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    } finally {
      EventRepository.closeResult(result)
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
    try {
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
    } catch (error) {
      AppLogger.error('EventRepository', `Failed to add event: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  static async updateEvent(context: Context, event: EventItem): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates('events')
    predicates.equalTo('id', event.id)
    try {
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
    } catch (error) {
      AppLogger.error('EventRepository', `Failed to update event ${event.id}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  static async deleteEvent(context: Context, id: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates('events')
    predicates.equalTo('id', id)
    try {
      await rdb.delete(predicates)
    } catch (error) {
      AppLogger.error('EventRepository', `Failed to delete event ${id}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
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

    let transactionOpened: boolean = false
    try {
      await rdb.executeSql('BEGIN TRANSACTION')
      transactionOpened = true
    } catch (error) {
      AppLogger.warn('EventRepository',
        `moveItem transaction not supported, fallback to non-transaction updates: ${error instanceof Error ? error.message : `${error}`}`)
    }
    try {
      for (let i = 0; i < list.length; i++) {
        list[i].sortIndex = i
        const predicates = new relationalStore.RdbPredicates('events')
        predicates.equalTo('id', list[i].id)
        await rdb.update({ sortIndex: list[i].sortIndex }, predicates)
      }
      if (transactionOpened) {
        await rdb.executeSql('COMMIT')
      }
    } catch (error) {
      if (transactionOpened) {
        await EventRepository.rollbackSafely(rdb, 'moveItem')
      }
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
        await EventRepository.rollbackSafely(rdb, 'saveSortOrder')
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

  private static goToNextRow(result: relationalStore.ResultSet): boolean {
    try {
      return result.goToNextRow()
    } catch (error) {
      AppLogger.error('EventRepository', `Failed to move result cursor: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  private static getColumnIndex(result: relationalStore.ResultSet, name: string): number {
    try {
      return result.getColumnIndex(name)
    } catch (error) {
      AppLogger.warn('EventRepository', `Column ${name} not found: ${error instanceof Error ? error.message : `${error}`}`)
      return -1
    }
  }

  private static getRequiredLong(result: relationalStore.ResultSet, name: string): number {
    const value = EventRepository.getNullableLong(result, name)
    if (value === undefined) {
      throw new Error(`Column ${name} is required`)
    }
    return value
  }

  private static getNullableLong(result: relationalStore.ResultSet, name: string): number | undefined {
    const col = EventRepository.getColumnIndex(result, name)
    if (col === -1) {
      return undefined
    }
    try {
      const value = result.getLong(col)
      return value === null ? undefined : value
    } catch (error) {
      AppLogger.warn('EventRepository', `Failed to read number column ${name}: ${error instanceof Error ? error.message : `${error}`}`)
      return undefined
    }
  }

  private static getNullableString(result: relationalStore.ResultSet, name: string): string | undefined {
    const col = EventRepository.getColumnIndex(result, name)
    if (col === -1) {
      return undefined
    }
    try {
      const value = result.getString(col)
      return value === null ? undefined : value
    } catch (error) {
      AppLogger.warn('EventRepository', `Failed to read string column ${name}: ${error instanceof Error ? error.message : `${error}`}`)
      return undefined
    }
  }

  private static closeResult(result: relationalStore.ResultSet | undefined): void {
    if (!result) {
      return
    }
    try {
      result.close()
    } catch (error) {
      AppLogger.warn('EventRepository', `Failed to close result set: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  private static async rollbackSafely(rdb: relationalStore.RdbStore, label: string): Promise<void> {
    try {
      await rdb.executeSql('ROLLBACK')
    } catch (error) {
      AppLogger.error('EventRepository',
        `${label} rollback failed: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }
}
