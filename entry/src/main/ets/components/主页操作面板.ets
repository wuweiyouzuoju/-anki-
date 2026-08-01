// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';

@Component
export struct 主页操作面板 {
  创建牌组回调: () => void = (): void => {};
  导入牌组回调: () => void = (): void => {};
  关闭回调: () => void = (): void => {};

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick((): void => this.关闭回调())

      Column() {
        Text($r('app.string.create_deck_title'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.创建牌组回调())
        Divider()
          .color($r('app.color.border_subtle'))
          .strokeWidth(应用尺寸.卡片边框)
          .margin({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
        Text($r('app.string.transfer_import_deck'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.导入牌组回调())
      }
      .width(200)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .margin({ top: 64, right: 应用尺寸.页面内边距_水平 })
      .onClick(() => {
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: -12 }))
          .animation({ curve: Curve.EaseOut, duration: 200 }),
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: -8 }))
          .animation({ curve: Curve.EaseIn, duration: 160 })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopEnd)
  }
}
