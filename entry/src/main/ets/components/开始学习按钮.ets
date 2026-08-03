// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

// ========================================================
// @块ID UI-START-STUDY-BUTTON-001
// @名称 开始学习按钮 组件主体字段与提亮色方法
//
// @作用
// 开始学习主按钮：主屏窄屏底部与详情 pane 共用。
// B 方案（2026-07-22）：按下时用 主色按钮按下（深一档）给出视觉反馈。
// 渐变方案（2026-07-22）：默认状态用 linearGradient 从 主色按钮背景（顶部）到 主色按钮按下（底部），
// 让主操作按钮有"立体凸起"质感；按下时整体切到 主色按钮按下 纯色（linearGradient 两端同色 = 纯色），
// 视觉上按钮"被按下凹陷"。渐变方向 180°（从上到下）模拟自然光源。
//
// @输入
// @Prop 待学数：待学卡数（用于按钮内文案）。
// 开始学习回调：用户点击按钮时上抛。
//
// @输出
// 渲染开始学习按钮；点击通过 开始学习回调 上抛。
//
// @业务规则
// 跟随用户选择的颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）。
// 2.1.4.1 对比度：按钮背景用 主色按钮背景 专用档（配 #FFFFFF 文字 ≥ 4.5:1），
// 高明度主题（lemon/sunset）下比 动作主色 更深，但白字可读性达标。
// 提亮色：往白色混合 20% 让按钮色偏淡（用户决策 2026-07-22：10% 不够，加到 20%），
// 只作用于本按钮渲染，不改主题色定义，不影响其他 primary 场景。
//
// @副作用
// 无。仅渲染与上抛回调。
// ========================================================
@Component
export struct 开始学习按钮 {
  @Prop 待学数: number = 0;
  开始学习回调: () => void = (): void => {
  };
  // 跟随用户选择的颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）
  // 2.1.4.1 对比度：按钮背景用 主色按钮背景 专用档（配 #FFFFFF 文字 ≥ 4.5:1），
  // 高明度主题（lemon/sunset）下比 动作主色 更深，但白字可读性达标
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  @State private 已按下: boolean = false;

  // ========================================================
  // @块ID UI-START-STUDY-BUTTON-002
  // @名称 提亮色
  //
  // @作用
  // 把传入 hex 色往白色混合 20%，让按钮色偏淡。
  //
  // @输入
  // 十六进制色：#RRGGBB 或 RRGGBB。
  //
  // @输出
  // 提亮后的 #RRGGBB 字符串。
  //
  // @业务规则
  // 用户决策 2026-07-22：10% 不够，加到 20%。只作用于本按钮渲染，不改主题色定义。
  //
  // @副作用
  // 无。
  // ========================================================
  private 提亮色(十六进制色: string): string {
    const s: string = 十六进制色.startsWith('#') ? 十六进制色.slice(1) : 十六进制色;
    const r0: number = parseInt(s.slice(0, 2), 16);
    const g0: number = parseInt(s.slice(2, 4), 16);
    const b0: number = parseInt(s.slice(4, 6), 16);
    const alpha: number = 0.20;
    const r: number = Math.round(r0 * (1 - alpha) + 255 * alpha);
    const g: number = Math.round(g0 * (1 - alpha) + 255 * alpha);
    const b: number = Math.round(b0 * (1 - alpha) + 255 * alpha);
    const 转十六进制 = (n: number): string => {
      const 限定: number = Math.max(0, Math.min(255, n));
      const h: string = 限定.toString(16);
      return h.length === 1 ? '0' + h : h;
    };
    return '#' + 转十六进制(r) + 转十六进制(g) + 转十六进制(b);
  }

  // ========================================================
  // @块ID UI-START-STUDY-BUTTON-003
  // @名称 开始学习按钮主渲染
  //
  // @作用
  // 渲染开始学习按钮：渐变背景 + "开始学习"标题 + 待学卡数小字。
  //
  // @输入
  // @Prop 待学数 + @StorageProp 主色按钮背景色 / 主色按钮按下色 + @State 已按下。
  //
  // @输出
  // 主操作按钮视觉；Touch Down 切深色按下态、Up/Cancel 回渐变凸起态；点击上抛 开始学习回调。
  //
  // @业务规则
  // 按下时整体切到 主色按钮按下色（深一档）模拟"凹陷"，
  // 抬起/取消回到 主色按钮背景色 → 主色按钮按下色 渐变模拟"凸起"。
  // 提亮色 应用在两端颜色上，让按钮整体偏淡。
  //
  // @副作用
  // 无。仅上抛回调。
  // ========================================================
  build() {
    Button() {
      Row() {
        Text($r('app.string.start_study'))
          .fontSize(应用尺寸.字号_标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.action_on_primary'))
        Blank()
        Text($r('app.string.card_pending_short', this.待学数))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.action_on_primary'))
      }
      .width('100%')
      .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8 })
    }
    .width('100%')
    .height(应用尺寸.行动按钮高度)
    .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
    .linearGradient({
      angle: 180,
      colors: this.已按下
        ? [[this.提亮色(this.主色按钮按下色) as ResourceColor, 0.0], [this.提亮色(this.主色按钮按下色) as ResourceColor, 1.0]]
        : [[this.提亮色(this.主色按钮背景色) as ResourceColor, 0.0], [this.提亮色(this.主色按钮按下色) as ResourceColor, 1.0]]
    })
    .borderRadius(应用尺寸.圆角_行动按钮)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      // 按下时整体切到 主色按钮按下色（深一档）模拟"凹陷"，抬起/取消回到 主色按钮背景色→主色按钮按下色 渐变模拟"凸起"
      if (event.type === TouchType.Down) {
        this.已按下 = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.已按下 = false;
      }
    })
    .onClick(() => {
      this.开始学习回调();
    })
  }
}
