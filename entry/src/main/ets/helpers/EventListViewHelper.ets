import { EventItem } from '../model/EventItem'
import { EventOccurrenceService } from '../services/EventOccurrenceService'

export class EventListViewHelper {
  static filterEvents(eventList: EventItem[], keyword: string): EventItem[] {
    const trimmedKeyword = keyword.trim()
    if (trimmedKeyword.length === 0) {
      return [...eventList]
    }

    const normalizedKeyword = trimmedKeyword.toLowerCase()
    return eventList.filter((item: EventItem) => {
      return item.title.toLowerCase().includes(normalizedKeyword) ||
        (item.note !== undefined && item.note.toLowerCase().includes(normalizedKeyword))
    })
  }

  static formatDate(targetDate: number): string {
    return EventOccurrenceService.formatEventDateText({
      id: 0,
      title: '',
      targetDate: targetDate,
      sortIndex: 0,
      createTime: 0
    })
  }

  static formatEventDate(item: EventItem): string {
    return EventOccurrenceService.formatEventDateText(item)
  }

  static primaryDateText(item: EventItem): string {
    return EventOccurrenceService.formatPrimaryDateText(item)
  }

  static secondaryDateText(item: EventItem): string {
    return EventOccurrenceService.formatSecondaryDateText(item)
  }

  static isLunarEvent(item: EventItem): boolean {
    return EventOccurrenceService.isLunarEvent(item)
  }

  static repeatLabel(item: EventItem): string {
    if (item.repeatType === 'yearly') {
      return '每年重复'
    }
    if (item.repeatType === 'monthly') {
      return '每月重复'
    }
    return '单次事件'
  }

  static reminderLabel(item: EventItem): string {
    if (!item.reminderType || item.reminderType === 'none') {
      return '不提醒'
    }
    if (item.reminderType === 'one_day_before') {
      return '提前一天'
    }
    return '当天提醒'
  }

  static eventThemeColor(item: EventItem, defaultThemeColor: string): string {
    return item.themeColor ?? defaultThemeColor
  }

  static isToday(item: EventItem): boolean {
    return EventOccurrenceService.resolveStatusInfo(item).status === 'today'
  }

  static isPast(item: EventItem): boolean {
    return EventOccurrenceService.resolveStatusInfo(item).status === 'past'
  }

  static statusPrefix(item: EventItem): string {
    return EventOccurrenceService.resolveStatusInfo(item).status === 'future' ? '还有' : '已过'
  }

  static statusNumber(item: EventItem): string {
    return `${EventOccurrenceService.resolveStatusInfo(item).days}`
  }

  static statusUnit(item: EventItem): string {
    return EventOccurrenceService.resolveStatusInfo(item).status === 'today' ? '' : '天'
  }
}
