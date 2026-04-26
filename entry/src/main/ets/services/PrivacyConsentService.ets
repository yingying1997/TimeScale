import preferences from '@ohos.data.preferences'
import { AppLogger } from '../utils/AppLogger'

export class PrivacyConsentService {
  private static readonly PREFERENCES_NAME: string = 'timescale_privacy'
  private static readonly AGREEMENT_KEY: string = 'privacy_policy_agreed'

  static async hasAgreed(context: Context): Promise<boolean> {
    try {
      const preferenceStore = await preferences.getPreferences(context, PrivacyConsentService.PREFERENCES_NAME)
      const value = await preferenceStore.get(PrivacyConsentService.AGREEMENT_KEY, false)
      return value === true
    } catch (error) {
      AppLogger.error(
        'PrivacyConsentService',
        `Failed to read privacy consent: ${error instanceof Error ? error.message : `${error}`}`
      )
      return false
    }
  }

  static async markAgreed(context: Context): Promise<void> {
    try {
      const preferenceStore = await preferences.getPreferences(context, PrivacyConsentService.PREFERENCES_NAME)
      await preferenceStore.put(PrivacyConsentService.AGREEMENT_KEY, true)
      await preferenceStore.flush()
    } catch (error) {
      AppLogger.error(
        'PrivacyConsentService',
        `Failed to persist privacy consent: ${error instanceof Error ? error.message : `${error}`}`
      )
      throw new Error(`${error}`)
    }
  }
}
