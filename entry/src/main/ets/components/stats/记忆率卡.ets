// SPDX-License-Identifier: AGPL-3.0-or-later

// 记忆率卡：渲染 GraphsView.retrievability 的平均记忆率。
// 大字展示百分比 + 进度条，仅在 FSRS 开启时有意义。

import type { RetrievabilitySummary } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 记忆率卡 {
  @Prop 记忆率数据: RetrievabilitySummary | null = null;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';

  build() {
    Column() {
      if (this.记忆率数据 === null) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染记忆率(this.记忆率数据 as RetrievabilitySummary)
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染记忆率(d: RetrievabilitySummary) {
    Column({ space: 应用尺寸.间距_8 }) {
      Row() {
        Text(`${d.average.toFixed(1)}%`)
          .fontSize(应用尺寸.字号_主视觉)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.主色)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.容器色)
          .borderRadius(应用尺寸.圆角_进度条)
        Column()
          .width(`${d.average}%`)
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.主色)
          .borderRadius(应用尺寸.圆角_进度条)
      }
      .width('100%')
      .height(应用尺寸.进度条高度)
    }
    .width('100%')
  }
}
