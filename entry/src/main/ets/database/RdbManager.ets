import relationalStore from '@ohos.data.relationalStore'
import { AppLogger } from '../utils/AppLogger'

const DB_NAME: string = 'event.db'
const TABLE_NAME: string = 'events'
const REMINDER_INSTANCE_TABLE_NAME: string = 'reminder_instances'

export class RdbManager {
  private static rdb: relationalStore.RdbStore | null = null

  static async getRdb(context: Context): Promise<relationalStore.RdbStore> {
    if (RdbManager.rdb) {
      return RdbManager.rdb
    }

    try {
      RdbManager.rdb = await relationalStore.getRdbStore(context, {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      })

      await RdbManager.rdb.executeSql(`
        CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          targetDate INTEGER,
          sortIndex INTEGER,
          themeColor TEXT,
          isLunarDate INTEGER,
          type TEXT NOT NULL DEFAULT 'countdown',
          status TEXT NOT NULL DEFAULT 'future',
          note TEXT,
          reminderType TEXT,
          reminderHour INTEGER,
          reminderMinute INTEGER,
          createTime INTEGER,
          repeatType TEXT,
          calendarEventId INTEGER,
          agentReminderId INTEGER,
          calendarType TEXT,
          solarMonth INTEGER,
          solarDay INTEGER,
          lunarMonth INTEGER,
          lunarDay INTEGER,
          isLeapMonth INTEGER
        )
      `)

      await RdbManager.rdb.executeSql(`
        CREATE TABLE IF NOT EXISTS ${REMINDER_INSTANCE_TABLE_NAME} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eventId INTEGER NOT NULL,
          occurrenceDate INTEGER NOT NULL,
          reminderTime INTEGER NOT NULL,
          calendarEventId INTEGER,
          agentReminderId INTEGER,
          status TEXT NOT NULL DEFAULT 'scheduled',
          reason TEXT,
          createTime INTEGER,
          updateTime INTEGER
        )
      `)
    } catch (error) {
      RdbManager.rdb = null
      AppLogger.error('RdbManager', `Failed to initialize database: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }

    await RdbManager.tryExecuteMigration(
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_reminder_instances_event_time ON ${REMINDER_INSTANCE_TABLE_NAME} (eventId, reminderTime)`,
      'reminder instance unique index'
    )
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN themeColor TEXT`, 'events.themeColor')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN isLunarDate INTEGER`, 'events.isLunarDate')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN calendarEventId INTEGER`, 'events.calendarEventId')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN agentReminderId INTEGER`, 'events.agentReminderId')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN calendarType TEXT`, 'events.calendarType')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN solarMonth INTEGER`, 'events.solarMonth')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN solarDay INTEGER`, 'events.solarDay')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN lunarMonth INTEGER`, 'events.lunarMonth')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN lunarDay INTEGER`, 'events.lunarDay')
    await RdbManager.tryExecuteMigration(`ALTER TABLE ${TABLE_NAME} ADD COLUMN isLeapMonth INTEGER`, 'events.isLeapMonth')

    return RdbManager.rdb
  }

  private static async tryExecuteMigration(sql: string, label: string): Promise<void> {
    if (!RdbManager.rdb) {
      return
    }
    try {
      await RdbManager.rdb.executeSql(sql)
    } catch (error) {
      AppLogger.warn('RdbManager', `Skip migration ${label}: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }
}
