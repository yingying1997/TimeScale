import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { EventItem } from '../model/EventItem'
import { CardRefreshService } from '../services/CardRefreshService'
import { AppTheme } from '../theme/AppTheme'
import { EventFormDisplayHelper } from '../helpers/EventFormDisplayHelper'
import { AppLogger } from '../utils/AppLogger'
import { LunarDateService } from '../services/LunarDateService'
import {
  EventFormMapper,
  EventFormStateData,
  BuildEventRecordParams
} from '../helpers/EventFormMapper'
import { EventSaveService, EventSaveRequest, ReminderSyncState } from '../services/EventSaveService'

type RepeatType = 'none' | 'yearly' | 'monthly'

enum ReminderType {
  ON_DAY = 'on_day',
  ONE_DAY_BEFORE = 'one_day_before',
  NONE = 'none'
}

interface RouteParams {
  event?: string
}

interface DialogButtonOption {
  text: string
  color: string
}

interface DialogText {
  title: string
  message: string
}

interface RgbColor {
  red: number
  green: number
  blue: number
}

@Entry
@Component
struct EventFormPage {
  @State selectedColor: string = AppTheme.COLOR_PRIMARY
  @State title: string = ''
  @State note: string = ''
  @State selectedDate: Date = new Date()
  @State isLunarDate: boolean = false
  @State reminderType: ReminderType = ReminderType.NONE
  @State reminderHour: number = 12
  @State reminderMinute: number = 0
  @State reminderDisplayText: string = '不提醒'
  @State eventDateDisplayText: string = ''
  @State repeatDisplayText: string = '不重复'
  @State repeatType: RepeatType = 'none'
  @State isEditing: boolean = false
  @State eventId: number = 0
  @State showColorPicker: boolean = false
  @State isSaving: boolean = false

  private currentSortIndex: number = 0
  private currentCreateTime: number = 0
  private currentCalendarEventId?: number = undefined
  private currentAgentReminderId?: number = undefined
  private hasInitialized: boolean = false
  private saveInProgress: boolean = false

  private readonly pagePadding: number = AppTheme.PAGE_PADDING
  private readonly sectionGap: number = 18
  private readonly cardRadius: number = AppTheme.CARD_RADIUS
  private readonly inputRadius: number = 18
  private readonly fieldHeight: number = 56
  private readonly primaryColor: string = AppTheme.COLOR_PRIMARY
  private readonly primaryDark: string = AppTheme.COLOR_PRIMARY_DARK
  private readonly primaryLight: string = AppTheme.COLOR_PRIMARY_LIGHT
  private readonly textPrimary: string = AppTheme.COLOR_TEXT_PRIMARY
  private readonly textSecondary: string = AppTheme.COLOR_TEXT_SECONDARY
  private readonly textTertiary: string = AppTheme.COLOR_TEXT_TERTIARY
  private readonly surface: string = AppTheme.COLOR_SURFACE
  private readonly surfaceSoft: string = AppTheme.COLOR_SURFACE_SOFT
  private readonly shadowColor: string = AppTheme.SHADOW_COLOR
  private readonly paletteHues: number[] = [225, 255, 285, 315, 345, 15, 40, 55, 85, 135, 175, 200]
  private readonly paletteLevels: number = 8
  private readonly paletteSaturation: number = 78
  private readonly paletteLightStart: number = 82
  private readonly paletteLightEnd: number = 28

  private getDataContext(): Context {
    return this.getUIContext().getHostContext() as Context
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().openToast({ message: message }).catch((error: Error) => {
      AppLogger.error('EventFormPage', `Failed to show toast: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  private showDialog(options: promptAction.ShowDialogOptions): Promise<promptAction.ShowDialogSuccessResponse> {
    return this.getUIContext().getPromptAction().showDialog(options)
  }

  private pushListPage(): void {
    this.getUIContext().getRouter().replaceUrl({
      url: 'pages/EventListPage',
      params: { t: Date.now().toString() }
    }).catch((error: Error) => {
      AppLogger.error('EventFormPage', `Failed to navigate to list: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  aboutToAppear() {
    if (this.hasInitialized) {
      return
    }
    this.hasInitialized = true
    const params = this.getUIContext().getRouter().getParams() as RouteParams
    if (!params?.event) {
      this.resetForm()
      return
    }

    const event = JSON.parse(params.event) as EventItem
    this.applyFormState(EventFormMapper.fromEvent(event, this.primaryColor))
    this.syncDisplayTexts()
  }

  private applyFormState(state: EventFormStateData): void {
    this.isEditing = state.isEditing
    this.eventId = state.eventId
    this.currentSortIndex = state.currentSortIndex
    this.currentCreateTime = state.currentCreateTime
    this.currentCalendarEventId = state.currentCalendarEventId
    this.currentAgentReminderId = state.currentAgentReminderId
    this.selectedColor = state.selectedColor
    this.isLunarDate = state.isLunarDate
    this.title = state.title
    this.note = state.note
    this.selectedDate = state.selectedDate
    this.repeatType = state.repeatType
    this.reminderType = state.reminderType as ReminderType
    this.reminderHour = state.reminderHour
    this.reminderMinute = state.reminderMinute
  }

  private resetForm(): void {
    this.applyFormState(EventFormMapper.createEmpty(this.primaryColor))
    this.syncDisplayTexts()
  }

  private syncDisplayTexts(): void {
    this.syncEventDateDisplayText()
    this.syncRepeatDisplayText()
    this.syncReminderDisplayText()
  }

  private async reloadCards(): Promise<void> {
    try {
      const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await CardRefreshService.refreshAll(abilityContext)
    } catch (error) {
      AppLogger.error('EventFormPage', `Failed to reload cards: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  private buildEventItem(id: number, calendarEventId?: number): EventItem {
    const params = new BuildEventRecordParams()
    params.id = id
    params.title = this.title
    params.selectedDate = this.selectedDate
    params.sortIndex = this.isEditing ? this.currentSortIndex : 0
    params.selectedColor = this.selectedColor
    params.isLunarDate = this.isLunarDate
    params.note = this.note
    params.reminderType = this.reminderType
    params.reminderHour = this.reminderHour
    params.reminderMinute = this.reminderMinute
    params.createTime = this.isEditing ? this.currentCreateTime : Date.now()
    params.repeatType = this.repeatType
    params.calendarEventId = calendarEventId
    params.agentReminderId = this.currentAgentReminderId
    return EventFormMapper.buildEventRecord(params)
  }

  async saveEvent() {
    if (this.saveInProgress) {
      return
    }

    const trimmedTitle = this.title.trim()
    if (!trimmedTitle) {
      this.showToast('请输入事件标题')
      return
    }

    this.saveInProgress = true
    this.isSaving = true
    const draftEvent = this.buildEventItem(this.isEditing ? this.eventId : Date.now(), this.currentCalendarEventId)

    try {
      const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      const request = new EventSaveRequest()
      request.isEditing = this.isEditing
      request.eventId = this.eventId
      request.draftEvent = draftEvent
      const reminderState = await EventSaveService.saveEvent(this.getDataContext(), abilityContext, request)

      await this.reloadCards()
      this.showToast(this.buildSaveToastMessage(reminderState))
      await this.showReminderIssueDialogIfNeeded(reminderState)

      this.navigateBackToList()
    } catch (error) {
      AppLogger.error('EventFormPage', `Failed to save event: ${error instanceof Error ? error.message : `${error}`}`)
      this.showToast('保存失败')
      this.saveInProgress = false
      this.isSaving = false
    }
  }

  private selectReminder(): void {
    const buttons: DialogButtonOption[] = [
      { text: '不提醒', color: AppTheme.COLOR_TEXT_MUTED },
      { text: '提前一天', color: this.primaryColor },
      { text: '当天', color: this.primaryColor }
    ]
    this.showDialog({ title: '提醒方式', buttons: buttons }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 0) {
        this.applyReminderSelection(ReminderType.NONE)
        return
      }
      if (res.index === 1) {
        this.applyReminderSelection(ReminderType.ONE_DAY_BEFORE, true)
        return
      }
      if (res.index === 2) {
        this.applyReminderSelection(ReminderType.ON_DAY, true)
      }
    })
  }

  private buildSaveToastMessage(reminderState: ReminderSyncState): string {
    const baseText = this.isEditing ? '更新成功' : '保存成功'
    if (this.reminderType === ReminderType.NONE || reminderState.reason === 'disabled') {
      return baseText
    }
    if (reminderState.calendarSuccessCount > 0 || reminderState.calendarScheduled) {
      if (this.repeatType === 'monthly' || this.repeatType === 'yearly') {
        return `${baseText}，已创建未来提醒`
      }
      return `${baseText}，提醒已设置`
    }
    if (reminderState.reason === 'permission_denied') {
      return `${baseText}，但日历权限未开启`
    }
    if (reminderState.reason === 'past') {
      return `${baseText}，但提醒时间已过`
    }
    if (reminderState.failedCount > 0 || reminderState.partialCount > 0) {
      return `${baseText}，但部分提醒创建失败`
    }
    if (reminderState.scheduled) {
      if (this.repeatType === 'monthly' || this.repeatType === 'yearly') {
        return `${baseText}，已创建未来提醒`
      }
      return `${baseText}，提醒已设置`
    }
    return `${baseText}，但部分提醒创建失败`
  }

  private async showReminderIssueDialogIfNeeded(reminderState: ReminderSyncState): Promise<void> {
    const dialog = this.buildReminderIssueDialog(reminderState)
    if (!dialog) {
      return
    }
    await this.showDialog({
      title: dialog.title,
      message: dialog.message,
      buttons: [
        { text: '知道了', color: this.primaryColor }
      ]
    })
  }

  private buildReminderIssueDialog(reminderState: ReminderSyncState): DialogText | undefined {
    if (this.reminderType === ReminderType.NONE || reminderState.reason === 'disabled') {
      return undefined
    }
    if (reminderState.scheduled && reminderState.partialCount <= 0 && reminderState.failedCount <= 0) {
      return undefined
    }
    if (reminderState.calendarSuccessCount > 0 || reminderState.calendarScheduled) {
      return undefined
    }
    if (reminderState.reason === 'permission_denied') {
      return {
        title: '日历权限未开启',
        message: '事件已保存，但未能写入系统日历，因此无法创建日历提醒。你可以稍后在系统设置中开启日历权限。'
      }
    }
    if (reminderState.reason === 'past') {
      return {
        title: '提醒时间已过',
        message: '事件已保存，但当前设置的提醒时间已经过去，因此没有创建日历提醒。'
      }
    }
    return {
      title: '日历提醒创建失败',
      message: '事件已保存，但日历提醒没有创建成功。你可以稍后重新保存，或检查日历权限后再试。'
    }
  }

  private navigateBackToList(): void {
    this.getUIContext().getRouter().back()
    setTimeout(() => {
      this.pushListPage()
    }, 50)
  }

  private applyReminderSelection(reminderType: ReminderType, showTimePicker: boolean = false): void {
    this.reminderType = reminderType
    this.syncReminderDisplayText()
    if (showTimePicker) {
      this.showTimePicker()
    }
  }

  private showTimePicker(): void {
    const baseDate = new Date(this.selectedDate.getTime())
    if (this.reminderType === ReminderType.ONE_DAY_BEFORE) {
      baseDate.setDate(baseDate.getDate() - 1)
    }
    baseDate.setHours(this.reminderHour)
    baseDate.setMinutes(this.reminderMinute)

    this.getUIContext().showTimePickerDialog({
      selected: baseDate,
      onAccept: (value: TimePickerResult) => {
        if (value.hour !== undefined && value.minute !== undefined) {
          const nextHour = Number(value.hour)
          const nextMinute = Number(value.minute)
          if (!Number.isNaN(nextHour) && !Number.isNaN(nextMinute)) {
            this.reminderHour = nextHour
            this.reminderMinute = nextMinute
            this.syncReminderDisplayText()
          }
        }
      }
    })
  }

  private selectRepeat(): void {
    const buttons: DialogButtonOption[] = [
      { text: '不重复', color: AppTheme.COLOR_TEXT_MUTED },
      { text: '每年', color: this.primaryColor },
      { text: '每月', color: this.primaryColor }
    ]
    this.showDialog({ title: '重复方式', buttons: buttons }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 0) {
        this.repeatType = 'none'
      }
      if (res.index === 1) {
        this.repeatType = 'yearly'
      }
      if (res.index === 2) {
        this.repeatType = 'monthly'
      }
      this.syncRepeatDisplayText()
    })
  }

  private chooseDateModeAndShowPicker(): void {
    const buttons: DialogButtonOption[] = [
      { text: '公历日期', color: this.primaryColor },
      { text: '农历日期', color: this.primaryColor }
    ]
    this.showDialog({ title: '选择日期类型', buttons: buttons }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 0) {
        this.showEventDatePicker(false)
        return
      }
      if (res.index === 1) {
        this.showEventDatePicker(true)
      }
    })
  }

  private showEventDatePicker(nextIsLunarDate: boolean): void {
    this.getUIContext().showDatePickerDialog({
      selected: this.selectedDate,
      lunar: nextIsLunarDate,
      lunarSwitch: false,
      onDateAccept: (value: Date) => {
        this.isLunarDate = nextIsLunarDate
        this.selectedDate = value
        this.syncEventDateDisplayText()
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.PageHeader()

        Scroll() {
          Column({ space: this.sectionGap }) {
            this.BasicSection()
            this.ScheduleSection()
            this.SubmitSection()
          }
          .width('100%')
          .padding({ left: this.pagePadding, right: this.pagePadding, bottom: 32 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.showColorPicker) {
        this.ColorPickerOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [[AppTheme.COLOR_BG_TOP, 0], [this.surfaceSoft, 0.42], [AppTheme.COLOR_BG_BOTTOM, 1]] })
  }

  @Builder
  private PageHeader() {
    Column({ space: 8 }) {
      Stack() {
        Row() {
          Button() {
            Image($r('app.media.back'))
              .width(16)
              .height(16)
              .fillColor(this.primaryDark)
          }
            .type(ButtonType.Normal)
            .width(28)
            .height(28)
            .backgroundColor(Color.Transparent)
            .border({ width: 0 })
            .onClick(() => {
              this.getUIContext().getRouter().back()
            })

          Blank()
        }
        .width('100%')

        Text(this.isEditing ? '编辑事件' : '新建事件')
          .fontSize(AppTheme.FONT_PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textPrimary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 50, left: this.pagePadding, right: this.pagePadding, bottom: 16 })
  }

  @Builder
  private BasicSection() {
    Column({ space: 12 }) {
      this.SectionTitle('基础信息')

      Column({ space: 12 }) {
        TextInput({ text: this.title, placeholder: '请输入事件名称' })
          .onChange((value: string) => this.title = value)
          .height(this.fieldHeight)
          .width('100%')
          .backgroundColor(this.surfaceSoft)
          .fontSize(AppTheme.FONT_BODY)
          .fontColor(this.textPrimary)
          .placeholderColor(AppTheme.COLOR_PLACEHOLDER)
          .borderRadius(this.inputRadius)
          .padding({ left: 16, right: 16 })

        TextArea({ text: this.note, placeholder: '请输入备注（可选）' })
          .onChange((value: string) => this.note = value)
          .height(132)
          .width('100%')
          .backgroundColor(this.surfaceSoft)
          .fontSize(AppTheme.FONT_BODY)
          .fontColor(this.textPrimary)
          .placeholderColor(AppTheme.COLOR_PLACEHOLDER)
          .borderRadius(this.inputRadius)
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        this.ColorActionRow()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 20 })
      .backgroundColor(this.surface)
      .borderRadius(this.cardRadius)
      .border({ width: 1, color: AppTheme.COLOR_BORDER })
      .shadow({ radius: 16, color: this.shadowColor, offsetX: 0, offsetY: 8 })
    }
    .width('100%')
  }

  @Builder
  private ScheduleSection() {
    Column({ space: 12 }) {
      this.SectionTitle('时间设置')

      Column({ space: 12 }) {
        this.EventDateActionRow()
        if (this.dateHintText().length > 0) {
          this.InlineHint(this.dateHintText())
        }
        this.ReminderActionRow()
        this.RepeatActionRow()
        if (this.repeatHintText().length > 0) {
          this.InlineHint(this.repeatHintText())
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 20 })
      .backgroundColor(this.surface)
      .borderRadius(this.cardRadius)
      .border({ width: 1, color: AppTheme.COLOR_BORDER })
      .shadow({ radius: 16, color: this.shadowColor, offsetX: 0, offsetY: 8 })
    }
    .width('100%')
  }

  @Builder
  private SubmitSection() {
    Column({ space: 14 }) {
      Button(this.isSaving ? (this.isEditing ? '更新中...' : '保存中...') : (this.isEditing ? '更新事件' : '保存事件'))
        .width('100%')
        .height(52)
        .linearGradient({ angle: 180, colors: [[this.primaryColor, 0], [this.primaryDark, 1]] })
        .fontColor(Color.White)
        .fontSize(AppTheme.FONT_CARD_TITLE)
        .fontWeight(FontWeight.Bold)
        .borderRadius(52)
        .enabled(!this.isSaving)
        .opacity(this.isSaving ? 0.72 : 1)
        .shadow({ radius: 52, color: AppTheme.PRIMARY_SHADOW_COLOR, offsetX: 0, offsetY: 10 })
        .onClick(() => this.saveEvent())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ColorPalette() {
    Column({ space: 12 }) {
      Grid() {
        ForEach(this.paletteColors(), (color: string) => {
          GridItem() {
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width('100%')
                .height('100%')
                .borderRadius(10)
                .backgroundColor(color)
                .border({
                  width: this.selectedColor === color ? 2.5 : 0.5,
                  color: this.selectedColor === color ? '#FFFFFF' : '#FFFFFF88'
                })

              if (this.selectedColor === color) {
                Text('✓')
                  .fontSize(AppTheme.FONT_BODY)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
            }
          }
          .width('100%')
          .height('100%')
          .onClick(() => {
            this.selectedColor = color
          })
        }, (color: string) => color)
      }
      .columnsTemplate(this.paletteColumnsTemplate())
      .rowsTemplate(this.paletteRowsTemplate())
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      .height(264)

    }
    .width('100%')
  }

  @Builder
  private ColorActionRow() {
    Row() {
      Text('事件颜色').fontSize(AppTheme.FONT_BODY).fontWeight(FontWeight.Medium).fontColor(this.textPrimary)
      Blank()
      Row({ space: 10 }) {
        Row()
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor(this.selectedColor)
          .border({ width: 2, color: '#FFFFFF' })
          .shadow({ radius: 10, color: `${this.selectedColor}2E`, offsetX: 0, offsetY: 4 })
        Text('更换').fontSize(AppTheme.FONT_BODY_SMALL).fontWeight(FontWeight.Medium).fontColor(this.primaryColor)
      }
    }
    .width('100%')
    .height(this.fieldHeight)
    .padding({ left: 18, right: 18 })
    .backgroundColor(this.surfaceSoft)
    .borderRadius(this.inputRadius)
    .onClick(() => {
      this.showColorPicker = true
    })
  }

  @Builder
  private ColorPickerOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor(AppTheme.COLOR_OVERLAY).onClick(() => {
        this.showColorPicker = false
      })

      Column({ space: 16 }) {
        Row() {
          Text('选择事件颜色').fontSize(AppTheme.FONT_EMPTY_TITLE).fontWeight(FontWeight.Bold).fontColor(this.textPrimary)
          Blank()
          Button('完成')
            .type(ButtonType.Capsule)
            .height(32)
            .padding({ left: 14, right: 14 })
            .fontSize(AppTheme.FONT_BODY_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryColor)
            .backgroundColor(AppTheme.COLOR_PRIMARY_LIGHT)
            .onClick(() => {
              this.showColorPicker = false
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          Row().width(20).height(20).borderRadius(10).backgroundColor(this.selectedColor).border({ width: 2, color: '#FFFFFF' }).shadow({ radius: 10, color: `${this.selectedColor}30`, offsetX: 0, offsetY: 4 })
          Column({ space: 4 }) {
            Text('事件颜色').fontSize(AppTheme.FONT_BODY).fontWeight(FontWeight.Medium).fontColor(this.textPrimary)
            Text('点按色板中的任意位置即可选择颜色').fontSize(AppTheme.FONT_CAPTION).fontColor(this.textTertiary)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        this.ColorPalette()
      }
      .width('100%')
      .padding({ top: 20, left: 20, right: 20, bottom: 28 })
      .backgroundColor(this.surface)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 20, color: AppTheme.COLOR_SHEET_SHADOW, offsetX: 0, offsetY: -6 })
    }
    .width('100%')
    .height('100%')
  }

  private paletteColors(): string[] {
    const colors: string[] = []
    for (let row = 0; row < this.paletteLevels; row++) {
      const lightness = this.paletteLevels === 1
        ? this.paletteLightStart
        : Math.round(this.paletteLightStart + row * (this.paletteLightEnd - this.paletteLightStart) / (this.paletteLevels - 1))
      this.paletteHues.forEach((hue: number) => {
        colors.push(this.hslToHex(hue, this.paletteSaturation, lightness))
      })
    }
    return colors
  }

  private paletteColumnsTemplate(): string {
    return this.paletteHues.map(() => '1fr').join(' ')
  }

  private paletteRowsTemplate(): string {
    let rowsTemplate = ''
    for (let index = 0; index < this.paletteLevels; index++) {
      rowsTemplate = index === 0 ? '1fr' : `${rowsTemplate} 1fr`
    }
    return rowsTemplate
  }

  private hslToHex(hue: number, saturation: number, lightness: number): string {
    const rgb = this.hslToRgb(hue, saturation, lightness)
    return this.rgbToHex(rgb.red, rgb.green, rgb.blue)
  }

  private hslToRgb(hue: number, saturation: number, lightness: number): RgbColor {
    let red: number
    let green: number
    let blue: number
    const normalizedSaturation = saturation / 100
    const normalizedLightness = lightness / 100

    if (normalizedSaturation === 0) {
      red = Math.round(normalizedLightness * 255)
      green = Math.round(normalizedLightness * 255)
      blue = Math.round(normalizedLightness * 255)
    } else {
      const brightnessMultiplier = normalizedLightness < 0.5
        ? normalizedLightness * (1 + normalizedSaturation)
        : normalizedLightness + normalizedSaturation - normalizedLightness * normalizedSaturation
      const baseValue = 2 * normalizedLightness - brightnessMultiplier

      red = Math.round(this.convertHueToRgb(baseValue, brightnessMultiplier, hue / 360 + 1 / 3) * 255)
      green = Math.round(this.convertHueToRgb(baseValue, brightnessMultiplier, hue / 360) * 255)
      blue = Math.round(this.convertHueToRgb(baseValue, brightnessMultiplier, hue / 360 - 1 / 3) * 255)
    }

    const rgb: RgbColor = {
      red: red,
      green: green,
      blue: blue
    }
    return rgb
  }

  private convertHueToRgb(baseValue: number, brightnessMultiplier: number, hueFraction: number): number {
    let normalizedHue = hueFraction
    if (normalizedHue < 0) {
      normalizedHue += 1
    }
    if (normalizedHue > 1) {
      normalizedHue -= 1
    }
    if (normalizedHue < 1 / 6) {
      return baseValue + (brightnessMultiplier - baseValue) * 6 * normalizedHue
    }
    if (normalizedHue < 1 / 2) {
      return brightnessMultiplier
    }
    if (normalizedHue < 2 / 3) {
      return baseValue + (brightnessMultiplier - baseValue) * (2 / 3 - normalizedHue) * 6
    }
    return baseValue
  }

  private rgbToHex(red: number, green: number, blue: number): string {
    return `#${((1 << 24) + (red << 16) + (green << 8) + blue).toString(16).slice(1).toUpperCase()}`
  }

  @Builder
  private SectionTitle(title: string) {
    Text(title)
      .fontSize(AppTheme.FONT_HINT)
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.8)
      .fontColor(this.textTertiary)
      .width('100%')
  }

  @Builder
  private InlineHint(text: string) {
    Text(text)
      .fontSize(AppTheme.FONT_HINT)
      .lineHeight(17)
      .fontColor(this.textTertiary)
      .width('100%')
      .padding({ left: 6, right: 6, top: -2 })
  }

  @Builder
  private EventDateActionRow() {
    Row() {
      Text('事件日期')
        .fontSize(AppTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)

      Blank()

      Text(this.eventDateDisplayText)
        .fontSize(AppTheme.FONT_BODY)
        .fontColor(this.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
    .height(this.fieldHeight)
    .padding({ left: 18, right: 18 })
    .backgroundColor(this.surfaceSoft)
    .borderRadius(this.inputRadius)
    .onClick(() => this.chooseDateModeAndShowPicker())
  }

  @Builder
  private RepeatActionRow() {
    Row() {
      Text('重复方式')
        .fontSize(AppTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)

      Blank()

      Text(this.repeatDisplayText)
        .fontSize(AppTheme.FONT_BODY)
        .fontColor(this.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(this.fieldHeight)
    .padding({ left: 18, right: 18 })
    .backgroundColor(this.surfaceSoft)
    .borderRadius(this.inputRadius)
    .onClick(() => this.selectRepeat())
  }

  @Builder
  private ReminderActionRow() {
    Row() {
      Text('提醒方式')
        .fontSize(AppTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)

      Blank()

      Text(this.reminderDisplayText)
        .fontSize(AppTheme.FONT_BODY)
        .fontColor(this.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(this.fieldHeight)
    .padding({ left: 18, right: 18 })
    .backgroundColor(this.surfaceSoft)
    .borderRadius(this.inputRadius)
    .onClick(() => this.selectReminder())
  }

  private syncEventDateDisplayText(): void {
    this.eventDateDisplayText = EventFormDisplayHelper.buildEventDateDisplayText(this.selectedDate, this.isLunarDate)
  }

  private syncRepeatDisplayText(): void {
    this.repeatDisplayText = EventFormDisplayHelper.buildRepeatDisplayText(this.repeatType)
  }

  private syncReminderDisplayText(): void {
    this.reminderDisplayText = EventFormDisplayHelper.buildReminderDisplayText(
      this.reminderType,
      this.reminderHour,
      this.reminderMinute
    )
  }

  private dateHintText(): string {
    if (!this.isLunarDate) {
      return ''
    }
    if (this.repeatType === 'yearly') {
      if (this.isSelectedLunarLeapMonth()) {
        return '按同一农历闰月月日重复；无对应闰月年份按平月提醒。'
      }
      return ''
    }
    return ''
  }

  private repeatHintText(): string {
    const selectedDay = this.selectedDate.getDate()
    const selectedMonth = this.selectedDate.getMonth() + 1
    if (this.repeatType === 'none') {
      return ''
    }
    if (this.isLunarDate) {
      if (this.repeatType === 'monthly') {
        return '开启每月重复后，会按当前农历日自动计算后续事件。'
      }
      return '开启每年重复后，会按当前农历月日自动计算后续事件。'
    }
    if (!this.isLunarDate && this.repeatType === 'monthly' && selectedDay >= 29) {
      return `开启每月重复后，会按每月 ${selectedDay} 号计算；无该日期时按当月最后一天。`
    }
    if (!this.isLunarDate && this.repeatType === 'yearly' && selectedMonth === 2 && selectedDay === 29) {
      return '开启每年重复后，会按 2 月 29 日计算；非闰年按 2 月 28 日。'
    }
    if (this.repeatType === 'monthly') {
      return `开启每月重复后，会按每月 ${selectedDay} 号自动计算后续事件。`
    }
    if (this.repeatType === 'yearly') {
      return `开启每年重复后，会按每年 ${selectedMonth} 月 ${selectedDay} 日自动计算后续事件。`
    }
    return ''
  }

  private isSelectedLunarLeapMonth(): boolean {
    if (!this.isLunarDate) {
      return false
    }
    return LunarDateService.getLunarDateInfo(this.selectedDate).isLeapMonth
  }

}







