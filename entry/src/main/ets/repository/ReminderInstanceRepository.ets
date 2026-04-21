import relationalStore from '@ohos.data.relationalStore'
import { RdbManager } from '../database/RdbManager'
import { ReminderInstance, ReminderInstanceStatus } from '../model/ReminderInstance'

export class ReminderInstanceRepository {
  private static readonly TABLE_NAME: string = 'reminder_instances'

  static async getInstancesByEventId(context: Context, eventId: number): Promise<ReminderInstance[]> {
    const rdb = await RdbManager.getRdb(context)
    const result = await rdb.querySql(
      `SELECT * FROM ${ReminderInstanceRepository.TABLE_NAME} WHERE eventId = ? ORDER BY reminderTime ASC`,
      [eventId]
    )
    const instances: ReminderInstance[] = []

    try {
      while (result.goToNextRow()) {
        instances.push(ReminderInstanceRepository.fromResultRow(result))
      }
    } finally {
      result.close()
    }

    return instances
  }

  static async getFutureInstancesByEventId(
    context: Context,
    eventId: number,
    fromTime: number = Date.now()
  ): Promise<ReminderInstance[]> {
    const rdb = await RdbManager.getRdb(context)
    const result = await rdb.querySql(
      `SELECT * FROM ${ReminderInstanceRepository.TABLE_NAME} WHERE eventId = ? AND reminderTime > ? ORDER BY reminderTime ASC`,
      [eventId, fromTime]
    )
    const instances: ReminderInstance[] = []

    try {
      while (result.goToNextRow()) {
        instances.push(ReminderInstanceRepository.fromResultRow(result))
      }
    } finally {
      result.close()
    }

    return instances
  }

  static async addInstance(context: Context, instance: ReminderInstance): Promise<number> {
    const rdb = await RdbManager.getRdb(context)
    const now = Date.now()
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
  }

  static async updateInstance(context: Context, instance: ReminderInstance): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('id', instance.id)
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
  }

  static async deleteInstance(context: Context, id: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('id', id)
    await rdb.delete(predicates)
  }

  static async deleteInstancesByEventId(context: Context, eventId: number): Promise<void> {
    const rdb = await RdbManager.getRdb(context)
    const predicates = new relationalStore.RdbPredicates(ReminderInstanceRepository.TABLE_NAME)
    predicates.equalTo('eventId', eventId)
    await rdb.delete(predicates)
  }

  private static fromResultRow(result: relationalStore.ResultSet): ReminderInstance {
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

    return {
      id: result.getLong(result.getColumnIndex('id')),
      eventId: result.getLong(result.getColumnIndex('eventId')),
      occurrenceDate: result.getLong(result.getColumnIndex('occurrenceDate')),
      reminderTime: result.getLong(result.getColumnIndex('reminderTime')),
      calendarEventId: getNullableLong(result.getColumnIndex('calendarEventId')),
      agentReminderId: getNullableLong(result.getColumnIndex('agentReminderId')),
      status: (getNullableString(result.getColumnIndex('status')) as ReminderInstanceStatus | undefined) ?? 'scheduled',
      reason: getNullableString(result.getColumnIndex('reason')),
      createTime: getNullableLong(result.getColumnIndex('createTime')) ?? Date.now(),
      updateTime: getNullableLong(result.getColumnIndex('updateTime')) ?? Date.now()
    }
  }
}
