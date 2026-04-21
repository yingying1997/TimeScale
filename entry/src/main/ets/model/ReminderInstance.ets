export type ReminderInstanceStatus = 'scheduled' | 'failed' | 'cancelled'

export interface ReminderInstance {
  id: number
  eventId: number
  occurrenceDate: number
  reminderTime: number
  calendarEventId?: number
  agentReminderId?: number
  status: ReminderInstanceStatus
  reason?: string
  createTime: number
  updateTime: number
}
