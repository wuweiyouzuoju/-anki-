// SPDX-License-Identifier: AGPL-3.0-or-later

// 真实保留率卡：渲染 GraphsView.trueRetention 为 6 个时间窗口的通过率表格。
// 每个窗口展示 young/mature 两组的 通过/未通过 计数与通过率。

import type { TrueRetention, TrueRetentionStats } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 真实保留率卡 {
  @Prop 保留率数据: TrueRetentionStats | null = null;
  // 年轻卡/成熟卡通过率统一用主题主色
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';

  private 取率(通过: number, 未通过: number): string {
    const 总: number = 通过 + 未通过;
    if (总 === 0) return '—';
    return `${Math.round(通过 / 总 * 100)}%`;
  }

  @Builder
  private 保留率行(标题: Resource, 数据: TrueRetention | null) {
    if (数据 === null) {
      Row() {
        Text(标题)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text('—')
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
    } else {
      Column({ space: 应用尺寸.间距_2 }) {
        Row() {
          Text(标题)
            .fontSize(应用尺寸.字号_正文_小)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .width('100%')

        Row({ space: 应用尺寸.间距_8 }) {
          // 年轻卡
          Column({ space: 应用尺寸.间距_2 }) {
            Row({ space: 应用尺寸.间距_4 }) {
              Text($r('app.string.stats_retention_young'))
                .fontSize(应用尺寸.字号_说明)
                .fontColor($r('app.color.text_secondary'))
              Text(this.取率(数据.youngPassed, 数据.youngFailed))
                .fontSize(应用尺寸.字号_正文)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.主色)
            }
            Text(`${数据.youngPassed} / ${数据.youngPassed + 数据.youngFailed}`)
              .fontSize(应用尺寸.字号_说明)
              .fontColor($r('app.color.text_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // 成熟卡
          Column({ space: 应用尺寸.间距_2 }) {
            Row({ space: 应用尺寸.间距_4 }) {
              Text($r('app.string.stats_retention_mature'))
                .fontSize(应用尺寸.字号_说明)
                .fontColor($r('app.color.text_secondary'))
              Text(this.取率(数据.maturePassed, 数据.matureFailed))
                .fontSize(应用尺寸.字号_正文)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.主色)
            }
            Text(`${数据.maturePassed} / ${数据.maturePassed + 数据.matureFailed}`)
              .fontSize(应用尺寸.字号_说明)
              .fontColor($r('app.color.text_tertiary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('app.color.border_subtle') } })
    }
  }

  build() {
    Column() {
      if (this.保留率数据 === null) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染保留率表(this.保留率数据 as TrueRetentionStats)
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染保留率表(d: TrueRetentionStats) {
    Column({ space: 应用尺寸.间距_3 }) {
      this.保留率行($r('app.string.stats_section_today'), d.today)
      this.保留率行($r('app.string.stats_period_yesterday'), d.yesterday)
      this.保留率行($r('app.string.stats_period_week'), d.week)
      this.保留率行($r('app.string.stats_period_month'), d.month)
      this.保留率行($r('app.string.stats_period_year'), d.year)
      this.保留率行($r('app.string.stats_period_all'), d.allTime)
    }
    .width('100%')
  }
}
