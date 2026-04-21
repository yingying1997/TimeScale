import { common } from '@kit.AbilityKit'
import { EventItem } from '../model/EventItem'
import { ReminderInstance } from '../model/ReminderInstance'
import { EventRepository } from '../repository/EventRepository'
import { ReminderInstanceRepository } from '../repository/ReminderInstanceRepository'
import { AppLogger } from '../utils/AppLogger'
import { ReminderOccurrence, ReminderOccurrenceGenerator } from './ReminderOccurrenceGenerator'
import { ReminderService, ReminderSyncResult } from './ReminderService'

export interface ReminderProvider {
  scheduleReminderAt(abilityContext: common.UIAbilityContext, event: EventItem, reminderDate: Date): Promise<ReminderSyncResult>
  cancelReminder(abilityContext: common.UIAbilityContext | Context, calendarEventId?: number): Promise<void>
  cancelAgentReminder(agentReminderId?: number): Promise<void>
}

export interface ReminderInstanceStore {
  getInstancesByEventId(context: Context, eventId: number): Promise<ReminderInstance[]>
  getFutureInstancesByEventId(context: Context, eventId: number, fromTime?: number): Promise<ReminderInstance[]>
  addInstance(context: Context, instance: ReminderInstance): Promise<number>
  deleteInstance(context: Context, id: number): Promise<void>
}

class SystemReminderProvider implements ReminderProvider {
  async scheduleReminderAt(
    abilityContext: common.UIAbilityContext,
    event: EventItem,
    reminderDate: Date
  ): Promise<ReminderSyncResult> {
    return ReminderService.scheduleReminderAt(abilityContext, event, reminderDate)
  }

  async cancelReminder(
    abilityContext: common.UIAbilityContext | Context,
    calendarEventId?: number
  ): Promise<void> {
    await ReminderService.cancelReminder(abilityContext, calendarEventId)
  }

  async cancelAgentReminder(agentReminderId?: number): Promise<void> {
    await ReminderService.cancelAgentReminder(agentReminderId)
  }
}

class RdbReminderInstanceStore implements ReminderInstanceStore {
  async getInstancesByEventId(context: Context, eventId: number): Promise<ReminderInstance[]> {
    return ReminderInstanceRepository.getInstancesByEventId(context, eventId)
  }

  async getFutureInstancesByEventId(context: Context, eventId: number, fromTime?: number): Promise<ReminderInstance[]> {
    return ReminderInstanceRepository.getFutureInstancesByEventId(context, eventId, fromTime)
  }

  async addInstance(context: Context, instance: ReminderInstance): Promise<number> {
    return ReminderInstanceRepository.addInstance(context, instance)
  }

  async deleteInstance(context: Context, id: number): Promise<void> {
    await ReminderInstanceRepository.deleteInstance(context, id)
  }
}

export class ReminderScheduleResult {
  scheduled: boolean = false
  calendarScheduled: boolean = false
  agentScheduled: boolean = false
  plannedCount: number = 0
  calendarSuccessCount: number = 0
  agentSuccessCount: number = 0
  scheduledCount: number = 0
  partialCount: number = 0
  failedCount: number = 0
  reason?: 'disabled' | 'past' | 'permission_denied' | 'notification_disabled' | 'publish_failed' = undefined
  errorCode?: number = undefined
}

export class ReminderScheduleService {
  private static reminderProvider: ReminderProvider = new SystemReminderProvider()
  private static reminderInstanceStore: ReminderInstanceStore = new RdbReminderInstanceStore()

  static setReminderProviderForTest(provider: ReminderProvider | undefined): void {
    ReminderScheduleService.reminderProvider = provider ?? new SystemReminderProvider()
  }

  static setReminderInstanceStoreForTest(store: ReminderInstanceStore | undefined): void {
    ReminderScheduleService.reminderInstanceStore = store ?? new RdbReminderInstanceStore()
  }

  static async rebuildEventSchedule(
    abilityContext: common.UIAbilityContext,
    dataContext: Context,
    event: EventItem
  ): Promise<ReminderScheduleResult> {
    await ReminderScheduleService.cancelEventSchedule(abilityContext, dataContext, event)
    event.calendarEventId = undefined
    event.agentReminderId = undefined

    if (ReminderScheduleService.isReminderDisabled(event)) {
      return ReminderScheduleService.disabledResult()
    }

    return ReminderScheduleService.ensureEventSchedule(abilityContext, dataContext, event)
  }

  static async ensureAllSchedules(
    abilityContext: common.UIAbilityContext,
    dataContext: Context
  ): Promise<void> {
    const events = await EventRepository.getAllEvents(dataContext)
    for (let i = 0; i < events.length; i++) {
      try {
        await ReminderScheduleService.ensureEventSchedule(abilityContext, dataContext, events[i])
      } catch (error) {
        AppLogger.error('ReminderScheduleService',
          `Failed to ensure schedule. eventId=${events[i].id}, message=${error instanceof Error ? error.message : `${error}`}`)
      }
    }
  }

  static async cancelEventSchedule(
    abilityContext: common.UIAbilityContext | Context,
    dataContext: Context,
    event: EventItem
  ): Promise<void> {
    const instances = await ReminderScheduleService.reminderInstanceStore.getInstancesByEventId(dataContext, event.id)
    for (let i = 0; i < instances.length; i++) {
      await ReminderScheduleService.cancelInstance(abilityContext, instances[i])
      await ReminderScheduleService.reminderInstanceStore.deleteInstance(dataContext, instances[i].id)
    }

    await ReminderScheduleService.reminderProvider.cancelReminder(abilityContext, event.calendarEventId)
    await ReminderScheduleService.reminderProvider.cancelAgentReminder(event.agentReminderId)
  }

  static async ensureEventSchedule(
    abilityContext: common.UIAbilityContext,
    dataContext: Context,
    event: EventItem
  ): Promise<ReminderScheduleResult> {
    if (ReminderScheduleService.isReminderDisabled(event)) {
      await ReminderScheduleService.cancelEventSchedule(abilityContext, dataContext, event)
      event.calendarEventId = undefined
      event.agentReminderId = undefined
      await EventRepository.updateEvent(dataContext, event)
      return ReminderScheduleService.disabledResult()
    }

    if (event.calendarEventId !== undefined || event.agentReminderId !== undefined) {
      await ReminderScheduleService.reminderProvider.cancelReminder(abilityContext, event.calendarEventId)
      await ReminderScheduleService.reminderProvider.cancelAgentReminder(event.agentReminderId)
      event.calendarEventId = undefined
      event.agentReminderId = undefined
      await EventRepository.updateEvent(dataContext, event)
    }

    await ReminderScheduleService.cleanupExpiredInstances(abilityContext, dataContext, event.id)

    const occurrences = ReminderOccurrenceGenerator.generateFutureOccurrences(event)
    if (occurrences.length === 0) {
      return ReminderScheduleService.pastResult()
    }

    const existingInstances = await ReminderScheduleService.reminderInstanceStore.getFutureInstancesByEventId(dataContext, event.id)
    await ReminderScheduleService.removeRetryableFailedInstances(abilityContext, dataContext, existingInstances)

    const existingTimes = new Set<number>()
    const refreshedInstances = await ReminderScheduleService.reminderInstanceStore.getFutureInstancesByEventId(dataContext, event.id)
    refreshedInstances.forEach((instance: ReminderInstance) => {
      if (instance.status === 'scheduled') {
        existingTimes.add(instance.reminderTime)
      }
    })

    const result = new ReminderScheduleResult()
    result.plannedCount = occurrences.length
    for (let i = 0; i < occurrences.length; i++) {
      const occurrence = occurrences[i]
      const reminderTime = occurrence.reminderDate.getTime()
      if (existingTimes.has(reminderTime)) {
        result.scheduled = true
        result.scheduledCount = result.scheduledCount + 1
        continue
      }

      const syncResult = await ReminderScheduleService.reminderProvider.scheduleReminderAt(abilityContext, event, occurrence.reminderDate)
      await ReminderScheduleService.saveInstanceResult(dataContext, event, occurrence, syncResult)
      ReminderScheduleService.mergeSyncResult(result, syncResult)
    }

    return result
  }

  private static async saveInstanceResult(
    dataContext: Context,
    event: EventItem,
    occurrence: ReminderOccurrence,
    syncResult: ReminderSyncResult
  ): Promise<void> {
    const now = Date.now()
    const instance: ReminderInstance = {
      id: 0,
      eventId: event.id,
      occurrenceDate: occurrence.occurrenceDate.getTime(),
      reminderTime: occurrence.reminderDate.getTime(),
      calendarEventId: syncResult.calendarEventId,
      agentReminderId: syncResult.agentReminderId,
      status: (syncResult.calendarScheduled === true || syncResult.agentScheduled === true || syncResult.scheduled) ? 'scheduled' : 'failed',
      reason: syncResult.reason,
      createTime: now,
      updateTime: now
    }
    await ReminderScheduleService.reminderInstanceStore.addInstance(dataContext, instance)
  }

  private static mergeSyncResult(target: ReminderScheduleResult, source: ReminderSyncResult): void {
    const calendarScheduled = source.calendarScheduled === true
    target.calendarScheduled = target.calendarScheduled || calendarScheduled
    if (calendarScheduled) {
      target.calendarSuccessCount = target.calendarSuccessCount + 1
    }
    if (source.scheduled) {
      target.scheduled = true
      if (calendarScheduled) {
        target.scheduledCount = target.scheduledCount + 1
      } else {
        target.partialCount = target.partialCount + 1
        target.reason = source.reason
        target.errorCode = source.errorCode
      }
      return
    }

    if (calendarScheduled) {
      target.scheduled = true
      target.partialCount = target.partialCount + 1
    } else {
      target.failedCount = target.failedCount + 1
    }

    target.reason = source.reason
    target.errorCode = source.errorCode
  }

  private static async removeRetryableFailedInstances(
    abilityContext: common.UIAbilityContext,
    dataContext: Context,
    instances: ReminderInstance[]
  ): Promise<void> {
    for (let i = 0; i < instances.length; i++) {
      if (instances[i].status === 'scheduled') {
        continue
      }
      await ReminderScheduleService.cancelInstance(abilityContext, instances[i])
      await ReminderScheduleService.reminderInstanceStore.deleteInstance(dataContext, instances[i].id)
    }
  }

  private static async cleanupExpiredInstances(
    abilityContext: common.UIAbilityContext,
    dataContext: Context,
    eventId: number
  ): Promise<void> {
    const instances = await ReminderScheduleService.reminderInstanceStore.getInstancesByEventId(dataContext, eventId)
    const now = Date.now()
    for (let i = 0; i < instances.length; i++) {
      if (instances[i].reminderTime > now) {
        continue
      }
      await ReminderScheduleService.cancelInstance(abilityContext, instances[i])
      await ReminderScheduleService.reminderInstanceStore.deleteInstance(dataContext, instances[i].id)
    }
  }

  private static async cancelInstance(
    abilityContext: common.UIAbilityContext | Context,
    instance: ReminderInstance
  ): Promise<void> {
    await ReminderScheduleService.reminderProvider.cancelReminder(abilityContext, instance.calendarEventId)
    await ReminderScheduleService.reminderProvider.cancelAgentReminder(instance.agentReminderId)
  }

  private static isReminderDisabled(event: EventItem): boolean {
    return event.reminderType === 'none' || event.reminderHour === undefined || event.reminderMinute === undefined
  }

  private static disabledResult(): ReminderScheduleResult {
    const result = new ReminderScheduleResult()
    result.reason = 'disabled'
    return result
  }

  private static pastResult(): ReminderScheduleResult {
    const result = new ReminderScheduleResult()
    result.reason = 'past'
    return result
  }
}
