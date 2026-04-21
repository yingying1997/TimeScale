import { describe, afterEach, it, expect } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { EventItem } from '../main/ets/model/EventItem'
import { ReminderInstance } from '../main/ets/model/ReminderInstance'
import {
  ReminderInstanceStore,
  ReminderProvider,
  ReminderScheduleService
} from '../main/ets/services/ReminderScheduleService'
import { ReminderSyncResult } from '../main/ets/services/ReminderService'

class FakeReminderProvider implements ReminderProvider {
  cancelledCalendarIds: number[] = []
  cancelledAgentIds: number[] = []
  scheduledCount: number = 0

  async scheduleReminderAt(
    _abilityContext: common.UIAbilityContext,
    _event: EventItem,
    _reminderDate: Date
  ): Promise<ReminderSyncResult> {
    this.scheduledCount = this.scheduledCount + 1
    return {
      scheduled: true,
      calendarScheduled: true,
      calendarEventId: 9000 + this.scheduledCount
    }
  }

  async cancelReminder(
    _abilityContext: common.UIAbilityContext | Context,
    calendarEventId?: number
  ): Promise<void> {
    if (calendarEventId !== undefined) {
      this.cancelledCalendarIds.push(calendarEventId)
    }
  }

  async cancelAgentReminder(agentReminderId?: number): Promise<void> {
    if (agentReminderId !== undefined) {
      this.cancelledAgentIds.push(agentReminderId)
    }
  }
}

class FakeReminderInstanceStore implements ReminderInstanceStore {
  instances: ReminderInstance[] = []
  deletedIds: number[] = []
  addedInstances: ReminderInstance[] = []

  async getInstancesByEventId(_context: Context, eventId: number): Promise<ReminderInstance[]> {
    return this.instances.filter((instance: ReminderInstance) => instance.eventId === eventId)
  }

  async getFutureInstancesByEventId(_context: Context, eventId: number, fromTime: number = Date.now()): Promise<ReminderInstance[]> {
    return this.instances.filter((instance: ReminderInstance) => instance.eventId === eventId && instance.reminderTime > fromTime)
  }

  async addInstance(_context: Context, instance: ReminderInstance): Promise<number> {
    const nextId = 100 + this.addedInstances.length
    this.addedInstances.push(instance)
    return nextId
  }

  async deleteInstance(_context: Context, id: number): Promise<void> {
    this.deletedIds.push(id)
    this.instances = this.instances.filter((instance: ReminderInstance) => instance.id !== id)
  }
}

function makeEvent(): EventItem {
  return {
    id: 7,
    title: 'Delete Old Reminder',
    targetDate: new Date(2099, 4, 10).getTime(),
    sortIndex: 0,
    themeColor: '#2563EB',
    isLunarDate: false,
    note: '',
    reminderType: 'on_day',
    reminderHour: 9,
    reminderMinute: 0,
    createTime: new Date(2099, 0, 1).getTime(),
    repeatType: 'none',
    calendarType: 'solar',
    solarMonth: 5,
    solarDay: 10,
    calendarEventId: 301,
    agentReminderId: 401
  }
}

function makeInstance(id: number, calendarEventId?: number, agentReminderId?: number): ReminderInstance {
  return {
    id,
    eventId: 7,
    occurrenceDate: new Date(2099, 4, 10).getTime(),
    reminderTime: new Date(2099, 4, 10, 9, 0).getTime(),
    calendarEventId,
    agentReminderId,
    status: 'scheduled',
    createTime: new Date(2099, 0, 1).getTime(),
    updateTime: new Date(2099, 0, 1).getTime()
  }
}

export default function reminderScheduleTest() {
  describe('reminderScheduleTest', () => {
    afterEach(() => {
      ReminderScheduleService.setReminderProviderForTest(undefined)
      ReminderScheduleService.setReminderInstanceStoreForTest(undefined)
    })

    it('cancelEventScheduleDeletesInstanceAndLegacyReminderIds', 0, async () => {
      const provider = new FakeReminderProvider()
      const store = new FakeReminderInstanceStore()
      store.instances = [
        makeInstance(11, 101, 201),
        makeInstance(12, 102, undefined)
      ]
      ReminderScheduleService.setReminderProviderForTest(provider)
      ReminderScheduleService.setReminderInstanceStoreForTest(store)

      await ReminderScheduleService.cancelEventSchedule({} as common.UIAbilityContext, {} as Context, makeEvent())

      expect(provider.cancelledCalendarIds.length).assertEqual(3)
      expect(provider.cancelledCalendarIds[0]).assertEqual(101)
      expect(provider.cancelledCalendarIds[1]).assertEqual(102)
      expect(provider.cancelledCalendarIds[2]).assertEqual(301)
      expect(provider.cancelledAgentIds.length).assertEqual(2)
      expect(provider.cancelledAgentIds[0]).assertEqual(201)
      expect(provider.cancelledAgentIds[1]).assertEqual(401)
      expect(store.deletedIds.length).assertEqual(2)
      expect(store.deletedIds[0]).assertEqual(11)
      expect(store.deletedIds[1]).assertEqual(12)
    })

    it('rebuildEventScheduleDeletesOldInstancesBeforeCreatingNewOne', 0, async () => {
      const provider = new FakeReminderProvider()
      const store = new FakeReminderInstanceStore()
      store.instances = [
        makeInstance(21, 501, 601)
      ]
      const event = makeEvent()
      ReminderScheduleService.setReminderProviderForTest(provider)
      ReminderScheduleService.setReminderInstanceStoreForTest(store)

      const result = await ReminderScheduleService.rebuildEventSchedule(
        {} as common.UIAbilityContext,
        {} as Context,
        event
      )

      expect(provider.cancelledCalendarIds.length).assertEqual(2)
      expect(provider.cancelledCalendarIds[0]).assertEqual(501)
      expect(provider.cancelledCalendarIds[1]).assertEqual(301)
      expect(provider.cancelledAgentIds.length).assertEqual(2)
      expect(provider.cancelledAgentIds[0]).assertEqual(601)
      expect(provider.cancelledAgentIds[1]).assertEqual(401)
      expect(store.deletedIds.length).assertEqual(1)
      expect(store.deletedIds[0]).assertEqual(21)
      expect(provider.scheduledCount).assertEqual(1)
      expect(store.addedInstances.length).assertEqual(1)
      expect(store.addedInstances[0].calendarEventId).assertEqual(9001)
      expect(result.scheduled).assertEqual(true)
      expect(result.calendarSuccessCount).assertEqual(1)
      expect(event.calendarEventId).assertEqual(undefined)
      expect(event.agentReminderId).assertEqual(undefined)
    })
  })
}
