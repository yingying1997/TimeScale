import { common } from '@kit.AbilityKit'
import { EventItem } from '../model/EventItem'
import { EventRepository } from '../repository/EventRepository'
import { ReminderScheduleResult, ReminderScheduleService } from './ReminderScheduleService'
import { EventFormMapper, EventRecord } from '../helpers/EventFormMapper'

export class ReminderSyncState {
  scheduled: boolean = false
  calendarScheduled: boolean = false
  agentScheduled: boolean = false
  plannedCount: number = 0
  calendarSuccessCount: number = 0
  agentSuccessCount: number = 0
  failedCount: number = 0
  partialCount: number = 0
  calendarEventId?: number = undefined
  agentReminderId?: number = undefined
  reason?: 'disabled' | 'past' | 'permission_denied' | 'notification_disabled' | 'publish_failed' = undefined
  errorCode?: number = undefined
}

export class EventSaveRequest {
  isEditing: boolean = false
  eventId: number = 0
  draftEvent: EventItem = new EventRecord()
}

export class EventSaveService {
  static async saveEvent(
    dataContext: Context,
    abilityContext: common.UIAbilityContext,
    request: EventSaveRequest
  ): Promise<ReminderSyncState> {
    const reminderResult = new ReminderSyncState()

    if (request.isEditing) {
      const latestEvent = await EventRepository.getEventById(dataContext, request.eventId)
      if (latestEvent) {
        request.draftEvent.sortIndex = latestEvent.sortIndex
        request.draftEvent.calendarEventId = latestEvent.calendarEventId
        request.draftEvent.agentReminderId = latestEvent.agentReminderId
      }
      const syncResult = await ReminderScheduleService.rebuildEventSchedule(
        abilityContext,
        dataContext,
        request.draftEvent
      )
      EventSaveService.applyReminderResult(reminderResult, syncResult)
      const updatedEvent = EventFormMapper.cloneEvent(
        request.draftEvent,
        request.draftEvent.id,
        undefined,
        undefined
      )
      await EventRepository.updateEvent(dataContext, updatedEvent)
      return reminderResult
    }

    const insertedId = await EventRepository.addEvent(dataContext, request.draftEvent)
    const createdEvent = EventFormMapper.cloneEvent(request.draftEvent, insertedId, request.draftEvent.calendarEventId)
    const insertedEvent = await EventRepository.getEventById(dataContext, insertedId)
    if (insertedEvent) {
      createdEvent.sortIndex = insertedEvent.sortIndex
    }
    const syncResult = await ReminderScheduleService.rebuildEventSchedule(
      abilityContext,
      dataContext,
      createdEvent
    )
    EventSaveService.applyReminderResult(reminderResult, syncResult)
    const updatedEvent = EventFormMapper.cloneEvent(
      createdEvent,
      insertedId,
      undefined,
      undefined
    )
    await EventRepository.updateEvent(dataContext, updatedEvent)
    return reminderResult
  }

  private static applyReminderResult(
    target: ReminderSyncState,
    source: ReminderScheduleResult
  ): void {
    target.scheduled = source.scheduled
    target.calendarScheduled = source.calendarScheduled
    target.agentScheduled = source.agentScheduled
    target.plannedCount = source.plannedCount
    target.calendarSuccessCount = source.calendarSuccessCount
    target.agentSuccessCount = source.agentSuccessCount
    target.failedCount = source.failedCount
    target.partialCount = source.partialCount
    target.calendarEventId = undefined
    target.agentReminderId = undefined
    target.reason = source.reason
    target.errorCode = source.errorCode
  }
}
