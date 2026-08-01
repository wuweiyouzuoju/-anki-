// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 开始学习按钮 {
  @Prop 待学数: number = 0;
  开始学习回调: () => void = (): void => {
  };
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下色: string = '#1E4FB8';
  @State private 已按下: boolean = false;

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
