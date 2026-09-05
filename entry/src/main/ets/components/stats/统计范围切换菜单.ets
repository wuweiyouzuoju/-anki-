// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 取全屏转场时长, 取全屏转场曲线 } from '../../utils/转场时长';

// ========================================================
// @名称 统计范围切换菜单
//
// @作用
// 统计页顶栏右上角「近一年/全部」按钮触发的下拉选择菜单。
// 视觉与交互完全对齐设置页的 模式切换菜单：透明承接层、右上角双项菜单、
// 当前项主色高亮、菜单外点击关闭，以及纯透明度淡入淡出。
// ========================================================

@Component
export struct 统计范围切换菜单 {
  @Prop 当前全部范围: boolean = false;
  @Prop 主色: ResourceColor = $r('app.color.action_primary');
  @Prop 顶部偏移: number = 68;
  选择回调: (全部范围: boolean) => void = (_全部范围: boolean): void => {};
  关闭回调: () => void = (): void => {};

  build() {
    Stack() {
      // 透明承接层：不遮暗不模糊，仅让菜单外点击可关闭。
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick((): void => this.关闭回调())

      Column() {
        Text($r('app.string.stats_hours_range_1y'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor(!this.当前全部范围 ? this.主色 : $r('app.color.text_primary'))
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.选择回调(false))

        Divider()
          .color($r('app.color.border_subtle'))
          .strokeWidth(应用尺寸.卡片边框)
          .margin({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })

        Text($r('app.string.stats_hours_range_all'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor(this.当前全部范围 ? this.主色 : $r('app.color.text_primary'))
          .width('100%')
          .height(应用尺寸.行动按钮高度)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.选择回调(true))
      }
      .width(160)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .margin({ top: this.顶部偏移, right: 应用尺寸.页面内边距_水平 })
      .onClick((): void => {
        // 阻断点击穿透到透明承接层。
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }),
        TransitionEffect.opacity(0)
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.TopEnd)
  }
}
