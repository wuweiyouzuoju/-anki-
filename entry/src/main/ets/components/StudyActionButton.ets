// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';

/**
 * 学习页专用操作按钮。每个实例独立持有按压状态，避免父级一次状态刷新
 * 让同一行的兄弟按钮同时进入按压视觉态。
 */
@Component
export struct StudyActionButton {
  @Prop label: ResourceStr;
  @Prop buttonHeight: number = 应用尺寸.行动按钮高度;
  @Prop labelFontSize: number = 应用尺寸.字号_按钮;
  @Prop labelColor: ResourceColor = $r('app.color.text_primary');
  @Prop pressedBackground: ResourceColor;
  @Prop pressedBorderColor: ResourceColor = $r('app.color.border_subtle');
  onActivate: () => void = (): void => {};
  @State private isPressed: boolean = false;

  build() {
    Button(this.label)
      // 按压视觉完全由本组件的局部状态控制，关闭 Button 自带的缩放叠加效果。
      .stateEffect(false)
      .layoutWeight(1)
      .height(this.buttonHeight)
      .fontSize(this.labelFontSize)
      .fontColor(this.labelColor)
      .backgroundColor(this.isPressed ? this.pressedBackground : $r('app.color.surface_card'))
      .border({
        width: 应用尺寸.卡片边框,
        color: this.isPressed ? this.pressedBorderColor : $r('app.color.border_subtle')
      })
      .borderRadius(应用尺寸.圆角_面板)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      })
      .onClick((): void => {
        this.onActivate();
      })
  }
}
