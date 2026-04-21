import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { calendarManager } from '@kit.CalendarKit'
import { EventItem } from '../model/EventItem'
import { AppTheme } from '../theme/AppTheme'
import { AppLogger } from '../utils/AppLogger'
import { EventOccurrenceService } from './EventOccurrenceService'

export interface ReminderSyncResult {
  scheduled: boolean
  calendarScheduled?: boolean
  agentScheduled?: boolean
  calendarEventId?: number
  agentReminderId?: number
  reason?: 'disabled' | 'past' | 'permission_denied' | 'notification_disabled' | 'publish_failed'
  errorCode?: number
  errorMessage?: string
}

export class ReminderService {
  private static readonly ACCOUNT_NAME: string = 'timescale_calendar'
  private static readonly ACCOUNT_DISPLAY_NAME: string = 'TimeScale'
  private static readonly CALENDAR_PERMISSIONS: Permissions[] = [
    'ohos.permission.READ_CALENDAR',
    'ohos.permission.WRITE_CALENDAR'
  ]
  static async syncReminder(context: common.UIAbilityContext, event: EventItem): Promise<ReminderSyncResult> {
    if (event.reminderType === 'none' || event.reminderHour === undefined || event.reminderMinute === undefined) {
      if (event.calendarEventId !== undefined) {
        await ReminderService.cancelReminder(context, event.calendarEventId)
      }
      if (event.agentReminderId !== undefined) {
        await ReminderService.cancelAgentReminder(event.agentReminderId)
      }
      event.calendarEventId = undefined
      event.agentReminderId = undefined
      return { scheduled: false, reason: 'disabled' }
    }

    const reminderDate = ReminderService.getNextReminderDate(event)
    if (!reminderDate || reminderDate.getTime() <= Date.now()) {
      if (event.calendarEventId !== undefined) {
        await ReminderService.cancelReminder(context, event.calendarEventId)
      }
      if (event.agentReminderId !== undefined) {
        await ReminderService.cancelAgentReminder(event.agentReminderId)
      }
      event.calendarEventId = undefined
      event.agentReminderId = undefined
      return { scheduled: false, reason: 'past' }
    }

    if (event.calendarEventId !== undefined) {
      await ReminderService.cancelReminder(context, event.calendarEventId)
      event.calendarEventId = undefined
    }
    if (event.agentReminderId !== undefined) {
      await ReminderService.cancelAgentReminder(event.agentReminderId)
      event.agentReminderId = undefined
    }

    const result = await ReminderService.scheduleReminderAt(context, event, reminderDate)
    event.calendarEventId = result.calendarEventId
    event.agentReminderId = result.agentReminderId
    return result
  }

  static async scheduleReminderAt(
    context: common.UIAbilityContext,
    event: EventItem,
    reminderDate: Date
  ): Promise<ReminderSyncResult> {
    if (event.reminderType === 'none' || event.reminderHour === undefined || event.reminderMinute === undefined) {
      return { scheduled: false, reason: 'disabled' }
    }

    if (reminderDate.getTime() <= Date.now()) {
      return { scheduled: false, reason: 'past' }
    }

    const result: ReminderSyncResult = {
      scheduled: false,
      calendarScheduled: false,
      agentScheduled: false
    }

    const calendarGranted = await ReminderService.ensureCalendarPermission(context)
    if (calendarGranted) {
      try {
        const calendar = await ReminderService.getOrCreateCalendar(context)
        const calendarEvent = ReminderService.buildCalendarEvent(event, reminderDate)
        result.calendarEventId = await calendar.addEvent(calendarEvent)
        result.calendarScheduled = true
        result.scheduled = true
      } catch (error) {
        const businessError = error as BusinessError
        AppLogger.error('ReminderService',
          `Failed to schedule calendar event. eventId=${event.id}, code=${businessError.code}, message=${businessError.message}`)
        result.reason = 'publish_failed'
        result.errorCode = businessError.code
        result.errorMessage = businessError.message
      }
    } else {
      AppLogger.warn('ReminderService', `Calendar permission denied. eventId=${event.id}`)
      result.reason = 'permission_denied'
    }

    if (result.scheduled) {
      return result
    }

    return {
      scheduled: false,
      calendarScheduled: false,
      agentScheduled: false,
      reason: result.reason ?? 'publish_failed',
      errorCode: result.errorCode,
      errorMessage: result.errorMessage
    }
  }

  static async cancelReminder(context: common.UIAbilityContext | Context, calendarEventId?: number): Promise<void> {
    if (calendarEventId === undefined) {
      return
    }

    try {
      const calendar = await ReminderService.getOrCreateCalendar(context)
      await calendar.deleteEvent(calendarEventId)
    } catch (error) {
      const businessError = error as BusinessError
      AppLogger.error('ReminderService',
        `Failed to delete calendar event. calendarEventId=${calendarEventId}, code=${businessError.code}, message=${businessError.message}`)
    }
  }

  static async cancelAgentReminder(agentReminderId?: number): Promise<void> {
    if (agentReminderId === undefined) {
      return
    }

    try {
      await reminderAgentManager.cancelReminder(agentReminderId)
    } catch (error) {
      const businessError = error as BusinessError
      AppLogger.error('ReminderService',
        `Failed to cancel agent reminder. agentReminderId=${agentReminderId}, code=${businessError.code}, message=${businessError.message}`)
    }
  }

  private static async ensureCalendarPermission(context: common.UIAbilityContext): Promise<boolean> {
    return ReminderService.ensurePermissions(context, ReminderService.CALENDAR_PERMISSIONS, 'calendar')
  }

  private static async ensurePermissions(
    context: common.UIAbilityContext,
    permissions: Permissions[],
    label: string
  ): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      const granted = result.authResults.every((item: number) => item === 0)
      return granted
    } catch (error) {
      const businessError = error as BusinessError
      if (businessError.code === 12100011) {
        return true
      }
      AppLogger.error('ReminderService',
        `Failed to request ${label} permissions. code=${businessError.code}, message=${businessError.message}`)
      return false
    }
  }

  private static async getOrCreateCalendar(context: common.UIAbilityContext | Context): Promise<calendarManager.Calendar> {
    try {
      const manager = calendarManager.getCalendarManager(context)
      const calendars = await manager.getAllCalendars()
      for (let i = 0; i < calendars.length; i++) {
        const account = ReminderService.getCalendarAccountSafely(calendars[i])
        if (account && account.name === ReminderService.ACCOUNT_NAME && account.type === calendarManager.CalendarType.LOCAL) {
          await ReminderService.ensureCalendarReminderEnabled(calendars[i])
          return calendars[i]
        }
      }

      const account: calendarManager.CalendarAccount = {
        name: ReminderService.ACCOUNT_NAME,
        type: calendarManager.CalendarType.LOCAL,
        displayName: ReminderService.ACCOUNT_DISPLAY_NAME
      }
      const calendar = await manager.createCalendar(account)
      await ReminderService.ensureCalendarReminderEnabled(calendar)
      return calendar
    } catch (error) {
      const businessError = error as BusinessError
      AppLogger.error('ReminderService',
        `Failed to get or create calendar. code=${businessError.code}, message=${businessError.message}`)
      throw new Error(`${error}`)
    }
  }

  private static async ensureCalendarReminderEnabled(calendar: calendarManager.Calendar): Promise<void> {
    try {
      await calendar.setConfig({
        enableReminder: true,
        color: AppTheme.COLOR_PRIMARY
      })
    } catch (error) {
      const businessError = error as BusinessError
      AppLogger.warn('ReminderService',
        `Failed to enable calendar reminder. code=${businessError.code}, message=${businessError.message}`)
    }
  }

  private static getCalendarAccountSafely(calendar: calendarManager.Calendar): calendarManager.CalendarAccount | undefined {
    try {
      return calendar.getAccount()
    } catch (error) {
      const businessError = error as BusinessError
      AppLogger.warn('ReminderService',
        `Failed to read calendar account. code=${businessError.code}, message=${businessError.message}`)
      return undefined
    }
  }

  private static buildCalendarEvent(event: EventItem, reminderDate: Date): calendarManager.Event {
    const startTime = reminderDate.getTime()
    const endTime = startTime + 10 * 60 * 1000
    const calendarEvent: calendarManager.Event = {
      type: calendarManager.EventType.NORMAL,
      title: ReminderService.buildCalendarTitle(event),
      startTime,
      endTime,
      isAllDay: false,
      isLunar: false,
      timeZone: 'Asia/Shanghai',
      reminderTime: [0],
      description: ReminderService.buildReminderDescription(event),
      identifier: `timescale-event-${event.id}-${reminderDate.getTime()}`,
    }

    return calendarEvent
  }

  private static buildCalendarTitle(event: EventItem): string {
    if (event.reminderType === 'one_day_before') {
      return `明天：${event.title}`
    }
    return `今天：${event.title}`
  }

  private static buildReminderDescription(event: EventItem): string {
    if (event.note && event.note.trim().length > 0) {
      return event.note
    }
    return event.reminderType === 'one_day_before' ? '你设置的事件将在明天到来' : '你设置的事件今天到来'
  }

  private static buildRecurrenceRule(event: EventItem): calendarManager.RecurrenceRule | undefined {
    const calendarType = event.calendarType ?? (event.isLunarDate ? 'lunar' : 'solar')
    if (calendarType === 'lunar') {
      return undefined
    }

    const targetDate = new Date(event.targetDate)
    const solarMonth = event.solarMonth ?? (targetDate.getMonth() + 1)
    const solarDay = event.solarDay ?? targetDate.getDate()
    if (event.repeatType === 'yearly') {
      if (solarMonth === 2 && solarDay === 29) {
        return undefined
      }
      return {
        recurrenceFrequency: calendarManager.RecurrenceFrequency.YEARLY,
        interval: 1,
        monthsOfYear: [solarMonth],
        daysOfMonth: [solarDay]
      }
    }

    if (event.repeatType === 'monthly') {
      if (solarDay > 28) {
        return undefined
      }
      return {
        recurrenceFrequency: calendarManager.RecurrenceFrequency.MONTHLY,
        interval: 1,
        daysOfMonth: [solarDay]
      }
    }

    return undefined
  }

  private static getNextReminderDate(event: EventItem): Date | null {
    const now = Date.now()
    let reminderDate = EventOccurrenceService.getReminderDate(event)
    if (reminderDate.getTime() > now) {
      return reminderDate
    }

    if (event.repeatType === 'monthly' || event.repeatType === 'yearly') {
      const nextBaseDate = ReminderService.getNextSearchBaseDate(event, reminderDate)
      reminderDate = EventOccurrenceService.getReminderDate(event, nextBaseDate)
      return reminderDate.getTime() > now ? reminderDate : null
    }

    return null
  }

  private static getNextSearchBaseDate(event: EventItem, reminderDate: Date): Date {
    const baseDate = new Date(reminderDate.getTime())
    if (event.reminderType === 'one_day_before') {
      baseDate.setDate(baseDate.getDate() + 1)
    }
    baseDate.setDate(baseDate.getDate() + 1)
    return baseDate
  }
}
