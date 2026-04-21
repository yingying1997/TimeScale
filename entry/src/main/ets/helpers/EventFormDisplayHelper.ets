import { DateUtils } from '../utils/DateUtils'

export type DisplayRepeatType = 'none' | 'yearly' | 'monthly'
export type DisplayReminderType = 'on_day' | 'one_day_before' | 'none'

export class EventFormDisplayHelper {
  static buildEventDateDisplayText(selectedDate: Date, isLunarDate: boolean): string {
    if (isLunarDate) {
      return DateUtils.formatLunarDate(selectedDate.getTime())
    }
    return DateUtils.formatSolarDate(selectedDate.getTime())
  }

  static buildRepeatDisplayText(repeatType: DisplayRepeatType): string {
    if (repeatType === 'yearly') {
      return '每年重复'
    }
    if (repeatType === 'monthly') {
      return '每月重复'
    }
    return '不重复'
  }

  static buildReminderDisplayText(reminderType: DisplayReminderType, reminderHour: number, reminderMinute: number): string {
    if (reminderType === 'none') {
      return '不提醒'
    }
    const modeText = reminderType === 'on_day' ? '当天' : '提前一天'
    const timeText = `${reminderHour.toString().padStart(2, '0')}:${reminderMinute.toString().padStart(2, '0')}`
    return `${modeText} ${timeText}`
  }
}
