// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 字段帮助面板 {
  @Prop 标题: Resource = $r('app.string.deck_options_title');
  @Prop 正文: Resource = $r('app.string.deck_learn_steps_help');
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  onClose: () => void = (): void => {};

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.35)').onClick(() => this.onClose())
      Column({ space: 应用尺寸.间距_12 }) {
        Text(this.标题).fontSize(应用尺寸.字号_面板标题).fontWeight(FontWeight.Bold).width('100%')
        Scroll() {
          Text(this.正文).fontSize(应用尺寸.字号_正文).fontColor($r('app.color.text_secondary')).width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: '55%' })
        .scrollBar(BarState.Auto)
        Button($r('app.string.done'))
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.主色按钮背景)
          .borderRadius(应用尺寸.圆角_面板)
          .onClick(() => this.onClose())
      }
      .width('88%').constraintSize({ maxWidth: 480, maxHeight: '75%' }).padding(应用尺寸.卡片内边距)
      .backgroundColor($r('app.color.surface_card')).borderRadius(应用尺寸.圆角_卡片)
      .onClick(() => {})
    }.width('100%').height('100%')
  }
}
