// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';

@Component
export struct 统一空态 {
  @Prop 图标: Resource | undefined = undefined;
  @Prop 标题: ResourceStr;
  @Prop 副标题: ResourceStr = '';
  @Prop 动作文案: ResourceStr = '';
  onAction: () => void = () => {};

  build() {
    Column({ space: 应用尺寸.间距_12 }) {
      if (this.图标 !== undefined) {
        Image(this.图标).width(56).height(56)
      }
      Text(this.标题)
        .fontSize(应用尺寸.字号_标题)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
      if (this.副标题 !== '') {
        Text(this.副标题)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      if (this.动作文案 !== '') {
        Button(this.动作文案)
          .type(ButtonType.Capsule)
          .height(应用尺寸.按钮高度)
          .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16 })
          .fontSize(应用尺寸.字号_按钮)
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 应用尺寸.间距_16, right: 应用尺寸.间距_16 })
  }
}
