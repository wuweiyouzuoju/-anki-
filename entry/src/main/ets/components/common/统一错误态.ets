// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';

@Component
export struct 统一错误态 {
  @Prop 文案: ResourceStr;
  @Prop 重试文案: ResourceStr = '重试';
  onRetry: () => void = (): void => {};

  build() {
    Column({ space: 应用尺寸.间距_12 }) {
      Text('⚠️').fontSize(48)
      Text(this.文案)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Button(this.重试文案)
        .type(ButtonType.Capsule)
        .height(应用尺寸.按钮高度)
        .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16 })
        .fontSize(应用尺寸.字号_按钮)
        .backgroundColor($r('app.color.surface_card'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => this.onRetry())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16 })
  }
}
