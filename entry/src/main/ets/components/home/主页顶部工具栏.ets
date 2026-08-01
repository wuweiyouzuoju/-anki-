// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 按下态按钮 } from '../common/按下态按钮';

@Component
export struct 主页顶部工具栏 {
  on设置点击: () => void = (): void => {};
  on创建牌组点击: () => void = (): void => {};
  @Prop 主色容器色: ResourceColor;
  @Prop 页面底色微染值: ResourceColor;
  @Prop 动作主色: ResourceColor;

  build() {
    Row() {
      按下态按钮({
        文案: $r('app.string.top_settings'),
        选中态背景: this.主色容器色,
        字色: $r('app.color.text_primary'),
        点击回调: (): void => { this.on设置点击(); }
      })

      Blank()

      按下态按钮({
        文案: $r('app.string.create_deck'),
        选中态背景: this.主色容器色,
        字色: this.动作主色,
        点击回调: (): void => { this.on创建牌组点击(); }
      })
    }
    .width('100%')
    .height(应用尺寸.工具栏高度)
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor(this.页面底色微染值)
  }
}
