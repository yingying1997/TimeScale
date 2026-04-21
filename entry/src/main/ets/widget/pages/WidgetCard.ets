let storage = new LocalStorage()

@Entry(storage)
@Component
struct WidgetCard {
  readonly actionType: string = 'router'
  readonly abilityName: string = 'EntryAbility'
  readonly message: string = 'from_widget'
  readonly titleColor: string = '#10233C'
  readonly subTitleColor: string = '#5F738D'
  readonly backgroundStartColor: string = '#F5F9FD'
  readonly backgroundEndColor: string = '#EAF2FA'
  readonly cardBorderColor: string = '#CCFFFFFF'

  @LocalStorageProp('dimension') dimension: number = 2
  @LocalStorageProp('firstTitle') firstTitle: string = '赶快去应用里添加吧！'
  @LocalStorageProp('event1Title') event1Title: string = ''
  @LocalStorageProp('event1CountdownText') event1CountdownText: string = ''
  @LocalStorageProp('event1Color') event1Color: string = '#8C939F'
  @LocalStorageProp('event1DateText') event1DateText: string = ''
  @LocalStorageProp('event1Status') event1Status: string = 'future'
  @LocalStorageProp('event2Title') event2Title: string = ''
  @LocalStorageProp('event2CountdownText') event2CountdownText: string = ''
  @LocalStorageProp('event2Color') event2Color: string = '#8C939F'
  @LocalStorageProp('event2DateText') event2DateText: string = ''
  @LocalStorageProp('event2Status') event2Status: string = 'future'
  @LocalStorageProp('event3Title') event3Title: string = ''
  @LocalStorageProp('event3CountdownText') event3CountdownText: string = ''
  @LocalStorageProp('event3Color') event3Color: string = '#8C939F'
  @LocalStorageProp('event3DateText') event3DateText: string = ''
  @LocalStorageProp('event3Status') event3Status: string = 'future'

  build() {
    Row() {
      if (this.dimension === 2) {
        this.renderDoubleCellCard()
      } else {
        this.renderQuadCellCard()
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.dimension === 2 ? 16 : 12)
    .linearGradient({
      angle: 135,
      colors: [[this.backgroundStartColor, 0], [this.backgroundEndColor, 1]]
    })
    .borderRadius(this.dimension === 2 ? 26 : 24)
    .border({ width: 1, color: this.cardBorderColor })
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        action: this.actionType,
        abilityName: this.abilityName,
        params: { message: this.message }
      })
    })
  }

  @Builder
  renderDoubleCellCard() {
    if (this.event1Title) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          Row() {
            if (this.event1Status === 'today') {
              Image($r('app.media.ringDot'))
                .width(14)
                .height(14)
                .fillColor(this.event1Color)
            } else if (this.event1Status === 'past') {
              Image($r('app.media.ring'))
                .width(14)
                .height(14)
                .fillColor(this.event1Color)
            } else {
              Image($r('app.media.dot'))
                .width(14)
                .height(14)
                .fillColor(this.event1Color)
            }
          }
          .width(16)
          .height(16)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          Text(this.event1Title)
            .layoutWeight(1)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.titleColor)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('76%')
        .alignItems(VerticalAlign.Center)
        .margin({ left: '12%' })

        Text(this.event1DateText)
          .width('100%')
          .fontSize(14)
          .fontColor(this.subTitleColor)
          .maxLines(1)
          .textAlign(TextAlign.Center)

        Text(this.primaryStatusValue(this.event1Status, this.event1CountdownText))
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.event1Color)
          .maxLines(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
    } else {
      this.renderEmptyCard()
    }
  }

  @Builder
  renderQuadCellCard() {
    if (!this.event1Title && !this.event2Title && !this.event3Title) {
      this.renderEmptyCard()
    } else {
      Column() {
        if (this.event1Title) {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Row({ space: 8 }) {
                Row() {
                  if (this.event1Status === 'today') {
                    Image($r('app.media.ringDot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event1Color)
                  } else if (this.event1Status === 'past') {
                    Image($r('app.media.ring'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event1Color)
                  } else {
                    Image($r('app.media.dot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event1Color)
                  }
                }
                .width(16)
                .height(16)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)

                Text(this.event1Title)
                  .layoutWeight(1)
                  .fontSize(12.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.titleColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text(this.event1DateText)
                .fontSize(10)
                .fontColor(this.subTitleColor)
                .maxLines(1)
                .margin({ left: 24 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.compactCountdownText(this.event1Status, this.event1CountdownText))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.event1Color)
              .maxLines(1)
              .margin({ left: 6 })
          }
          .width('100%')
          .height(42)
          .alignItems(VerticalAlign.Center)
        }
        if (this.event2Title) {
          Row() {
            Blank()
              .width(18)

            Column()
              .layoutWeight(1)
              .height(1)
              .backgroundColor('#33C7D7E6')
          }
          .width('100%')

          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Row({ space: 8 }) {
                Row() {
                  if (this.event2Status === 'today') {
                    Image($r('app.media.ringDot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event2Color)
                  } else if (this.event2Status === 'past') {
                    Image($r('app.media.ring'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event2Color)
                  } else {
                    Image($r('app.media.dot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event2Color)
                  }
                }
                .width(16)
                .height(16)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)

                Text(this.event2Title)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontWeight(FontWeight.Regular)
                  .fontColor(this.titleColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text(this.event2DateText)
                .fontSize(10)
                .fontColor(this.subTitleColor)
                .maxLines(1)
                .margin({ left: 24 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.compactCountdownText(this.event2Status, this.event2CountdownText))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.event2Color)
              .maxLines(1)
              .margin({ left: 6 })
          }
          .width('100%')
          .height(42)
          .alignItems(VerticalAlign.Center)
        }
        if (this.event3Title) {
          Row() {
            Blank()
              .width(18)

            Column()
              .layoutWeight(1)
              .height(1)
              .backgroundColor('#33C7D7E6')
          }
          .width('100%')

          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Row({ space: 8 }) {
                Row() {
                  if (this.event3Status === 'today') {
                    Image($r('app.media.ringDot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event3Color)
                  } else if (this.event3Status === 'past') {
                    Image($r('app.media.ring'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event3Color)
                  } else {
                    Image($r('app.media.dot'))
                      .width(14)
                      .height(14)
                      .fillColor(this.event3Color)
                  }
                }
                .width(16)
                .height(16)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)

                Text(this.event3Title)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontWeight(FontWeight.Regular)
                  .fontColor(this.titleColor)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Text(this.event3DateText)
                .fontSize(10)
                .fontColor(this.subTitleColor)
                .maxLines(1)
                .margin({ left: 24 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.compactCountdownText(this.event3Status, this.event3CountdownText))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.event3Color)
              .maxLines(1)
              .margin({ left: 6 })
          }
          .width('100%')
          .height(42)
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
  }

  @Builder
  renderEmptyCard() {
    Column({ space: 8 }) {
      Text('暂无事件')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.titleColor)

      Text(this.firstTitle)
        .fontSize(11)
        .fontColor(this.subTitleColor)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  private primaryStatusValue(status: string, countdownText: string): string {
    if (!countdownText) {
      return '--'
    }
    if (status === 'today') {
      return '今天'
    }
    return countdownText
  }

  private compactCountdownText(status: string, countdownText: string): string {
    if (!countdownText) {
      return '--'
    }
    if (status === 'today') {
      return '今天'
    }
    return countdownText
  }
}


