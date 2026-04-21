export type ReminderType = 'on_day' | 'one_day_before' | 'none';
export type CalendarType = 'solar' | 'lunar';

export interface EventItem {
  id: number;
  title: string;
  targetDate: number;
  sortIndex: number;
  themeColor?: string;
  isLunarDate?: boolean;
  note?: string;
  reminderType?: ReminderType;
  reminderHour?: number;
  reminderMinute?: number;
  createTime: number;
  repeatType?: 'none' | 'monthly' | 'yearly';
  calendarEventId?: number;
  agentReminderId?: number;
  calendarType?: CalendarType;
  solarMonth?: number;
  solarDay?: number;
  lunarMonth?: number;
  lunarDay?: number;
  isLeapMonth?: boolean;
}
