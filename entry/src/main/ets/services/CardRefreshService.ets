import { common } from '@kit.AbilityKit'
import { formProvider } from '@kit.FormKit'
import { CardManager } from './CardManager'

export class CardRefreshService {
  static async refreshAll(abilityContext: common.UIAbilityContext): Promise<void> {
    await CardManager.getInstance().updateAllForms(abilityContext)
    await formProvider.reloadAllForms(abilityContext)
  }
}
