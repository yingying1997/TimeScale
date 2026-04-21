import { EventItem } from '../model/EventItem'
import { EventOccurrenceService } from './EventOccurrenceService'

export type CardEventStatus = 'future' | 'today' | 'past'

export class CardEventData {
  title: string = ''
  countdownText: string = ''
  color: string = '#8C939F'
  dateText: string = ''
  status: CardEventStatus = 'future'
}

export class CardDataPayload {
  firstTitle: string = '赶快去应用里添加吧！'

  event1Title: string = ''
  event1CountdownText: string = ''
  event1Color: string = '#8C939F'
  event1DateText: string = ''
  event1Status: CardEventStatus = 'future'

  event2Title: string = ''
  event2CountdownText: string = ''
  event2Color: string = '#8C939F'
  event2DateText: string = ''
  event2Status: CardEventStatus = 'future'

  event3Title: string = ''
  event3CountdownText: string = ''
  event3Color: string = '#8C939F'
  event3DateText: string = ''
  event3Status: CardEventStatus = 'future'

  eventCount: number = 0
  dimension: number = 2
  renderVersion: number = 0
}

export class CardDataBuilder {
  private static readonly EMPTY_EVENT: CardEventData = new CardEventData()

  static build(events: EventItem[], dimension: number): CardDataPayload {
    const sortedEvents = [...events].sort((a: EventItem, b: EventItem) => a.sortIndex - b.sortIndex)
    const top3 = sortedEvents.slice(0, 3)

    const event1 = top3.length > 0 ? CardDataBuilder.buildEventData(top3[0]) : CardDataBuilder.emptyEvent()
    const event2 = top3.length > 1 ? CardDataBuilder.buildEventData(top3[1]) : CardDataBuilder.emptyEvent()
    const event3 = top3.length > 2 ? CardDataBuilder.buildEventData(top3[2]) : CardDataBuilder.emptyEvent()

    const payload = new CardDataPayload()
    payload.firstTitle = top3.length > 0 ? event1.title : '赶快去应用里添加吧！'

    payload.event1Title = event1.title
    payload.event1CountdownText = event1.countdownText
    payload.event1Color = event1.color
    payload.event1DateText = event1.dateText
    payload.event1Status = event1.status

    payload.event2Title = event2.title
    payload.event2CountdownText = event2.countdownText
    payload.event2Color = event2.color
    payload.event2DateText = event2.dateText
    payload.event2Status = event2.status

    payload.event3Title = event3.title
    payload.event3CountdownText = event3.countdownText
    payload.event3Color = event3.color
    payload.event3DateText = event3.dateText
    payload.event3Status = event3.status

    payload.eventCount = top3.length
    payload.dimension = dimension
    payload.renderVersion = Date.now()
    return payload
  }

  private static buildEventData(item: EventItem): CardEventData {
    const statusInfo = EventOccurrenceService.resolveStatusInfo(item)
    const eventData = new CardEventData()
    eventData.title = item.title
    eventData.countdownText = statusInfo.text
    eventData.color = item.themeColor ?? statusInfo.color
    eventData.dateText = EventOccurrenceService.formatEventDateText(item)
    eventData.status = statusInfo.status
    return eventData
  }

  private static emptyEvent(): CardEventData {
    const eventData = new CardEventData()
    eventData.title = CardDataBuilder.EMPTY_EVENT.title
    eventData.countdownText = CardDataBuilder.EMPTY_EVENT.countdownText
    eventData.color = CardDataBuilder.EMPTY_EVENT.color
    eventData.dateText = CardDataBuilder.EMPTY_EVENT.dateText
    eventData.status = CardDataBuilder.EMPTY_EVENT.status
    return eventData
  }
}
