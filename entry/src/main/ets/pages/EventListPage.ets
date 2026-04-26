import { promptAction, curves } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { EventItem } from '../model/EventItem'
import { EventStore, eventStore } from '../store/EventStore'
import { EventRepository } from '../repository/EventRepository'
import { CardRefreshService } from '../services/CardRefreshService'
import { NotificationNavigationState } from '../services/NotificationNavigationState'
import { AppTheme } from '../theme/AppTheme'
import { EventListViewHelper } from '../helpers/EventListViewHelper'
import { EventSortService } from '../services/EventSortService'
import { AppLogger } from '../utils/AppLogger'
import { PrivacyConsentService } from '../services/PrivacyConsentService'

interface GestureEventPosition {
  globalY?: number
  windowY?: number
  screenY?: number
  y?: number
  position?: GesturePosition
}

interface GesturePosition {
  y?: number
}

interface EventFormRouteParams {
  event: string
}

@Entry
@Component
struct EventListPage {
  @State eventList: EventItem[] = []
  @State filteredList: EventItem[] = []
  @State searchKeyword: string = ''
  @State activeSlideId: number | null = null
  @State draggingItemId: number | null = null
  @State dragStartIndex: number = -1
  @State offsetY: number = 0
  @State scaleItemId: number | null = null
  @State neighborItemId: number | null = null
  @State neighborScale: number = 1
  @State moveControls: boolean = true
  @State slideOffsets: Record<number, number> = {}
  @State gestureStartOffsets: Record<number, number> = {}

  private readonly store: EventStore = eventStore
  private readonly listScroller: ListScroller = new ListScroller()
  private privacyDialogVisible: boolean = false
  private dragRefOffset: number = 0
  private autoScrollTimer: number = -1
  private autoScrollDirection: number = 0
  private listAreaTop: number = 0
  private listAreaBottom: number = 0
  private readonly autoScrollEdge: number = 64
  private readonly autoScrollInterval: number = 80

  private readonly pagePadding: number = AppTheme.PAGE_PADDING
  private readonly headerTop: number = 16
  private readonly sectionGap: number = 18
  private readonly cardHeight: number = 146
  private readonly cardRadius: number = AppTheme.CARD_RADIUS
  private readonly listItemSpace: number = 14
  private readonly listSideInset: number = 12
  private readonly listTopInset: number = 8
  private readonly dragSwapThreshold: number = 64
  private readonly deleteWidth: number = 100
  private readonly fabSize: number = 64

  private readonly colorBgTop: string = AppTheme.COLOR_BG_TOP
  private readonly colorBgBottom: string = AppTheme.COLOR_BG_BOTTOM
  private readonly colorSurface: string = AppTheme.COLOR_SURFACE
  private readonly colorSurfaceSoft: string = AppTheme.COLOR_SURFACE_SOFT
  private readonly colorPrimary: string = AppTheme.COLOR_PRIMARY
  private readonly colorPrimaryDark: string = AppTheme.COLOR_PRIMARY_DARK
  private readonly colorPrimaryLight: string = AppTheme.COLOR_PRIMARY_LIGHT
  private readonly colorTextPrimary: string = AppTheme.COLOR_TEXT_PRIMARY
  private readonly colorTextSecondary: string = AppTheme.COLOR_TEXT_SECONDARY
  private readonly colorTextTertiary: string = AppTheme.COLOR_TEXT_TERTIARY
  private readonly colorBorder: string = AppTheme.COLOR_BORDER
  private readonly colorDanger: string = AppTheme.COLOR_DANGER
  private readonly shadowColor: string = AppTheme.SHADOW_COLOR
  private readonly defaultThemeColor: string = AppTheme.COLOR_PRIMARY

  async aboutToAppear() {
    await this.refreshPageState()
  }

  onPageShow() {
    this.refreshPageState().catch((error: Error) => {
      AppLogger.error('EventListPage', `Failed to refresh page state: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  private getDataContext(): Context {
    return this.getUIContext().getHostContext() as Context
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().openToast({ message: message }).catch((error: Error) => {
      AppLogger.error('EventListPage', `Failed to show toast: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  private async showDialog(options: promptAction.ShowDialogOptions): Promise<promptAction.ShowDialogSuccessResponse> {
    try {
      return await this.getUIContext().getPromptAction().showDialog(options)
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to show dialog: ${error instanceof Error ? error.message : `${error}`}`)
      throw new Error(`${error}`)
    }
  }

  private pushUrl(url: string, params?: EventFormRouteParams): void {
    if (params) {
      this.getUIContext().getRouter().pushUrl({ url: url, params: params }).catch((error: Error) => {
        AppLogger.error('EventListPage', `Failed to navigate to ${url}: ${error instanceof Error ? error.message : `${error}`}`)
      })
      return
    }
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error) => {
      AppLogger.error('EventListPage', `Failed to navigate to ${url}: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  private async ensurePrivacyConsent(): Promise<boolean> {
    if (this.privacyDialogVisible) {
      return false
    }

    const hasAgreed = await PrivacyConsentService.hasAgreed(this.getDataContext())
    if (hasAgreed) {
      return true
    }

    this.privacyDialogVisible = true
    try {
      const result = await this.showDialog({
        title: '隐私政策',
        message: '欢迎使用时光刻度。为保障您的合法权益，请先阅读并同意《隐私政策》后继续使用应用。',
        buttons: [
          { text: '查看隐私政策', color: this.colorPrimary },
          { text: '不同意', color: this.colorDanger },
          { text: '同意并继续', color: this.colorPrimary }
        ],
        isModal: true
      })

      if (result.index === 0) {
        this.pushUrl('pages/PrivacyPolicyPage')
        return false
      }

      if (result.index === 1) {
        await this.terminateCurrentAbility()
        return false
      }

      await PrivacyConsentService.markAgreed(this.getDataContext())
      this.showToast('已同意隐私政策')
      return true
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to handle privacy consent: ${error instanceof Error ? error.message : `${error}`}`)
      this.showToast('隐私政策处理失败，请稍后重试')
      return false
    } finally {
      this.privacyDialogVisible = false
    }
  }

  private async refreshPageState(): Promise<void> {
    await this.loadEvents()
    const hasConsent = await this.ensurePrivacyConsent()
    if (hasConsent) {
      this.openPendingEventIfNeeded()
    }
  }

  private async terminateCurrentAbility(): Promise<void> {
    try {
      const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await abilityContext.terminateSelf()
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to terminate ability: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  private async reloadCards(): Promise<void> {
    try {
      const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (!abilityContext) {
        return
      }
      await CardRefreshService.refreshAll(abilityContext)
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to reload cards: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  async loadEvents() {
    try {
      this.eventList = await EventRepository.getAllEvents(this.getDataContext())
      this.applyFilter()
      this.slideOffsets = {}
      await this.reloadCards()
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to load events: ${error instanceof Error ? error.message : `${error}`}`)
      this.showToast('加载数据失败')
    }
  }

  private applyFilter() {
    this.filteredList = EventListViewHelper.filterEvents(this.eventList, this.searchKeyword)
    this.slideOffsets = {}
  }

  private openPendingEventIfNeeded(): void {
    const pendingEventId = NotificationNavigationState.consumePendingEventId()
    if (pendingEventId === undefined) {
      return
    }

    const event = this.eventList.find((item: EventItem) => item.id === pendingEventId)
    if (!event) {
      return
    }

    this.pushUrl('pages/EventFormPage', { event: JSON.stringify(event) })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.PageSurface()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .linearGradient({
        angle: 180,
        colors: [[this.colorBgTop, 0], [this.colorSurfaceSoft, 0.42], [this.colorBgBottom, 1]]
      })
      .zIndex(1)

      Button() {
        Text('+')
          .fontSize(AppTheme.FONT_PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(this.fabSize)
      .height(this.fabSize)
      .linearGradient({
        angle: 180,
        colors: [[this.colorPrimary, 0], [this.colorPrimaryDark, 1]]
      })
      .borderRadius(this.fabSize / 2)
      .shadow({ radius: 22, color: AppTheme.PRIMARY_SHADOW_COLOR, offsetX: 0, offsetY: 12 })
      .margin({ right: 24, bottom: 28 })
      .zIndex(20)
      .onClick(() => {
        this.activeSlideId = null
        this.pushUrl('pages/EventFormPage')
      })
    }
  }

  @Builder
  private PageSurface() {
    Column() {
      this.HeaderSection()

      if (this.filteredList.length === 0) {
        Column() {
          this.EmptyStateSection()
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        List({ space: this.listItemSpace, scroller: this.listScroller }) {
          ForEach(this.filteredList, (item: EventItem) => {
            ListItem() {
              this.SwipeableListItem(item)
            }
            .margin({ left: this.listSideInset, right: this.listSideInset })
            .zIndex(this.draggingItemId === item.id ? 50 : 0)
            .scale({
              x: this.scaleSelect(item.id),
              y: this.scaleSelect(item.id)
            })
            .translate({
              y: this.draggingItemId === item.id ? this.offsetY : 0
            })
            .animation(this.draggingItemId === item.id ? { duration: 100, curve: Curve.Linear } : { duration: 300, curve: Curve.EaseOut })
            .clip(false)
            .draggable(this.moveControls && this.canDragSort())
          }, (item: EventItem) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: this.listSideInset, right: this.listSideInset, top: this.listTopInset, bottom: 20 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onAreaChange((oldRect, newRect) => {
          const top = this.lengthToNumber(newRect.position.y)
          const height = this.lengthToNumber(newRect.height)
          this.listAreaTop = top
          this.listAreaBottom = top + height
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private HeaderSection() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text('时光刻度')
            .fontSize(AppTheme.FONT_PAGE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorTextPrimary)
          Text('每一个重要的日子，都在这里记录。')
            .fontSize(AppTheme.FONT_BODY_SMALL)
            .lineHeight(21)
            .fontColor(this.colorTextSecondary)
            .width('88%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button() {
          Image($r('app.media.statistics'))
            .width(20)
            .height(20)
            .fillColor(this.colorPrimaryDark)
        }
          .type(ButtonType.Capsule)
          .width(42)
          .height(42)
          .backgroundColor(this.colorSurface)
          .border({ width: 1, color: this.colorBorder })
          .onClick(() => {
            this.pushUrl('pages/StatisticsPage')
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)

      if (this.eventList.length > 0) {
        this.SearchBar()
      }

      if (this.eventList.length > 0 && this.searchKeyword.trim()) {
        Row() {
          Text(`找到 ${this.filteredList.length} 条相关事件`)
            .fontSize(AppTheme.FONT_BODY_SMALL)
            .fontColor(this.colorTextTertiary)
            .opacity(0.78)
        }
        .width('100%')
        .margin({ top: -2 })
      }
    }
    .width('100%')
    .padding({ top: 50 + this.headerTop, left: this.pagePadding, right: this.pagePadding, bottom: 10 })
  }

  @Builder
  private SearchBar() {
    Row({ space: 8 }) {
      Image($r('app.media.search'))
        .width(20)
        .height(20)
        .fillColor(this.colorPrimaryDark)
        .opacity(0.72)

      Text('|')
        .fontSize(AppTheme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colorTextTertiary)
        .opacity(0.5)

      TextInput({ placeholder: '搜索标题 / 备注', text: this.searchKeyword })
        .layoutWeight(1)
        .height(48)
        .backgroundColor(Color.Transparent)
        .fontSize(AppTheme.FONT_BODY)
        .fontColor(this.colorTextPrimary)
        .placeholderColor(this.colorTextTertiary)
        .onChange((value: string) => {
          this.searchKeyword = value
          this.activeSlideId = null
          this.applyFilter()
        })

      if (this.searchKeyword.length > 0) {
        Image($r('app.media.clear'))
          .width(20)
          .height(20)
          .fillColor(this.colorTextTertiary)
          .onClick(() => {
            this.searchKeyword = ''
            this.activeSlideId = null
            this.applyFilter()
          })
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 12 })
    .backgroundColor(this.colorSurface)
    .borderRadius(18)
    .border({ width: 1, color: this.colorBorder })
  }

  @Builder
  private EmptyStateSection() {
    Column({ space: 0 }) {
      Image($r('app.media.icon_empty'))
        .width(210)
        .height('auto')
        .opacity(0.84)
        .margin({ top: 8, bottom: 16 })

      Column({ space: 10 }) {
        Text(this.searchKeyword.trim().length > 0 ? '没有匹配结果' : '这里还没有记录')
          .fontSize(AppTheme.FONT_EMPTY_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorTextPrimary)

        Text(this.searchKeyword.trim().length > 0
          ? '没有找到相关记录，试试其他关键词。'
          : '赶快添加您的第一个重要日子吧！')
          .fontSize(AppTheme.FONT_BODY_SMALL)
          .lineHeight(22)
          .fontColor(this.colorTextSecondary)
          .textAlign(TextAlign.Center)
          .width('84%')
      }
    }
    .width('100%')
    .height('70%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16, right: 16, bottom: 42 })
  }

  private getSlideOffset(itemId: number): number {
    return this.slideOffsets[itemId] || 0
  }

  private isSlideActive(itemId: number): boolean {
    const offset = this.getSlideOffset(itemId)
    return offset < 0
  }

  private scaleSelect(itemId: number): number {
    if (this.scaleItemId === itemId) {
      return 1.05
    }
    if (this.neighborItemId === itemId) {
      return this.neighborScale
    }
    return 1
  }

  private itemMove(index: number, newIndex: number): void {
    EventSortService.reorderInPlace(this.eventList, index, newIndex)
    if (!this.searchKeyword.trim()) {
      this.filteredList = [...this.eventList]
    }
  }

  private getItemInterval(): number {
    return this.cardHeight + this.listItemSpace
  }

  private lengthToNumber(value: Length | undefined): number {
    if (value === undefined) {
      return 0
    }
    if (typeof value === 'number') {
      return value
    }
    const parsed = parseFloat(`${value}`)
    return Number.isNaN(parsed) ? 0 : parsed
  }

  private updateAutoScrollDirection(globalY: number): void {
    if (this.draggingItemId === null) {
      this.autoScrollDirection = 0
      return
    }
    if (this.listAreaBottom <= this.listAreaTop) {
      this.autoScrollDirection = 0
      return
    }
    if (globalY < this.listAreaTop + this.autoScrollEdge) {
      this.autoScrollDirection = -1
      return
    }
    if (globalY > this.listAreaBottom - this.autoScrollEdge) {
      this.autoScrollDirection = 1
      return
    }
    this.autoScrollDirection = 0
  }

  private resolveGlobalY(event: GestureEvent): number | undefined {
    const position = event as GestureEventPosition
    return position.globalY
      ?? position.windowY
      ?? position.screenY
      ?? position.y
      ?? position.position?.y
  }

  private startAutoScroll(): void {
    if (this.autoScrollTimer >= 0) {
      return
    }
    this.autoScrollTimer = setInterval(() => {
      if (this.draggingItemId === null || this.autoScrollDirection === 0) {
        return
      }
      const currentIndex = this.eventList.findIndex((event: EventItem) => event.id === this.draggingItemId)
      if (currentIndex < 0) {
        return
      }
      const targetIndex = Math.max(0, Math.min(this.eventList.length - 1, currentIndex + this.autoScrollDirection))
      if (targetIndex === currentIndex) {
        return
      }
      this.listScroller.scrollToIndex(targetIndex, true)
      this.dragRefOffset += this.autoScrollDirection * this.getItemInterval()
    }, this.autoScrollInterval)
  }

  private stopAutoScroll(): void {
    if (this.autoScrollTimer >= 0) {
      clearInterval(this.autoScrollTimer)
      this.autoScrollTimer = -1
    }
    this.autoScrollDirection = 0
  }

  @Builder
  private SwipeableListItem(item: EventItem) {
    Stack() {
      // 删除按钮层（底层）
      if (this.isSlideActive(item.id) && this.draggingItemId === null) {
        Row() {
          Blank()
          Button('删除')
            .type(ButtonType.Normal)
            .width(this.deleteWidth)
            .height('100%')
            .backgroundColor(this.colorDanger)
            .fontColor(Color.White)
            .fontSize(AppTheme.FONT_BODY)
            .fontWeight(FontWeight.Medium)
            .borderRadius({ topLeft: 0, bottomLeft: 0, topRight: this.cardRadius, bottomRight: this.cardRadius })
            .onClick(() => {
              this.slideOffsets[item.id] = 0
              this.confirmDelete(item)
            })
        }
        .width('100%')
        .height('100%')
        .borderRadius({ topLeft: 0, bottomLeft: 0, topRight: this.cardRadius, bottomRight: this.cardRadius })
      }

      // 事件卡片层（上层，可滑动）
      Stack() {
        Row() {
          this.EventCard(item)
        }
        .width('100%')
        .height(this.cardHeight)
        .backgroundColor(this.colorSurface)
        .borderRadius(this.isSlideActive(item.id)
          ? { topLeft: this.cardRadius, bottomLeft: this.cardRadius, topRight: 0, bottomRight: 0 }
          : this.cardRadius)
        .border({ width: 1, color: this.colorBorder })
        .shadow(this.draggingItemId === item.id
          ? { radius: 24, color: AppTheme.PRIMARY_DRAG_SHADOW_COLOR, offsetX: 0, offsetY: 14 }
          : { radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
        .clip(true)
        .gesture(
          GestureGroup(
            GestureMode.Parallel,
            PanGesture({
              direction: PanDirection.Horizontal
            }).onActionStart(() => {
              if (this.draggingItemId !== null) {
                return
              }
              this.gestureStartOffsets[item.id] = this.getSlideOffset(item.id)
            }).onActionUpdate((event: GestureEvent) => {
              if (this.draggingItemId !== null) {
                return
              }
              const startOffset = this.gestureStartOffsets[item.id] || 0
              const newOffset = Math.max(-this.deleteWidth, Math.min(0, startOffset + event.offsetX))
              this.slideOffsets[item.id] = newOffset
            }).onActionEnd(() => {
              if (this.draggingItemId !== null) {
                return
              }
              const currentOffset = this.getSlideOffset(item.id)
              if (currentOffset < -this.deleteWidth / 2) {
                this.slideOffsets[item.id] = -this.deleteWidth
              } else {
                this.slideOffsets[item.id] = 0
              }
            }),
            GestureGroup(
              GestureMode.Sequence,
              LongPressGesture({ repeat: true }).onAction(() => {
                if (!this.canDragSort()) {
                  if (this.searchKeyword.trim().length > 0) {
                    this.showToast('搜索状态下不可拖拽排序')
                  }
                  return
                }
                this.getUIContext().animateTo({ curve: Curve.Friction, duration: 300 }, () => {
                  this.scaleItemId = item.id
                })
              }).onActionEnd(() => {
                this.getUIContext().animateTo({ curve: Curve.Friction, duration: 300 }, () => {
                  this.scaleItemId = null
                })
              }),
              PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 0 })
                .onActionStart(() => {
                  if (!this.canDragSort()) {
                    return
                  }
                  this.activeSlideId = null
                  this.draggingItemId = item.id
                  this.dragStartIndex = this.eventList.findIndex((event: EventItem) => event.id === item.id)
                  this.offsetY = 0
                  this.dragRefOffset = 0
                  this.neighborItemId = null
                  this.neighborScale = 1
                  this.startAutoScroll()
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.draggingItemId !== item.id) {
                    return
                  }
                  const globalY = this.resolveGlobalY(event)
                  if (globalY !== undefined) {
                    this.updateAutoScrollDirection(globalY)
                  } else {
                    this.autoScrollDirection = 0
                  }
                  this.offsetY = event.offsetY - this.dragRefOffset
                  this.neighborItemId = null
                  const index = this.eventList.findIndex((event: EventItem) => event.id === item.id)
                  if (index < 0) {
                    return
                  }
                  const itemIntv = this.getItemInterval()
                  const curveValue = curves.initCurve(Curve.Sharp)
                  let value = 0
                  if (this.offsetY < 0 && index > 0) {
                    value = curveValue.interpolate(Math.min(1, -this.offsetY / itemIntv))
                    this.neighborItemId = this.eventList[index - 1].id
                    this.neighborScale = 1 - value / 20
                  } else if (this.offsetY > 0 && index < this.eventList.length - 1) {
                    value = curveValue.interpolate(Math.min(1, this.offsetY / itemIntv))
                    this.neighborItemId = this.eventList[index + 1].id
                    this.neighborScale = 1 - value / 20
                  }

                  if (this.offsetY > itemIntv / 2 && index < this.eventList.length - 1) {
                    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                      this.offsetY -= itemIntv
                      this.dragRefOffset += itemIntv
                      this.itemMove(index, index + 1)
                      this.listScroller.scrollToIndex(index + 1, true)
                    })
                  } else if (this.offsetY < -itemIntv / 2 && index > 0) {
                    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                      this.offsetY += itemIntv
                      this.dragRefOffset -= itemIntv
                      this.itemMove(index, index - 1)
                      this.listScroller.scrollToIndex(index - 1, true)
                    })
                  }
                })
                .onActionEnd(() => {
                  this.stopAutoScroll()
                  this.finishDragSort().catch((error: Error) => {
                    AppLogger.error('EventListPage', `Failed to finish drag sort: ${error.message}`)
                  })

                  this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 400, 38) }, () => {
                    this.draggingItemId = null
                    this.neighborItemId = null
                    this.offsetY = 0
                  })
                  this.getUIContext().animateTo({
                    curve: curves.interpolatingSpring(14, 1, 170, 17),
                    delay: 150
                  }, () => {
                    this.scaleItemId = null
                  })
                })
            )
          )
        )
        .onClick(() => {
          if (this.draggingItemId !== null) {
            return
          }
          if (this.isSlideActive(item.id)) {
            this.slideOffsets[item.id] = 0
            return
          }
          this.pushUrl('pages/EventFormPage', { event: JSON.stringify(item) })
        })
      }
      .width('100%')
      .height(this.cardHeight)
      .translate({
        x: this.getSlideOffset(item.id),
        y: 0
      })
      .clip(false)
    }
    .width('100%')
    .height(this.cardHeight)
  }

  @Builder
  private EventCard(item: EventItem) {
    Row({ space: 14 }) {
      Column() {
        Row({ space: 8 }) {
          this.StatusMarker(item)
          Text(item.title)
            .layoutWeight(1)
            .fontSize(AppTheme.FONT_CARD_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorTextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 10 })

        Column({ space: 4 }) {
          Text(this.primaryDateText(item))
            .fontSize(AppTheme.FONT_BODY_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.COLOR_TEXT_MUTED)
            .width('100%')

          if (this.hasSecondaryDate(item)) {
            Text(this.secondaryDateText(item))
              .fontSize(AppTheme.FONT_HINT)
              .fontColor(AppTheme.COLOR_PLACEHOLDER)
              .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: this.hasNote(item) ? 7 : 12 })

        if (this.hasNote(item)) {
          Text(item.note)
            .fontSize(AppTheme.FONT_CAPTION)
            .lineHeight(18)
            .fontColor(this.colorTextTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ bottom: 10 })
        }

        Row({ space: 6 }) {
          if (this.isLunarEvent(item)) {
            this.Tag('农历事件', AppTheme.COLOR_TAG_BG, AppTheme.COLOR_TAG_TEXT)
          }
          this.Tag(this.reminderLabel(item), AppTheme.COLOR_TAG_BG, AppTheme.COLOR_TAG_TEXT)
          this.Tag(this.repeatLabel(item), AppTheme.COLOR_TAG_BG, AppTheme.COLOR_TAG_TEXT)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      this.StatusCapsule(item)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private Tag(label: string, bgColor: string, textColor: string) {
    Text(label)
      .fontSize(AppTheme.FONT_TAG)
      .fontWeight(FontWeight.Medium)
      .fontColor(textColor)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(bgColor)
      .borderRadius(999)
  }

  @Builder
  private StatusCapsule(item: EventItem) {
    Column({ space: 5 }) {
      if (this.isToday(item)) {
        Column({ space: 5 }) {
          Text('就是')
            .fontSize(AppTheme.FONT_HINT)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colorTextTertiary)

          Text('今天')
            .fontSize(AppTheme.FONT_NUMBER_SMALL)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.eventThemeColor(item))
            .textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.End)
      } else {
        Column({ space: 5 }) {
          Text(this.statusPrefix(item))
            .fontSize(AppTheme.FONT_HINT)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colorTextTertiary)

          Row({ space: 2 }) {
            Text(this.statusNumber(item))
              .fontSize(AppTheme.FONT_NUMBER)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.eventThemeColor(item))
            Text(this.statusUnit(item))
              .fontSize(AppTheme.FONT_TAG)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colorTextTertiary)
              .margin({ top: 7 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width(68)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 4, right: 2, top: 0, bottom: 0 })
  }

  @Builder
  private StatusMarker(item: EventItem) {
    Row() {
      if (this.isToday(item)) {
        Image($r('app.media.ringDot'))
          .width(14)
          .height(14)
          .fillColor(this.eventThemeColor(item))
      } else if (EventListViewHelper.isPast(item)) {
        Image($r('app.media.ring'))
          .width(14)
          .height(14)
          .fillColor(this.eventThemeColor(item))
      } else {
        Image($r('app.media.dot'))
          .width(14)
          .height(14)
          .fillColor(this.eventThemeColor(item))
      }
    }
    .width(16)
    .height(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  private eventThemeColor(item: EventItem): string {
    return EventListViewHelper.eventThemeColor(item, this.defaultThemeColor)
  }

  private canDragSort(): boolean {
    return EventSortService.canDragSort(this.searchKeyword, this.eventList.length)
  }

  private async finishDragSort(): Promise<void> {
    if (this.draggingItemId === null) {
      return
    }

    const movedItemId = this.draggingItemId
    const newIndex = this.eventList.findIndex((event: EventItem) => event.id === movedItemId)
    const moved = this.dragStartIndex >= 0 && newIndex >= 0 && newIndex !== this.dragStartIndex
    this.dragStartIndex = -1

    if (!moved) {
      return
    }

    try {
      await EventRepository.saveSortOrder(this.getDataContext(), this.eventList)
      await this.loadEvents()
    } catch (error) {
      AppLogger.error('EventListPage', `Failed to persist drag sort order: ${error instanceof Error ? error.message : `${error}`}`)
      this.showToast('排序失败')
      await this.loadEvents()
    }
  }

  private confirmDelete(item: EventItem) {
    this.showDialog({
      title: '删除事件',
      message: `确定要删除“${item.title}”吗？此操作不可恢复。`,
      buttons: [
        { text: '取消', color: AppTheme.COLOR_TEXT_MUTED },
        { text: '删除', color: this.colorDanger }
      ]
    }).then(async (res) => {
      if (res.index !== 1) {
        return
      }

      try {
        await this.store.delete(this.getDataContext(), item)
        await this.loadEvents()
        this.showToast('删除成功')
      } catch (error) {
        AppLogger.error('EventListPage', `Failed to delete item: ${error instanceof Error ? error.message : `${error}`}`)
        this.showToast('删除失败')
        await this.loadEvents()
      }
    })
  }

  private primaryDateText(item: EventItem): string {
    return EventListViewHelper.primaryDateText(item)
  }

  private secondaryDateText(item: EventItem): string {
    return EventListViewHelper.secondaryDateText(item)
  }

  private hasSecondaryDate(item: EventItem): boolean {
    return this.secondaryDateText(item).length > 0
  }

  private isLunarEvent(item: EventItem): boolean {
    return EventListViewHelper.isLunarEvent(item)
  }

  private repeatLabel(item: EventItem): string {
    return EventListViewHelper.repeatLabel(item)
  }

  private reminderLabel(item: EventItem): string {
    return EventListViewHelper.reminderLabel(item)
  }

  private hasNote(item: EventItem): boolean {
    return item.note !== undefined && item.note.trim() !== ''
  }

  private isToday(item: EventItem): boolean {
    return EventListViewHelper.isToday(item)
  }

  private statusPrefix(item: EventItem): string {
    return EventListViewHelper.statusPrefix(item)
  }

  private statusNumber(item: EventItem): string {
    return EventListViewHelper.statusNumber(item)
  }

  private statusUnit(item: EventItem): string {
    return EventListViewHelper.statusUnit(item)
  }
}


