import { AppDimens } from '../utils/AppDimens';

/**
 * 首页动作菜单（顶部弹出形态，纯 UI 积木）。
 * 触发按钮在右上角，菜单锚定其下方弹出，手指零移动；
 * 普通下拉式打开：不加 dim/磨砂遮罩，透明层承接外部点击关闭。
 */
@Component
export struct HomeActionPanel {
  onCreateDeck: () => void = (): void => {};
  onImportDeck: () => void = (): void => {};
  onClose: () => void = (): void => {};

  build() {
    Stack() {
      // 透明承接层：不遮暗不模糊，仅让菜单外点击可关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick((): void => this.onClose())

      Column() {
        Text($r('app.string.create_deck_title'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .height(AppDimens.CTA_HEIGHT)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.onCreateDeck())
        Divider()
          .color($r('app.color.border_subtle'))
          .strokeWidth(AppDimens.CARD_BORDER)
          .margin({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
        Text($r('app.string.transfer_import_deck'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .height(AppDimens.CTA_HEIGHT)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.onImportDeck())
      }
      .width(200)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_CARD)
      .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
      .margin({ top: 64, right: AppDimens.PAGE_PADDING_H })
      .onClick(() => {
        // 阻断点击穿透到遮罩
      })
      // 从触发按钮处向下轻推入场（思路参考：华为官方 TransitionEffect 示例）
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
