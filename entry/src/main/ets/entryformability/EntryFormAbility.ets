import { FormExtensionAbility, formInfo, formBindingData, formProvider } from '@kit.FormKit'
import type { Want } from '@kit.AbilityKit'
import { CardManager } from '../services/CardManager'
import { AppLogger } from '../utils/AppLogger'

const TAG: string = 'EntryFormAbility'

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string
    if (!formId) {
      AppLogger.error(TAG, 'onAddForm failed: formId is undefined')
      return formBindingData.createFormBindingData({})
    }

    const dimension = this.resolveDimensionFromWant(want)
    CardManager.getInstance().registerForm(formId)
    CardManager.getInstance().setFormDimension(formId, dimension)

    Promise.resolve().then(() => {
      this.updateCard(formId)
    })

    return formBindingData.createFormBindingData({ dimension: dimension })
  }

  onUpdateForm(formId: string, want?: Want): void {
    Promise.resolve().then(() => {
      this.updateCard(formId, want)
    }).catch((err: Error) => {
      AppLogger.error(TAG, `error in onUpdateForm promise chain: ${err.message}`)
    })
  }

  private async updateCard(formId: string, _want?: Want): Promise<void> {
    let dimension = 2
    try {
      const info = await formProvider.getPublishedRunningFormInfoById(formId)
      dimension = this.resolveDimensionFromPublishedInfo(info.dimension)
    } catch (error) {
      AppLogger.error(TAG, `get form info failed: ${error instanceof Error ? error.message : `${error}`}`)
    }

    CardManager.getInstance().registerForm(formId)
    CardManager.getInstance().setFormDimension(formId, dimension)

    try {
      await CardManager.getInstance().updateForm(formId, this.context)
    } catch (error) {
      AppLogger.error(TAG, `updateCard error: ${error instanceof Error ? error.message : `${error}`}`)
      if (error instanceof Error) {
        AppLogger.error(TAG, error.message)
      }
    }
  }

  onRemoveForm(formId: string): void {
    CardManager.getInstance().unregisterForm(formId)
    CardManager.getInstance().clearFormDimension(formId)
  }

  onFormEvent(formId: string, message: string): void {
    AppLogger.info(TAG, `onFormEvent received. formId=${formId}, message=${message}`)
  }

  onAcquireFormState(want: Want): number {
    return 1
  }

  private resolveDimensionFromWant(want: Want): number {
    const dimValue = want.parameters?.[formInfo.FormParam.DIMENSION_KEY] as string | number | undefined
    return this.resolveDimensionFromPublishedInfo(dimValue)
  }

  private resolveDimensionFromPublishedInfo(dimensionValue: string | number | undefined): number {
    if (dimensionValue === 3 || dimensionValue === 4 || dimensionValue === '3' || dimensionValue === '4') {
      return 4
    }
    return 2
  }
}
