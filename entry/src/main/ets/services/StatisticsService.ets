import { EventItem } from '../model/EventItem'
import { AppTheme } from '../theme/AppTheme'
import { EventOccurrenceService } from './EventOccurrenceService'

export interface CountdownBucket {
  key: 'today' | 'week' | 'month' | 'later' | 'past'
  label: string
  value: number
  color: string
}

export interface RepeatBucket {
  key: 'none' | 'monthly' | 'yearly'
  label: string
  value: number
  color: string
}

export interface CalendarBucket {
  key: 'solar' | 'lunar'
  label: string
  value: number
  color: string
}

export interface StatisticsSummary {
  totalCount: number
  next7DaysCount: number
  next30DaysCount: number
  reminderOnCount: number
}

export interface MonthReminderStats {
  monthEventCount: number
  reminderCount: number
  noReminderCount: number
}

export interface StatisticsDashboard {
  summary: StatisticsSummary
  countdownBuckets: CountdownBucket[]
  repeatBuckets: RepeatBucket[]
  calendarBuckets: CalendarBucket[]
  monthlyTrend: number[]
  monthReminder: MonthReminderStats
  insights: string[]
}

export class StatisticsService {
  static emptyDashboard(): StatisticsDashboard {
    return {
      summary: {
        totalCount: 0,
        next7DaysCount: 0,
        next30DaysCount: 0,
        reminderOnCount: 0
      },
      countdownBuckets: [],
      repeatBuckets: [],
      calendarBuckets: [],
      monthlyTrend: new Array<number>(12).fill(0),
      monthReminder: {
        monthEventCount: 0,
        reminderCount: 0,
        noReminderCount: 0
      },
      insights: []
    }
  }

  static buildDashboard(eventList: EventItem[], baseDate: Date = new Date()): StatisticsDashboard {
    const summary = StatisticsService.summary(eventList, baseDate)
    const monthlyTrend = StatisticsService.monthlyTrend(eventList, baseDate)
    const monthReminder = StatisticsService.monthReminderStats(eventList, baseDate)
    return {
      summary: summary,
      countdownBuckets: StatisticsService.countdownBuckets(eventList, baseDate),
      repeatBuckets: StatisticsService.repeatBuckets(eventList),
      calendarBuckets: StatisticsService.calendarBuckets(eventList),
      monthlyTrend: monthlyTrend,
      monthReminder: monthReminder,
      insights: StatisticsService.insightTexts(summary, monthlyTrend, baseDate)
    }
  }

  static countdownBuckets(eventList: EventItem[], baseDate: Date = new Date()): CountdownBucket[] {
    let overdue = 0
    let today = 0
    let week = 0
    let month = 0
    let later = 0

    eventList.forEach((item: EventItem) => {
      const info = EventOccurrenceService.resolveStatusInfo(item, baseDate)
      if (info.status === 'past') {
        overdue++
      } else if (info.status === 'today') {
        today++
      } else if (info.days <= 7) {
        week++
      } else if (info.days <= 30) {
        month++
      } else {
        later++
      }
    })

    return [
      { key: 'today', label: '今天', value: today, color: AppTheme.COLOR_DANGER },
      { key: 'week', label: '1-7天', value: week, color: AppTheme.COLOR_WARNING },
      { key: 'month', label: '8-30天', value: month, color: AppTheme.COLOR_SUCCESS },
      { key: 'later', label: '30天+', value: later, color: AppTheme.COLOR_INFO },
      { key: 'past', label: '已过', value: overdue, color: AppTheme.COLOR_ACCENT }
    ]
  }

  static repeatBuckets(eventList: EventItem[]): RepeatBucket[] {
    let oneTime = 0
    let monthly = 0
    let yearly = 0

    eventList.forEach((item: EventItem) => {
      if (item.repeatType === 'monthly') {
        monthly++
      } else if (item.repeatType === 'yearly') {
        yearly++
      } else {
        oneTime++
      }
    })

    return [
      { key: 'none', label: '单次', value: oneTime, color: AppTheme.COLOR_TEXT_MUTED },
      { key: 'monthly', label: '每月', value: monthly, color: AppTheme.COLOR_SKY },
      { key: 'yearly', label: '每年', value: yearly, color: AppTheme.COLOR_PRIMARY }
    ]
  }

  static calendarBuckets(eventList: EventItem[]): CalendarBucket[] {
    let solar = 0
    let lunar = 0

    eventList.forEach((item: EventItem) => {
      const calendarType = item.calendarType ?? (item.isLunarDate ? 'lunar' : 'solar')
      if (calendarType === 'lunar') {
        lunar++
      } else {
        solar++
      }
    })

    return [
      { key: 'solar', label: '公历', value: solar, color: AppTheme.COLOR_SUCCESS },
      { key: 'lunar', label: '农历', value: lunar, color: AppTheme.COLOR_ORANGE }
    ]
  }

  static monthlyTrend(eventList: EventItem[], baseDate: Date = new Date()): number[] {
    const list: number[] = new Array<number>(12).fill(0)
    const monthStart = new Date(baseDate.getFullYear(), baseDate.getMonth(), 1).getTime()
    const monthEnd = new Date(baseDate.getFullYear(), baseDate.getMonth() + 12, 1).getTime()

    eventList.forEach((item: EventItem) => {
      const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(item, baseDate)
      const occurrenceTimestamp = occurrenceDate.getTime()
      if (occurrenceTimestamp < monthStart || occurrenceTimestamp >= monthEnd) {
        return
      }
      const eventDate = occurrenceDate
      const index = (eventDate.getFullYear() - baseDate.getFullYear()) * 12 + (eventDate.getMonth() - baseDate.getMonth())
      if (index >= 0 && index < 12) {
        list[index] = list[index] + 1
      }
    })

    return list
  }

  static monthLabel(offset: number, baseDate: Date = new Date()): string {
    const date = new Date(baseDate.getFullYear(), baseDate.getMonth() + offset, 1)
    return `${date.getMonth() + 1}月`
  }

  static summary(eventList: EventItem[], baseDate: Date = new Date()): StatisticsSummary {
    return {
      totalCount: eventList.length,
      next7DaysCount: eventList.filter((item: EventItem) => {
        const info = EventOccurrenceService.resolveStatusInfo(item, baseDate)
        return info.status === 'today' || (info.status === 'future' && info.days <= 7)
      }).length,
      next30DaysCount: eventList.filter((item: EventItem) => {
        const info = EventOccurrenceService.resolveStatusInfo(item, baseDate)
        return info.status === 'today' || (info.status === 'future' && info.days <= 30)
      }).length,
      reminderOnCount: eventList.filter((item: EventItem) => item.reminderType !== undefined && item.reminderType !== 'none').length
    }
  }

  static monthReminderStats(eventList: EventItem[], baseDate: Date = new Date()): MonthReminderStats {
    const monthEventCount = eventList.filter((item: EventItem) => {
      return StatisticsService.isOccurrenceInMonth(item, baseDate)
    }).length
    const reminderCount = eventList.filter((item: EventItem) => {
      return StatisticsService.isOccurrenceInMonth(item, baseDate) && StatisticsService.isReminderEnabled(item)
    }).length
    return {
      monthEventCount: monthEventCount,
      reminderCount: reminderCount,
      noReminderCount: Math.max(0, monthEventCount - reminderCount)
    }
  }

  static insightTexts(
    summary: StatisticsSummary,
    monthlyTrend: number[],
    baseDate: Date
  ): string[] {
    const texts: string[] = []

    const reminderText = StatisticsService.reminderGapInsight(summary)
    if (reminderText.length > 0) {
      texts.push(reminderText)
    }

    const peakText = StatisticsService.busiestMonthInsight(monthlyTrend, baseDate)
    if (peakText.length > 0) {
      texts.push(peakText)
    }

    const spreadText = StatisticsService.yearSpreadInsight(monthlyTrend)
    if (spreadText.length > 0) {
      texts.push(spreadText)
    }

    return texts
  }

  private static isOccurrenceInMonth(item: EventItem, baseDate: Date): boolean {
    const occurrenceDate = EventOccurrenceService.resolveOccurrenceDate(item, baseDate)
    return occurrenceDate.getFullYear() === baseDate.getFullYear() && occurrenceDate.getMonth() === baseDate.getMonth()
  }

  private static isReminderEnabled(item: EventItem): boolean {
    return item.reminderType !== undefined && item.reminderType !== 'none'
  }

  private static reminderGapInsight(summary: StatisticsSummary): string {
    if (summary.totalCount <= 0) {
      return ''
    }
    const noReminderCount = summary.totalCount - summary.reminderOnCount
    if (noReminderCount <= 0) {
      return '所有记录都已设置提醒，提醒覆盖比较完整。'
    }
    return `还有 ${noReminderCount} 个记录没有提醒，可按重要程度补充。`
  }

  private static busiestMonthInsight(monthlyTrend: number[], baseDate: Date): string {
    let maxCount = 0
    let maxIndex = 0
    monthlyTrend.forEach((count: number, index: number) => {
      if (count > maxCount) {
        maxCount = count
        maxIndex = index
      }
    })
    if (maxCount <= 0) {
      return ''
    }
    return `未来一年里，${StatisticsService.monthLabel(maxIndex, baseDate)}是高峰月份，共 ${maxCount} 个重要日子。`
  }

  private static yearSpreadInsight(monthlyTrend: number[]): string {
    const activeMonthCount = monthlyTrend.filter((count: number) => count > 0).length
    if (activeMonthCount <= 0) {
      return ''
    }
    if (activeMonthCount <= 3) {
      return `未来一年的记录集中在 ${activeMonthCount} 个月，适合提前关注高峰月份。`
    }
    return `未来一年的记录分布在 ${activeMonthCount} 个月，整体节奏比较分散。`
  }
}
