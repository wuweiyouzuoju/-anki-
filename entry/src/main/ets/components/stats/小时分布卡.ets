// SPDX-License-Identifier: AGPL-3.0-or-later

// 小时分布卡：渲染 GraphsView.hours 为 24 小时垂直柱状图。
// 支持 4 个时间段切换（1月/3月/1年/全部）。

import type { Hours, HourBucket } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

@Component
export struct 小时分布卡 {
  @Prop 小时数据: Hours | null = null;
  @State 时间段索引: number = 0;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';
  private readonly 图表高度: number = 100;

  private readonly 时间段标签: Resource[] = [
    $r('app.string.stats_hours_range_1m'),
    $r('app.string.stats_hours_range_3m'),
    $r('app.string.stats_hours_range_1y'),
    $r('app.string.stats_hours_range_all')
  ];

  private 取数据(): HourBucket[] {
    if (this.小时数据 === null) {
      return [];
    }
    switch (this.时间段索引) {
      case 0: return this.小时数据.oneMonth;
      case 1: return this.小时数据.threeMonths;
      case 2: return this.小时数据.oneYear;
      case 3: return this.小时数据.allTime;
      default: return this.小时数据.oneMonth;
    }
  }

  private 取最大值(数据: HourBucket[]): number {
    let 最大: number = 0;
    for (let i = 0; i < 数据.length; i++) {
      if (数据[i].total > 最大) {
        最大 = 数据[i].total;
      }
    }
    return 最大 === 0 ? 1 : 最大;
  }

  private 数据为空(): boolean {
    if (this.小时数据 === null) return true;
    return this.取数据().length === 0;
  }

  build() {
    Column() {
      if (this.数据为空()) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染小时分布(this.取数据(), this.取最大值(this.取数据()))
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染小时分布(数据: HourBucket[], 最大值: number) {
    Column({ space: 应用尺寸.间距_8 }) {
      // 时间段切换
      Row({ space: 应用尺寸.间距_4 }) {
        ForEach(this.时间段标签, (标签: Resource, 索引: number) => {
          Text(标签)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(索引 === this.时间段索引 ? this.主色 : $r('app.color.text_secondary'))
            .fontWeight(索引 === this.时间段索引 ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8,
              top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
            .backgroundColor(索引 === this.时间段索引 ? this.容器色 : Color.Transparent)
            .borderRadius(应用尺寸.圆角_进度条)
            .onClick(() => {
              this.时间段索引 = 索引;
            })
        }, (标签: Resource, 索引: number) => `${索引}`)
      }
      .width('100%')

      // 柱状图
      Row() {
        ForEach(数据, (桶: HourBucket, 索引: number) => {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('100%')
              .height(应用尺寸.进度条高度)
              .backgroundColor(this.容器色)
              .borderRadius(应用尺寸.圆角_进度条)
            Column()
              .width('100%')
              .height((桶.total / 最大值) * this.图表高度)
              .backgroundColor(this.主色)
              .borderRadius(应用尺寸.圆角_进度条)
          }
          .layoutWeight(1)
          .height(this.图表高度)
        }, (桶: HourBucket, 索引: number) => `${索引}`)
      }
      .width('100%')
      .height(this.图表高度)

      // 小时刻度
      Row() {
        Text('0')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Text('6')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('12')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('18')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('23')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')
    }
    .width('100%')
  }
}
