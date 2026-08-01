// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';

@Component
export struct 按下态按钮 {
  @Prop 文案: ResourceStr;
  @Prop 图标: Resource | undefined = undefined;
  @Prop 选中态背景: ResourceColor;
  @Prop 字号: number = 应用尺寸.字号_按钮;
  @Prop 字色: ResourceColor = $r('app.color.text_primary');
  点击回调: () => void = (): void => {};
  @State private 按下中: boolean = false;

  build() {
    Button() {
      Row({ space: 应用尺寸.间距_8 }) {
        if (this.图标 !== undefined) {
          Image(this.图标).width(16).height(16)
        }
        Text(this.文案)
          .fontSize(this.字号)
          .fontColor(this.字色)
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(应用尺寸.按钮高度)
    .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
    .constraintSize({ minWidth: 0 })
    .fontColor(this.字色)
    .backgroundColor(this.按下中 ? this.选中态背景 : $r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_胶囊)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.按下中 = true; }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下中 = false; }
    })
    .onClick(() => { this.点击回调(); })
  }
}
