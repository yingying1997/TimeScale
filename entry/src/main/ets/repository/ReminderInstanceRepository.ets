import relationalStore from '@ohos.data.relationalStore'
import { RdbManager } from '../database/RdbManager'
import { ReminderInstance, ReminderInstanceStatus } from '../model/ReminderInstance'
import { AppLogger } from '../utils/AppLogger'

export class ReminderInstanceRepository {
  private static readonly TABLE_NAME: string = 'reminder_instances'

  static async getInstancesByEventId(context: Context, eventId: number): Promise<ReminderInstance[]> {
    const rdb = await RdbManager.getRdb(context)
    let result: relationalStore.ResultSet | undefined = undefined
    const instances: ReminderInstance[] = []

    try {
      result = await rdb.querySql(
        `SELECT * FROM ${ReminderInstanceRepository.TABLE_NAME} WHERE eventId = ? ORDER BY reminderTime ASC`,
        [eventId]
      )
      while (ReminderInstanceRepository.goToNextRow(result)) {
        instances.push(ReminderInstanceRepository.fromResultRow(result))
      }
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to query reminder instances for event ${eventId}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    } finally {
      ReminderInstanceRepository.closeResult(result)
    }

    return instances
  }

  static async getFutureInstancesByEventId(
    context: Context,
    eventId: number,
    fromTime: number = Date.now()
  ): Promise<ReminderInstance[]> {
    const rdb = await RdbManager.getRdb(context)
    let result: relationalStore.ResultSet | undefined = undefined
    const instances: ReminderInstance[] = []

    try {
      result = await rdb.querySql(
        `SELECT * FROM ${ReminderInstanceRepository.TABLE_NAME} WHERE eventId = ? AND reminderTime > ? ORDER BY reminderTime ASC`,
        [eventId, fromTime]
      )
      while (ReminderInstanceRepository.goToNextRow(result)) {
        instances.push(ReminderInstanceRepository.fromResultRow(result))
      }
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to query future reminder instances for event ${eventId}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    } finally {
      ReminderInstanceRepository.closeResult(result)
    }

    return instances
  }

  static async addInstance(context: Context, instance: ReminderInstance): Promise<number> {
    const rdb = await RdbManager.getRdb(context)
    const now = Date.now()
    try {
      const rowId = await rdb.insert(ReminderInstanceRepository.TABLE_NAME, {
        eventId: instance.eventId,
        occurrenceDate: instance.occurrenceDate,
        reminderTime: instance.reminderTime,
        calendarEventId: instance.calendarEventId,
        agentReminderId: instance.agentReminderId,
        status: instance.status,
        reason: instance.reason,
        createTime: instance.createTime || now,
        updateTime: instance.updateTime || now
      })
      return Number(rowId)
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to add reminder instance for event ${instance.eventId}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  static async updateInstance(context: Context, instance: ReminderInstance): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('id', instance.id)
    try {
      await rdb.update({
        eventId: instance.eventId,
        occurrenceDate: instance.occurrenceDate,
        reminderTime: instance.reminderTime,
        calendarEventId: instance.calendarEventId,
        agentReminderId: instance.agentReminderId,
        status: instance.status,
        reason: instance.reason,
        createTime: instance.createTime,
        updateTime: Date.now()
      }, predicates)
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to update reminder instance ${instance.id}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  static async deleteInstance(context: Context, id: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('id', id)
    try {
      await rdb.delete(predicates)
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to delete reminder instance ${id}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  static async deleteInstancesByEventId(context: Context, eventId: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('eventId', eventId)
    try {
      await rdb.delete(predicates)
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to delete reminder instances for event ${eventId}: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  private static fromResultRow(result: relationalStore.ResultSet): ReminderInstance {
    return {
      id: ReminderInstanceRepository.getRequiredLong(result, 'id'),
      eventId: ReminderInstanceRepository.getRequiredLong(result, 'eventId'),
      occurrenceDate: ReminderInstanceRepository.getRequiredLong(result, 'occurrenceDate'),
      reminderTime: ReminderInstanceRepository.getRequiredLong(result, 'reminderTime'),
      calendarEventId: ReminderInstanceRepository.getNullableLong(result, 'calendarEventId'),
      agentReminderId: ReminderInstanceRepository.getNullableLong(result, 'agentReminderId'),
      status: (ReminderInstanceRepository.getNullableString(result, 'status') as ReminderInstanceStatus | undefined) ?? 'scheduled',
      reason: ReminderInstanceRepository.getNullableString(result, 'reason'),
      createTime: ReminderInstanceRepository.getNullableLong(result, 'createTime') ?? Date.now(),
      updateTime: ReminderInstanceRepository.getNullableLong(result, 'updateTime') ?? Date.now()
    }
  }

  private static goToNextRow(result: relationalStore.ResultSet): boolean {
    try {
      return result.goToNextRow()
    } catch (error) {
      AppLogger.error('ReminderInstanceRepository',
        `Failed to move result cursor: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  private static getColumnIndex(result: relationalStore.ResultSet, name: string): number {
    try {
      return result.getColumnIndex(name)
    } catch (error) {
      AppLogger.warn('ReminderInstanceRepository',
        `Column ${name} not found: ${error instanceof Error ? error.message : `${error}`}`)
      return -1
    }
  }

  private static getRequiredLong(result: relationalStore.ResultSet, name: string): number {
    const value = ReminderInstanceRepository.getNullableLong(result, name)
    if (value === undefined) {
      throw new Error(`Column ${name} is required`)
    }
    return value
  }

  private static getNullableLong(result: relationalStore.ResultSet, name: string): number | undefined {
    const col = ReminderInstanceRepository.getColumnIndex(result, name)
    if (col === -1) {
      return undefined
    }
    try {
      const value = result.getLong(col)
      return value === null ? undefined : value
    } catch (error) {
      AppLogger.warn('ReminderInstanceRepository',
        `Failed to read number column ${name}: ${error instanceof Error ? error.message : `${error}`}`)
      return undefined
    }
  }

  private static getNullableString(result: relationalStore.ResultSet, name: string): string | undefined {
    const col = ReminderInstanceRepository.getColumnIndex(result, name)
    if (col === -1) {
      return undefined
    }
    try {
      const value = result.getString(col)
      return value === null ? undefined : value
    } catch (error) {
      AppLogger.warn('ReminderInstanceRepository',
        `Failed to read string column ${name}: ${error instanceof Error ? error.message : `${error}`}`)
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
      AppLogger.warn('ReminderInstanceRepository',
        `Failed to close result set: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }
}
