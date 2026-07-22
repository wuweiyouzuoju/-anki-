// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';

/** Small, reusable help sheet. Option help is intentionally opt-in through ⓘ only. */
@Component
export struct FieldHelpPanel {
  @Prop title: Resource = $r('app.string.deck_options_title');
  @Prop body: Resource = $r('app.string.deck_learn_steps_help');
  onClose: () => void = (): void => {};

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.35)').onClick(() => this.onClose())
      Column({ space: AppDimens.SPACE_12 }) {
        Text(this.title).fontSize(AppDimens.FONT_PANEL_TITLE).fontWeight(FontWeight.Bold).width('100%')
        Scroll() {
          Text(this.body).fontSize(AppDimens.FONT_BODY).fontColor($r('app.color.text_secondary')).width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: '55%' })
        .scrollBar(BarState.Auto)
        Button($r('app.string.done')).width('100%').height(AppDimens.BUTTON_HEIGHT).onClick(() => this.onClose())
      }
      .width('88%').constraintSize({ maxWidth: 480, maxHeight: '75%' }).padding(AppDimens.CARD_PADDING)
      .backgroundColor($r('app.color.surface_card')).borderRadius(AppDimens.RADIUS_CARD)
      .onClick(() => {})
    }.width('100%').height('100%')
  }
}
