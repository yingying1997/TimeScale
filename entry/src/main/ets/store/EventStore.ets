import common from '@ohos.app.ability.common'
import { EventItem } from '../model/EventItem'
import { EventRepository } from '../repository/EventRepository'
import { ReminderScheduleService } from '../services/ReminderScheduleService'
import { AppLogger } from '../utils/AppLogger'

type ReminderType = 'on_day' | 'one_day_before' | 'none'

@Observed
export class EventStore {
  eventList: EventItem[] = []

  async load(context: common.Context) {
    try {
      this.eventList = await EventRepository.getAllEvents(context)
    } catch (error) {
      AppLogger.error('EventStore', `Failed to load events: ${error instanceof Error ? error.message : `${error}`}`)
      this.eventList = []
    }
  }

  async add(
    context: common.Context,
    title: string,
    targetTime: number,
    themeColor: string = '#2563EB',
    note?: string,
    reminderType: ReminderType = 'on_day',
    hour: number = 12,
    minute: number = 0,
    repeatType: 'none' | 'monthly' | 'yearly' = 'none',
  ) {
    const newEvent: EventItem = {
      id: Date.now(),
      title,
      targetDate: targetTime,
      sortIndex: this.eventList.length,
      themeColor,
      note,
      reminderType,
      reminderHour: reminderType === 'none' ? undefined : hour,
      reminderMinute: reminderType === 'none' ? undefined : minute,
      createTime: Date.now(),
      repeatType
    }

    try {
      await EventRepository.addEvent(context, newEvent)
      await this.load(context)
    } catch (error) {
      AppLogger.error('EventStore', `Failed to add event: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  async delete(context: common.Context, event: EventItem) {
    try {
      await ReminderScheduleService.cancelEventSchedule(context, context, event)
      await EventRepository.deleteEvent(context, event.id)
      await this.load(context)
    } catch (error) {
      AppLogger.error('EventStore', `Failed to delete event: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  async update(context: common.Context, event: EventItem) {
    try {
      await EventRepository.updateEvent(context, event)
      await this.load(context)
    } catch (error) {
      AppLogger.error('EventStore', `Failed to update event: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  async moveItem(context: common.Context, from: number, to: number) {
    try {
      await EventRepository.moveItem(context, from, to)
      await this.load(context)
    } catch (error) {
      AppLogger.error('EventStore', `Failed to move event: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }
}

export const eventStore = new EventStore()
