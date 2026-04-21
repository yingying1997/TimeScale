import { formProvider, formBindingData } from '@kit.FormKit'
import type { Context } from '@kit.AbilityKit'
import { EventRepository } from '../repository/EventRepository'
import { CardDataBuilder } from './CardDataBuilder'
import { AppLogger } from '../utils/AppLogger'

export class CardManager {
  private static instance: CardManager | null = null
  private formIds: Set<string> = new Set()
  private formDimensions: Map<string, number> = new Map()

  private constructor() {
  }

  static getInstance(): CardManager {
    if (!CardManager.instance) {
      CardManager.instance = new CardManager()
    }
    return CardManager.instance
  }

  registerForm(formId: string): void {
    this.formIds.add(formId)
  }

  unregisterForm(formId: string): void {
    this.formIds.delete(formId)
    this.formDimensions.delete(formId)
  }

  setFormDimension(formId: string, dimension: number): void {
    this.formDimensions.set(formId, dimension)
  }

  getFormDimension(formId: string): number {
    return this.formDimensions.get(formId) ?? 2
  }

  clearFormDimension(formId: string): void {
    this.formDimensions.delete(formId)
  }

  async updateAllForms(context: Context): Promise<void> {
    const formIds = Array.from(this.formIds)
    for (let i = 0; i < formIds.length; i++) {
      await this.updateForm(formIds[i], context)
    }
  }

  async updateForm(formId: string, context: Context): Promise<void> {
    try {
      const events = await EventRepository.getAllEvents(context)
      const cardData = CardDataBuilder.build(events, this.getFormDimension(formId))
      const bindingData = formBindingData.createFormBindingData(cardData)
      await formProvider.updateForm(formId, bindingData)
    } catch (err) {
      AppLogger.error('CardManager', `failed to update form ${formId}: ${err instanceof Error ? err.message : `${err}`}`)
    }
  }
}
