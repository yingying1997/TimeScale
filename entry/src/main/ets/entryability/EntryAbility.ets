import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { NotificationNavigationState } from '../services/NotificationNavigationState'
import { ReminderScheduleService } from '../services/ReminderScheduleService'

const DOMAIN = 0x0000
const TAG = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err))
    }

    this.handleNotificationWant(want)
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate')
  }

  onNewWant(want: Want): void {
    this.handleNotificationWant(want)
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onNewWant')
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate')

    windowStage.loadContent('pages/EventListPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err))
        return
      }
      this.configureSystemBars(windowStage)
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.')
    })
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    ReminderScheduleService.ensureAllSchedules(this.context, this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'Failed to ensure reminder schedules. Cause: %{public}s', JSON.stringify(err))
    })
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground')
  }

  private handleNotificationWant(want: Want): void {
    const eventIdParam = want.parameters?.['eventId']
    if (typeof eventIdParam === 'number') {
      NotificationNavigationState.setPendingEventId(eventIdParam)
      return
    }

    if (typeof eventIdParam === 'string') {
      const eventId = Number(eventIdParam)
      if (!Number.isNaN(eventId)) {
        NotificationNavigationState.setPendingEventId(eventId)
      }
    }
  }

  private configureSystemBars(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        return mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          isStatusBarLightIcon: false,
          isNavigationBarLightIcon: false
        })
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Failed to configure system bars. Cause: %{public}s', JSON.stringify(err))
      })
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Failed to get main window. Cause: %{public}s', JSON.stringify(err))
    })
  }
}
