import { EventItem } from '../model/EventItem'

export class EventSortService {
  static reorderInPlace(eventList: EventItem[], fromIndex: number, toIndex: number): void {
    if (fromIndex < 0 || fromIndex >= eventList.length || toIndex < 0 || toIndex >= eventList.length || fromIndex === toIndex) {
      return
    }

    const movedItems = eventList.splice(fromIndex, 1)
    if (movedItems.length === 0) {
      return
    }

    eventList.splice(toIndex, 0, movedItems[0])
    EventSortService.normalizeSortIndexes(eventList)
  }

  static normalizeSortIndexes(eventList: EventItem[]): void {
    eventList.forEach((item: EventItem, index: number) => {
      item.sortIndex = index
    })
  }

  static canDragSort(keyword: string, totalCount: number): boolean {
    return keyword.trim().length === 0 && totalCount > 1
  }
}
