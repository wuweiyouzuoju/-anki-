// SPDX-License-Identifier: AGPL-3.0-or-later

// 小时分布卡：渲染 GraphsView.hours 为 24 小时垂直柱状图。
// 支持 4 个时间段切换（1月/3月/1年/全部）；窗口选择持久化并由统计页管理，
// 首页卡片与桌面卡片跟随同一窗口，保证三处口径一致。

import type { Hours, HourBucket } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';
import { 取小时柱色 } from '../../model/统计色板';
import { 取轴域 } from '../../model/统计分箱';
import type { 轴域 } from '../../model/统计分箱';
import { 纵轴刻度, 右轴百分比, 纵轴宽, 右轴宽 } from './图表轴';

@Component
export struct 小时分布卡 {
  @Prop 小时数据: Hours | null = null;
  @Link 时间段索引: number;
  /** 是否深色主题（正确率面积叠加色对齐 Anki CumulativeOverlay 深浅两套） */
  @Prop 是否深色: boolean = false;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';
  /** 图区实际宽度（onAreaChange 更新）：正确率面积路径点坐标用 */
  @State private 图宽: number = 320;
  private readonly 图表高度: number = 100;
  private onRangeChange?: (索引: number) => void;

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

  /** Y 轴域（上限与刻度绑定产出，柱高归一化用 域.上限） */
  private 取轴(数据: HourBucket[]): 轴域 {
    return 取轴域(this.取峰值(数据), 4);
  }

  /** 数据峰值（柱色归一化用：Anki Blues 按峰值取色，与轴上限无关） */
  private 取峰值(数据: HourBucket[]): number {
    let 最大: number = 0;
    for (let i = 0; i < 数据.length; i++) {
      if (数据[i].total > 最大) {
        最大 = 数据[i].total;
      }
    }
    return 最大 === 0 ? 1 : 最大;
  }

  /** 正确率面积路径（对齐 Anki HourGraph 的 cumulative-overlay）。
   *  Anki 用 d3 area + curveBasis：从图底填充到正确率线（顶部=100%），
   *  .defined(total>0) 使无数据小时断开为多段。此处用直线段近似曲线，
   *  每段连续有数据的小时生成一个「底部→各点→底部」闭合子路径。 */
  private 取正确率面积路径(数据: HourBucket[]): string {
    let 路径: string = '';
    let 段起: number = -1;
    const 收尾 = (止: number): void => {
      if (段起 < 0 || 止 <= 段起) {
        return;
      }
      const 底: number = this.图表高度;
      路径 += ` M ${( (段起 + 0.5) / 24 * this.图宽).toFixed(1)} ${底}`;
      for (let i = 段起; i <= 止; i++) {
        const x: number = (i + 0.5) / 24 * this.图宽;
        const y: number = (1 - 数据[i].correct / 数据[i].total) * this.图表高度;
        路径 += ` L ${x.toFixed(1)} ${y.toFixed(1)}`;
      }
      路径 += ` L ${((止 + 0.5) / 24 * this.图宽).toFixed(1)} ${底} Z`;
    };
    for (let i = 0; i < 数据.length && i < 24; i++) {
      if (数据[i].total > 0) {
        if (段起 < 0) {
          段起 = i;
        }
      } else if (段起 >= 0) {
        收尾(i - 1);
        段起 = -1;
      }
    }
    收尾(Math.min(数据.length, 24) - 1);
    return 路径.trim();
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
        this.渲染小时分布(this.取数据(), this.取轴(this.取数据()))
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染小时分布(数据: HourBucket[], 域: 轴域) {
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
              if (this.onRangeChange !== undefined) {
                this.onRangeChange(索引);
              }
            })
        }, (标签: Resource, 索引: number) => `${索引}`)
      }
      .width('100%')

      // 柱状图 + 正确率面积叠加 + 右轴百分比（Anki HourGraph 三轴设计：
      // 左轴=复习次数、右轴 y2=正确率百分比 [0,25,50,75,100]%、底轴=小时；
      // 柱=复习数量，面积=correct/total 正确率对着右轴读数）。
      // 柱色对齐 Anki：Blues(0.1+0.7×归一化计数)，无复习浅蓝、峰值深蓝；
      // 面积样式对齐 Anki CumulativeOverlay：极淡填充+描边（浅色黑 0.03/0.08，深色白 0.08/黑 0.18）。
      Row() {
        纵轴刻度({
          刻度: 域.刻度,
          高度: this.图表高度
        })
        Stack({ alignContent: Alignment.TopStart }) {
          Row() {
            ForEach(数据, (桶: HourBucket, 索引: number) => {
              Stack({ alignContent: Alignment.Bottom }) {
                Column()
                  .width('70%')
                  .height((桶.total / 域.上限) * this.图表高度)
                  .backgroundColor(取小时柱色(桶.total / this.取峰值(数据)))
                  .borderRadius(1)
              }
              .layoutWeight(1)
              .height(this.图表高度)
            }, (桶: HourBucket, 索引: number) => `${索引}`)
          }
          .width('100%')
          .height(this.图表高度)

          if (this.取正确率面积路径(数据) !== '') {
            Path()
              .commands(this.取正确率面积路径(数据))
              .fill(this.是否深色 ? '#ffffff' : '#000000')
              .fillOpacity(this.是否深色 ? 0.08 : 0.03)
              .stroke('#000000')
              .strokeOpacity(this.是否深色 ? 0.18 : 0.08)
              .strokeWidth(1)
              .width('100%')
              .height(this.图表高度)
          }
        }
        .layoutWeight(1)
        .height(this.图表高度)
        .onAreaChange((_旧: Area, 新: Area): void => {
          const 宽: Length = 新.width;
          if (typeof 宽 === 'number') {
            this.图宽 = 宽;
          }
        })

        // 右轴 y2：正确率百分比刻度（面积的读数轴，官方 axisRight(yArea)）
        右轴百分比({
          高度: this.图表高度
        })
      }
      .width('100%')

      // 小时刻度：五等分居中，五个数字中心落点 10%/30%/50%/70%/90%，间距严格相等
      Row() {
        Text('0')
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
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
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 纵轴宽, right: 右轴宽 })
    }
    .width('100%')
  }
}
