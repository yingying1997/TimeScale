import { AppTheme } from '../theme/AppTheme'
import { AppLogger } from '../utils/AppLogger'

@Entry
@Component
struct PrivacyPolicyPage {
  private readonly pagePadding: number = AppTheme.PAGE_PADDING
  private readonly cardRadius: number = AppTheme.CARD_RADIUS
  private readonly colorBgTop: string = AppTheme.COLOR_BG_TOP
  private readonly colorBgBottom: string = AppTheme.COLOR_BG_BOTTOM
  private readonly colorSurface: string = AppTheme.COLOR_SURFACE
  private readonly colorSurfaceSoft: string = AppTheme.COLOR_SURFACE_SOFT
  private readonly colorPrimaryDark: string = AppTheme.COLOR_PRIMARY_DARK
  private readonly colorTextPrimary: string = AppTheme.COLOR_TEXT_PRIMARY
  private readonly colorTextSecondary: string = AppTheme.COLOR_TEXT_SECONDARY
  private readonly colorTextTertiary: string = AppTheme.COLOR_TEXT_TERTIARY
  private readonly shadowColor: string = AppTheme.SHADOW_COLOR

  private back(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (error) {
      AppLogger.error('PrivacyPolicyPage', `Failed to navigate back: ${error instanceof Error ? error.message : `${error}`}`)
    }
  }

  build() {
    Column() {
      this.PageHeader()

      Scroll() {
        Column({ space: 16 }) {
          this.PolicyCard()
        }
        .width('100%')
        .padding({ left: this.pagePadding, right: this.pagePadding, top: 6, bottom: 28 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
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
            .onClick(() => this.back())

          Blank()
        }
        .width('100%')

        Text('隐私政策')
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
  private PolicyCard() {
    Column({ space: 16 }) {
      this.Section(
        '一、我们处理的信息',
        '时光刻度用于记录纪念日、倒数日、生日等重要日期。您在应用中主动填写的标题、备注、日期、重复方式、提醒方式等信息，仅用于事件记录、展示、排序、统计与提醒。'
      )
      this.Section(
        '二、信息存储方式',
        '应用会将相关事件数据保存在当前设备本地，用于完成倒数日展示、提醒安排、桌面卡片和统计分析等功能。当前版本不提供账号登录、云同步或开发者服务器存储。'
      )
      this.Section(
        '三、权限使用说明',
        '当您主动开启提醒功能时，应用可能申请读取日历和写入日历权限，用于将事件提醒同步到系统日历。如果您拒绝授权，您仍可使用记录和查看功能，但系统日历提醒可能无法正常使用。'
      )
      this.Section(
        '四、第三方共享说明',
        '当前版本未接入第三方广告 SDK、统计 SDK 或登录 SDK。除将您主动设置提醒的必要信息写入设备系统日历外，我们不会向第三方共享您的事件数据。'
      )
      this.Section(
        '五、您的选择权利',
        '您可以在应用内新增、编辑或删除事件数据。删除事件后，应用会尝试同步清理其对应的系统提醒。'
      )
      Column({ space: 6 }) {
        Text('开发者：Ying Studio')
          .fontSize(AppTheme.FONT_BODY_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colorTextPrimary)
          .width('100%')
        Text('应用包名：com.ying.timescale')
          .fontSize(AppTheme.FONT_CAPTION)
          .fontColor(this.colorTextTertiary)
          .width('100%')
        Text('完整隐私政策网址请以应用市场展示信息为准。')
          .fontSize(AppTheme.FONT_CAPTION)
          .lineHeight(18)
          .fontColor(this.colorTextTertiary)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor(this.colorSurfaceSoft)
      .borderRadius(16)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(this.colorSurface)
    .borderRadius(this.cardRadius)
    .border({ width: 1, color: AppTheme.COLOR_BORDER })
    .shadow({ radius: 14, color: this.shadowColor, offsetX: 0, offsetY: 8 })
  }

  @Builder
  private Section(title: string, body: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(AppTheme.FONT_CARD_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colorTextPrimary)
        .width('100%')
      Text(body)
        .fontSize(AppTheme.FONT_BODY_SMALL)
        .lineHeight(22)
        .fontColor(this.colorTextSecondary)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
