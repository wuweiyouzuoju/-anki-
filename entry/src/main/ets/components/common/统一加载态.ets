// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';

@Component
export struct 统一加载态 {
  @Prop 文案: ResourceStr = '加载中…';
  @Prop 尺寸: number = 40;

  build() {
    Column({ space: 应用尺寸.间距_8 }) {
      LoadingProgress().width(this.尺寸).height(this.尺寸).color($r('app.color.text_secondary'))
      Text(this.文案).fontSize(应用尺寸.字号_正文).fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
