// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-HEADER-001
// @名称 主页顶部工具栏
//
// @作用
// 渲染主页顶部工具栏：左侧设置+浏览按钮、右侧创建牌组按钮。
// 替换原 首页.ets 的 @Builder 顶部工具栏()，用 按下态按钮 积木替代手动 工具栏按下状态 1/2 状态机。
//
// @输入
// on设置点击: () => void  设置按钮点击回调
// on浏览点击: () => void  浏览按钮点击回调
// on创建牌组点击: () => void  创建牌组按钮点击回调
// 主色容器色: ResourceColor  按下态背景色
// 页面底色微染值: ResourceColor  工具栏背景色
// 动作主色: ResourceColor  创建牌组按钮字色
//
// @输出
// 渲染 Row(设置按钮 + 浏览按钮 + Blank + 创建牌组按钮)
//
// @业务规则
// 设置按钮字色用 text_primary；浏览按钮字色用 text_primary；创建牌组按钮字色用 动作主色 + Medium 字重
// 三按钮均使用 按下态按钮 积木自带 pressed 视觉反馈
//
// @副作用
// 无。
// ========================================================

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 按下态按钮 } from '../common/按下态按钮';

@Component
export struct 主页顶部工具栏 {
  on设置点击: () => void = (): void => {};
  on浏览点击: () => void = (): void => {};
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

      按下态按钮({
        文案: $r('app.string.browser_title'),
        选中态背景: this.主色容器色,
        字色: $r('app.color.text_primary'),
        点击回调: (): void => { this.on浏览点击(); }
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
