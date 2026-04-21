import { common } from '@kit.AbilityKit'
import { formProvider } from '@kit.FormKit'
import { CardManager } from './CardManager'
import { AppLogger } from '../utils/AppLogger'

export class CardRefreshService {
  static async refreshAll(abilityContext: common.UIAbilityContext): Promise<void> {
    try {
      await CardManager.getInstance().updateAllForms(abilityContext)
    } catch (error) {
      AppLogger.error('CardRefreshService',
        `Failed to update form data: ${error instanceof Error ? error.message : `${error}`}`)
    }

    try {
      await formProvider.reloadAllForms(abilityContext)
    } catch (error) {
      AppLogger.error('CardRefreshService',
        `Failed to reload forms: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }
}
