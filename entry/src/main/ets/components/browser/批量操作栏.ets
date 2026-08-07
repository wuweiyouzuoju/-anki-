// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @名称 批量操作栏
//
// @作用
// 浏览页 T8 批量操作栏：多选模式下固定在底部的按钮组。
// 阶段 3 实现 5 个已有后端能力的操作：改牌组 / 设置标志 / 挂起 / 恢复 / 删除。
// 其余 4 个（标签 / 重调度 / 重新定位 / 改笔记类型）待后端能力补齐后扩展。
//
// @输入
// isDark: 是否深色主题（预留，当前按钮配色走 color 资源）
// busy: 父级是否正在执行批量操作（禁用所有按钮）
// 选中数: 当前选中行数（按钮文案展示用）
//
// @输出
// on改牌组 / on设置标志 / on挂起 / on恢复 / on删除: 五个操作回调，父级负责弹层确认与落盘
//
// @Invariants
// - 本组件不直接调后端，所有操作经回调上抛
// - busy=true 时所有按钮禁用，防止重复点击
// - 选中数 === 0 时不应显示本组件（由父级 if 控制）
//
// @Extension Points
// - 阶段 3.5/4 补齐后端能力后，按钮组可扩展为 8 个（加标签/重调度/重新定位/改笔记类型）
// - 按钮文案走 i18n，新增按钮只需加 browser_action_* key
//
// @副作用
// 仅通过外部回调引发后端写入；本组件不直接落盘。
// ========================================================

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 批量操作栏 {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  @Prop 选中数: number = 0;
  on改牌组: () => void = (): void => {};
  on设置标志: () => void = (): void => {};
  on挂起: () => void = (): void => {};
  on恢复: () => void = (): void => {};
  on删除: () => void = (): void => {};
  // 帮助按钮上抛：由父组件（浏览页）统一渲染 字段帮助面板
  onHelp: () => void = (): void => {};

  // 按钮按下态背景色（走主题系统，与 首页/学习页 主色容器同源）
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @State private 已按下: number = -1;

  /** 生成按钮按下态背景色（按下时用主色容器，否则用 surface_card）。 */
  private 按钮背景(tag: number): ResourceColor {
    if (this.已按下 === tag) {
      return this.主色容器色;
    }
    return $r('app.color.surface_card');
  }

  build() {
    Row({ space: 应用尺寸.间距_8 }) {
      // 帮助按钮：点击上抛到父组件弹出批量操作说明（4 个操作不便每个加 ⓘ，统一入口）
      Text($r('app.string.field_help_button'))
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 应用尺寸.间距_4, right: 应用尺寸.间距_4 })
        .onClick((): void => { this.onHelp(); })

      Button($r('app.string.browser_action_change_deck'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.按钮背景(0))
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) { this.已按下 = 0; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.已按下 = -1; }
        })
        .onClick((): void => { this.on改牌组(); })

      Button($r('app.string.browser_action_set_flag'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.按钮背景(1))
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) { this.已按下 = 1; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.已按下 = -1; }
        })
        .onClick((): void => { this.on设置标志(); })

      Button($r('app.string.browser_action_suspend'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.按钮背景(2))
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) { this.已按下 = 2; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.已按下 = -1; }
        })
        .onClick((): void => { this.on挂起(); })

      Button($r('app.string.browser_action_restore'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.按钮背景(3))
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) { this.已按下 = 3; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.已按下 = -1; }
        })
        .onClick((): void => { this.on恢复(); })

      Button($r('app.string.browser_action_delete'))
        .layoutWeight(1)
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.error_text'))
        .backgroundColor(this.按钮背景(4))
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy)
        .onTouch((e: TouchEvent): void => {
          if (e.type === TouchType.Down) { this.已按下 = 4; }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.已按下 = -1; }
        })
        .onClick((): void => { this.on删除(); })
    }
    .width('100%')
    .padding({
      left: 应用尺寸.间距_16,
      right: 应用尺寸.间距_16,
      top: 应用尺寸.间距_8,
      bottom: 应用尺寸.间距_8
    })
    .backgroundColor($r('app.color.surface_page'))
    .border({ width: 0.5, color: $r('app.color.divider') })
  }
}
