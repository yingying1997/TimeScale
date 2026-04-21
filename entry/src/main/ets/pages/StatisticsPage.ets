import { EventItem } from '../model/EventItem'
import { EventRepository } from '../repository/EventRepository'
import { AppTheme } from '../theme/AppTheme'
import { StatisticsService, CountdownBucket, RepeatBucket, CalendarBucket, StatisticsDashboard } from '../services/StatisticsService'
import { AppLogger } from '../utils/AppLogger'

@Entry
@Component
struct StatisticsPage {
  @State private dashboard: StatisticsDashboard = StatisticsService.emptyDashboard()
  @State private isLoading: boolean = true
  @State private chartProgress: number = 0

  private readonly repeatDonutSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private readonly repeatDonutContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.repeatDonutSettings)
  private readonly barSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private readonly barContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.barSettings)
  private repeatDonutReady: boolean = false
  private barReady: boolean = false
  private animationTimer: number = -1

  private readonly pagePadding: number = AppTheme.PAGE_PADDING
  private readonly cardRadius: number = AppTheme.CARD_RADIUS
  private readonly colorBgTop: string = AppTheme.COLOR_BG_TOP
  private readonly colorBgBottom: string = AppTheme.COLOR_BG_BOTTOM
  private readonly colorSurface: string = AppTheme.COLOR_SURFACE
  private readonly colorPrimary: string = AppTheme.COLOR_PRIMARY
  private readonly colorPrimaryDark: string = AppTheme.COLOR_PRIMARY_DARK
  private readonly colorTextPrimary: string = AppTheme.COLOR_TEXT_PRIMARY
  private readonly colorTextSecondary: string = AppTheme.COLOR_TEXT_SECONDARY
  private readonly colorTextTertiary: string = AppTheme.COLOR_TEXT_TERTIARY
  private readonly shadowColor: string = AppTheme.SHADOW_COLOR

  private readonly repeatDonutWidth: number = 180
  private readonly repeatDonutHeight: number = 150
  private readonly barWidth: number = 300
  private readonly barHeight: number = 220

  async aboutToAppear() {
    await this.loadEvents()
    this.startChartAnimation()
  }

  aboutToDisappear() {
    this.clearAnimationTimer()
  }

  private getDataContext(): Context {
    return this.getUIContext().getHostContext() as Context
  }

  private pushUrl(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((error: Error) => {
      AppLogger.error('StatisticsPage', `Failed to navigate to ${url}: ${error instanceof Error ? error.message : `${error}`}`)
    })
  }

  private async loadEvents(): Promise<void> {
    this.isLoading = true
    try {
      const eventList: EventItem[] = await EventRepository.getAllEvents(this.getDataContext())
      this.dashboard = StatisticsService.buildDashboard(eventList)
    } catch (error) {
      AppLogger.error('StatisticsPage', `Load events failed: ${error instanceof Error ? error.message : `${error}`}`)
      this.dashboard = StatisticsService.emptyDashboard()
    } finally {
      this.isLoading = false
      this.renderCharts()
    }
  }

  private clearAnimationTimer(): void {
    if (this.animationTimer >= 0) {
      clearInterval(this.animationTimer)
      this.animationTimer = -1
    }
  }

  private startChartAnimation(): void {
    this.clearAnimationTimer()
    this.chartProgress = 0
    this.renderCharts()

    const startAt: number = Date.now()
    const duration: number = 900
    this.animationTimer = setInterval(() => {
      const elapsed: number = Date.now() - startAt
      const raw: number = Math.min(1, elapsed / duration)
      this.chartProgress = 1 - Math.pow(1 - raw, 3)
      this.renderCharts()
      if (raw >= 1) {
        this.clearAnimationTimer()
      }
    }, 16)
  }

  private renderCharts(): void {
    this.renderRepeatDonutChart()
    this.renderBarChart()
  }

  private countdownBuckets(): CountdownBucket[] {
    return this.dashboard.countdownBuckets
  }

  private repeatBuckets(): RepeatBucket[] {
    return this.dashboard.repeatBuckets
  }

  private calendarBuckets(): CalendarBucket[] {
    return this.dashboard.calendarBuckets
  }

  private monthlyTrend(): number[] {
    return this.dashboard.monthlyTrend
  }

  private monthLabel(offset: number): string {
    return StatisticsService.monthLabel(offset)
  }

  private totalCount(): number {
    return this.dashboard.summary.totalCount
  }

  private next7DaysCount(): number {
    return this.dashboard.summary.next7DaysCount
  }

  private next30DaysCount(): number {
    return this.dashboard.summary.next30DaysCount
  }

  private reminderOnCount(): number {
    return this.dashboard.summary.reminderOnCount
  }

  private drawRoundedRect(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number
  ): void {
    const r = Math.min(radius, width / 2, height / 2)
    ctx.beginPath()
    ctx.moveTo(x + r, y)
    ctx.lineTo(x + width - r, y)
    ctx.arcTo(x + width, y, x + width, y + r, r)
    ctx.lineTo(x + width, y + height - r)
    ctx.arcTo(x + width, y + height, x + width - r, y + height, r)
    ctx.lineTo(x + r, y + height)
    ctx.arcTo(x, y + height, x, y + height - r, r)
    ctx.lineTo(x, y + r)
    ctx.arcTo(x, y, x + r, y, r)
    ctx.closePath()
  }

  private renderRepeatDonutChart(): void {
    if (!this.repeatDonutReady) {
      return
    }
    const ctx = this.repeatDonutContext
    const width = this.repeatDonutWidth
    const height = this.repeatDonutHeight
    ctx.clearRect(0, 0, width, height)

    const buckets = this.repeatBuckets()
    const total = buckets.reduce((sum: number, item: RepeatBucket) => sum + item.value, 0)
    const centerX = width / 2
    const centerY = height / 2
    const radius = 46
    const lineWidth = 18

    ctx.beginPath()
    ctx.strokeStyle = AppTheme.COLOR_CHART_TRACK_SOFT
    ctx.lineWidth = lineWidth
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
    ctx.stroke()

    if (total <= 0) {
      ctx.fillStyle = AppTheme.COLOR_TEXT_MUTED
      ctx.font = `bold ${AppTheme.FONT_BODY}px sans-serif`
      ctx.textAlign = 'center'
      ctx.fillText('赶快去应用里添加吧！', centerX, centerY + 5)
      return
    }

    let startAngle = -Math.PI / 2
    buckets.forEach((bucket: RepeatBucket) => {
      if (bucket.value <= 0) {
        return
      }
      const fullSweep = (bucket.value / total) * Math.PI * 2
      const sweep = fullSweep * this.chartProgress
      ctx.beginPath()
      ctx.strokeStyle = bucket.color
      ctx.lineWidth = lineWidth
      ctx.lineCap = 'round'
      ctx.arc(centerX, centerY, radius, startAngle, startAngle + sweep)
      ctx.stroke()
      startAngle = startAngle + fullSweep
    })

    ctx.fillStyle = AppTheme.COLOR_CHART_TEXT
    ctx.font = `bold ${AppTheme.FONT_NUMBER_SMALL}px sans-serif`
    ctx.textAlign = 'center'
    ctx.fillText(Math.round(total * this.chartProgress).toString(), centerX, centerY + 6)
  }

  private renderBarChart(): void {
    if (!this.barReady) {
      return
    }
    const ctx = this.barContext
    const width = this.barWidth
    const height = this.barHeight
    ctx.clearRect(0, 0, width, height)

    const list = this.monthlyTrend()
    const max = Math.max(1, ...list)

    const chartX = 18
    const chartY = 20
    const chartHeight = 160
    const chartWidth = width - chartX * 2
    const gap = 6
    const singleBarWidth = (chartWidth - gap * 11) / 12

    ctx.strokeStyle = AppTheme.COLOR_CHART_GRID
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(chartX, chartY + chartHeight)
    ctx.lineTo(chartX + chartWidth, chartY + chartHeight)
    ctx.stroke()

    list.forEach((count: number, index: number) => {
      const target = (count / max) * chartHeight
      const h = target * this.chartProgress
      const x = chartX + index * (singleBarWidth + gap)
      const y = chartY + chartHeight - h
      const color = count > 0 ? AppTheme.COLOR_PRIMARY : AppTheme.COLOR_CHART_IDLE
      ctx.fillStyle = color
      this.drawRoundedRect(ctx, x, y, singleBarWidth, Math.max(h, 2), 4)
      ctx.fill()

      if (index % 2 === 0) {
        ctx.fillStyle = AppTheme.COLOR_TEXT_MUTED
        ctx.font = `${AppTheme.FONT_HINT}px sans-serif`
        ctx.textAlign = 'center'
        ctx.fillText(this.monthLabel(index), x + singleBarWidth / 2, chartY + chartHeight + 18)
      }
    })
  }

  build() {
    Column() {
      this.PageHeader()

      if (this.isLoading) {
        Column() {
          Text('正在整理统计数据...')
            .fontSize(AppTheme.FONT_BODY)
            .fontColor(this.colorTextSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.totalCount() === 0) {
        this.EmptyState()
      } else {
        this.ContentSection()
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[this.colorBgTop, 0], [AppTheme.COLOR_BG_MIDDLE, 0.42], [this.colorBgBottom, 1]]
    })
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
              .fillColor(this.colorPrimaryDark)
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

        Text('时光概览')
          .fontSize(AppTheme.FONT_PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorTextPrimary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 50, left: this.pagePadding, right: this.pagePadding, bottom: 14 })
  }

  @Builder
  private EmptyState() {
    Column({ space: 14 }) {
      Text('还没有记录')
        .fontSize(AppTheme.FONT_EMPTY_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)
      Text('添加一个重要日子后，这里会自动整理。')
        .fontSize(AppTheme.FONT_BODY)
        .fontColor(this.colorTextSecondary)
      Button('去添加')
        .height(42)
        .padding({ left: 18, right: 18 })
        .linearGradient({ angle: 180, colors: [[this.colorPrimary, 0], [this.colorPrimaryDark, 1]] })
        .fontColor(Color.White)
        .borderRadius(42)
        .onClick(() => {
          this.pushUrl('pages/EventFormPage')
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: this.pagePadding, right: this.pagePadding })
  }

  @Builder
  private ContentSection() {
    Scroll() {
      Column({ space: 16 }) {
        this.OverviewCard()
        this.MonthReminderCard()
        this.InsightCard()
        this.OverallDistributionCard()
        this.MonthlyBarCard()
      }
      .width('100%')
      .padding({ left: this.pagePadding, right: this.pagePadding, top: 6, bottom: 30 })
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
  }

  @Builder
  private OverviewCard() {
    Row({ space: 10 }) {
      this.OverviewItem('全部', this.totalCount().toString())
      this.OverviewItem('7天内', this.next7DaysCount().toString())
      this.OverviewItem('30天内', this.next30DaysCount().toString())
      this.OverviewItem('提醒', this.reminderOnCount().toString())
    }
    .width('100%')
  }

  @Builder
  private OverviewItem(label: string, value: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(AppTheme.FONT_NUMBER_SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)
      Text(label)
        .fontSize(AppTheme.FONT_HINT)
        .fontColor(this.colorTextTertiary)
    }
    .layoutWeight(1)
    .height(84)
    .padding({ top: 4 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.colorSurface)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 12, color: this.shadowColor, offsetX: 0, offsetY: 6 })
  }

  @Builder
  private MonthlyBarCard() {
    Column({ space: 12 }) {
      Text('未来一年')
        .fontSize(AppTheme.FONT_CARD_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)

      Canvas(this.barContext)
        .width(this.barWidth)
        .height(this.barHeight)
        .onReady(() => {
          this.barReady = true
          this.renderBarChart()
        })

      if (this.totalCount() <= 2) {
        Text('数据较少，趋势仅供参考')
          .fontSize(AppTheme.FONT_CAPTION)
          .fontColor(this.colorTextTertiary)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.colorSurface)
    .borderRadius(this.cardRadius)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
  }

  @Builder
  private OverallDistributionCard() {
    Column({ space: 14 }) {
      Text('整体数据分布')
        .fontSize(AppTheme.FONT_CARD_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)

      this.TimeDistributionSection()
      this.RepeatDonutSection()
      this.CalendarSplitSection()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.colorSurface)
    .borderRadius(this.cardRadius)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
  }

  @Builder
  private TimeDistributionSection() {
    Column({ space: 8 }) {
      Text('时间')
        .fontSize(AppTheme.FONT_CAPTION)
        .fontColor(this.colorTextTertiary)

      ForEach(this.countdownBuckets(), (item: CountdownBucket) => {
        this.StructureRow(item.label, item.value, item.color)
      }, (item: CountdownBucket) => item.key)
    }
    .width('100%')
  }

  @Builder
  private RepeatDonutSection() {
    Column({ space: 8 }) {
      Text('重复')
        .fontSize(AppTheme.FONT_CAPTION)
        .fontColor(this.colorTextTertiary)

      Row({ space: 12 }) {
        Canvas(this.repeatDonutContext)
          .width(this.repeatDonutWidth)
          .height(this.repeatDonutHeight)
          .onReady(() => {
            this.repeatDonutReady = true
            this.renderRepeatDonutChart()
          })

        Column({ space: 8 }) {
          ForEach(this.repeatBuckets(), (item: RepeatBucket) => {
            this.LegendRow(item.label, item.value, item.color)
          }, (item: RepeatBucket) => item.key)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private CalendarSplitSection() {
    Column({ space: 8 }) {
      Text('日期')
        .fontSize(AppTheme.FONT_CAPTION)
        .fontColor(this.colorTextTertiary)

      Row() {
        if (this.calendarValue('solar') > 0) {
          Row()
            .height(10)
            .layoutWeight(this.calendarValue('solar'))
            .backgroundColor(this.calendarColor('solar'))
        }
        if (this.calendarValue('lunar') > 0) {
          Row()
            .height(10)
            .layoutWeight(this.calendarValue('lunar'))
            .backgroundColor(this.calendarColor('lunar'))
        }
      }
      .width('100%')
      .height(10)
      .clip(true)
      .borderRadius(5)
      .backgroundColor(AppTheme.COLOR_CHART_TRACK)

      Row({ space: 12 }) {
        ForEach(this.calendarBuckets(), (item: CalendarBucket) => {
          this.LegendRow(item.label, item.value, item.color)
        }, (item: CalendarBucket) => item.key)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private LegendRow(label: string, value: number, color: string) {
    Row({ space: 6 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(color)
      Text(`${label} ${value}`)
        .fontSize(AppTheme.FONT_HINT)
        .fontColor(this.colorTextTertiary)
    }
  }

  @Builder
  private StructureRow(label: string, value: number, color: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(AppTheme.FONT_BODY_SMALL)
          .fontColor(this.colorTextSecondary)
        Blank()
        Text(value.toString())
          .fontSize(AppTheme.FONT_BODY_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colorTextPrimary)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor(AppTheme.COLOR_CHART_TRACK)
          .borderRadius(4)

        Row()
          .width(this.structureWidthPercent(value))
          .height(8)
          .backgroundColor(color)
          .borderRadius(4)
      }
      .width('100%')
      .height(8)
    }
    .width('100%')
    .padding({ top: 2, bottom: 2 })
  }

  @Builder
  private MonthReminderCard() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text('本月待提醒事件')
          .fontSize(AppTheme.FONT_CARD_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorTextPrimary)
        Text('统计本月到来事件的提醒覆盖')
          .fontSize(AppTheme.FONT_CAPTION)
          .fontColor(this.colorTextTertiary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        this.MonthMetric('本月到来', this.dashboard.monthReminder.monthEventCount.toString(), AppTheme.COLOR_INFO_SOFT, this.colorPrimary)
        this.MonthMetric('有提醒', this.dashboard.monthReminder.reminderCount.toString(), AppTheme.COLOR_SUCCESS_SOFT, AppTheme.COLOR_SUCCESS_DARK)
        this.MonthMetric('无提醒', this.dashboard.monthReminder.noReminderCount.toString(), AppTheme.COLOR_WARNING_SOFT, AppTheme.COLOR_WARNING_DARK)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.colorSurface)
    .borderRadius(this.cardRadius)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
  }

  @Builder
  private MonthMetric(label: string, value: string, bgColor: string, textColor: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(AppTheme.FONT_NUMBER_SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(AppTheme.FONT_HINT)
        .fontColor(this.colorTextTertiary)
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(bgColor)
    .borderRadius(16)
  }

  @Builder
  private InsightCard() {
    Column({ space: 12 }) {
      Text('自动洞察')
        .fontSize(AppTheme.FONT_CARD_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)

      ForEach(this.dashboard.insights, (text: string) => {
        Row({ space: 8 }) {
          Row()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(this.colorPrimary)
          Text(text)
            .fontSize(AppTheme.FONT_BODY_SMALL)
            .lineHeight(20)
            .fontColor(this.colorTextSecondary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }, (text: string) => text)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.colorSurface)
    .borderRadius(this.cardRadius)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
  }

  private structureWidthPercent(value: number): string {
    if (value <= 0) {
      return '0%'
    }
    const total = Math.max(1, this.totalCount())
    const ratio = value / total
    return `${Math.max(6, Math.round(ratio * 100))}%`
  }

  private calendarValue(key: 'solar' | 'lunar'): number {
    let value = 0
    this.calendarBuckets().forEach((item: CalendarBucket) => {
      if (item.key === key) {
        value = item.value
      }
    })
    return value
  }

  private calendarColor(key: 'solar' | 'lunar'): string {
    let color = AppTheme.COLOR_CHART_IDLE
    this.calendarBuckets().forEach((item: CalendarBucket) => {
      if (item.key === key) {
        color = item.color
      }
    })
    return color
  }
}
