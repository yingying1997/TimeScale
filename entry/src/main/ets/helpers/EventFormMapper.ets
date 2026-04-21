import { CalendarType, EventItem, ReminderType as EventReminderType } from '../model/EventItem'
import { LunarDateService } from '../services/LunarDateService'

export type FormRepeatType = 'none' | 'yearly' | 'monthly'
export type FormReminderType = 'on_day' | 'one_day_before' | 'none'

export class EventFormStateData {
  isEditing: boolean = false
  eventId: number = 0
  currentSortIndex: number = 0
  currentCreateTime: number = 0
  currentCalendarEventId?: number = undefined
  currentAgentReminderId?: number = undefined
  selectedColor: string = '#2563EB'
  isLunarDate: boolean = false
  title: string = ''
  note: string = ''
  selectedDate: Date = new Date()
  repeatType: FormRepeatType = 'none'
  reminderType: FormReminderType = 'none'
  reminderHour: number = 12
  reminderMinute: number = 0
}

export class EventRecord implements EventItem {
  id: number = 0
  title: string = ''
  targetDate: number = 0
  sortIndex: number = 0
  themeColor?: string = undefined
  isLunarDate?: boolean = undefined
  note?: string = undefined
  reminderType?: EventReminderType = undefined
  reminderHour?: number = undefined
  reminderMinute?: number = undefined
  createTime: number = 0
  repeatType?: 'none' | 'monthly' | 'yearly' = undefined
  calendarEventId?: number = undefined
  agentReminderId?: number = undefined
  calendarType?: CalendarType = undefined
  solarMonth?: number = undefined
  solarDay?: number = undefined
  lunarMonth?: number = undefined
  lunarDay?: number = undefined
  isLeapMonth?: boolean = undefined
}

export class BuildEventRecordParams {
  id: number = 0
  title: string = ''
  selectedDate: Date = new Date()
  sortIndex: number = 0
  selectedColor: string = '#2563EB'
  isLunarDate: boolean = false
  note: string = ''
  reminderType: FormReminderType = 'none'
  reminderHour: number = 12
  reminderMinute: number = 0
  createTime: number = 0
  repeatType: FormRepeatType = 'none'
  calendarEventId?: number = undefined
  agentReminderId?: number = undefined
}

export class EventFormMapper {
  static createEmpty(primaryColor: string): EventFormStateData {
    const state = new EventFormStateData()
    state.selectedColor = primaryColor
    state.selectedDate = new Date()
    return state
  }

  static fromEvent(event: EventItem, primaryColor: string): EventFormStateData {
    const state = new EventFormStateData()
    state.isEditing = true
    state.eventId = event.id
    state.currentSortIndex = event.sortIndex
    state.currentCreateTime = event.createTime
    state.currentCalendarEventId = event.calendarEventId
    state.currentAgentReminderId = event.agentReminderId
    state.selectedColor = event.themeColor ?? primaryColor
    state.isLunarDate = event.isLunarDate ?? false
    state.title = event.title
    state.note = event.note ?? ''
    state.selectedDate = new Date(event.targetDate)
    state.repeatType = event.repeatType ?? 'none'
    state.reminderType = (event.reminderType as FormReminderType | undefined) ?? 'none'
    state.reminderHour = event.reminderHour ?? 12
    state.reminderMinute = event.reminderMinute ?? 0
    return state
  }

  static buildEventRecord(params: BuildEventRecordParams): EventItem {
    const event = new EventRecord()
    const selectedDate = new Date(params.selectedDate.getTime())
    const lunarInfo = params.isLunarDate ? LunarDateService.getLunarDateInfo(selectedDate) : undefined
    event.id = params.id
    event.title = params.title.trim()
    event.targetDate = selectedDate.getTime()
    event.sortIndex = params.sortIndex
    event.themeColor = params.selectedColor
    event.isLunarDate = params.isLunarDate
    event.note = params.note.trim()
    event.reminderType = params.reminderType as EventReminderType
    event.reminderHour = params.reminderType === 'none' ? undefined : params.reminderHour
    event.reminderMinute = params.reminderType === 'none' ? undefined : params.reminderMinute
    event.createTime = params.createTime
    event.repeatType = params.repeatType
    event.calendarEventId = params.calendarEventId
    event.agentReminderId = params.agentReminderId
    event.calendarType = params.isLunarDate ? 'lunar' : 'solar'
    event.solarMonth = selectedDate.getMonth() + 1
    event.solarDay = selectedDate.getDate()
    event.lunarMonth = lunarInfo?.lunarMonth
    event.lunarDay = lunarInfo?.lunarDay
    event.isLeapMonth = lunarInfo?.isLeapMonth
    return event
  }

  static cloneEvent(event: EventItem, id: number, calendarEventId?: number, agentReminderId?: number): EventItem {
    const clone = new EventRecord()
    clone.id = id
    clone.title = event.title
    clone.targetDate = event.targetDate
    clone.sortIndex = event.sortIndex
    clone.themeColor = event.themeColor
    clone.isLunarDate = event.isLunarDate
    clone.note = event.note
    clone.reminderType = event.reminderType
    clone.reminderHour = event.reminderHour
    clone.reminderMinute = event.reminderMinute
    clone.createTime = event.createTime
    clone.repeatType = event.repeatType
    clone.calendarEventId = calendarEventId
    clone.agentReminderId = agentReminderId
    clone.calendarType = event.calendarType
    clone.solarMonth = event.solarMonth
    clone.solarDay = event.solarDay
    clone.lunarMonth = event.lunarMonth
    clone.lunarDay = event.lunarDay
    clone.isLeapMonth = event.isLeapMonth
    return clone
  }
}
