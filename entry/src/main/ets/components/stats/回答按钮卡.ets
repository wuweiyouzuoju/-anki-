// SPDX-License-Identifier: AGPL-3.0-or-later

// 回答按钮卡：渲染 GraphsResponse.buttons 为分组柱状图（对齐 Anki ButtonsGraph）。
// 3 组（学习中/年轻/成熟）× 4 柱（评分按钮 1-4），柱色按按钮号取 RdYlGn：
// 重来红 / 困难黄 / 良好浅绿 / 简单深绿。默认时间范围为近 1 年（与 Anki 一致）。
// Invariants: build 单根 Column；按钮数组长度不足 4 时按 0 处理。

import type { Buttons, ButtonCounts } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 取按钮色 } from '../../model/统计色板';
import { 范围切换条 } from './范围切换条';

@Component
export struct 回答按钮卡 {
  @Prop @Watch('更新缓存') 按钮数据: Buttons | null = null;
  @Prop 是否显示全部: boolean = false;
  @State private 范围索引: number = 2;
  @State private 组缓存: ButtonCounts[] = [];
  private readonly 柱区高度: number = 110;
  private readonly 范围标签: Resource[] = [
    $r('app.string.stats_hours_range_1m'),
    $r('app.string.stats_hours_range_3m'),
    $r('app.string.stats_hours_range_1y'),
    $r('app.string.stats_hours_range_all')
  ];

  aboutToAppear(): void {
    this.更新缓存();
  }

  更新缓存(): void {
    if (this.按钮数据 === null) {
      this.组缓存 = [];
      return;
    }
    let 选中: ButtonCounts | null = null;
    switch (this.范围索引) {
      case 0: 选中 = this.按钮数据.oneMonth; break;
      case 1: 选中 = this.按钮数据.threeMonths; break;
      case 2: 选中 = this.按钮数据.oneYear; break;
      default: 选中 = this.按钮数据.allTime; break;
    }
    this.组缓存 = 选中 === null ? [] : [选中];
  }

  private 取按钮计数(组: ButtonCounts, 类别: number, 按钮: number): number {
    let 数组: number[] = [];
    if (类别 === 0) {
      数组 = 组.learning;
    } else if (类别 === 1) {
      数组 = 组.young;
    } else {
      数组 = 组.mature;
    }
    if (按钮 < 数组.length) {
      return 数组[按钮];
    }
    return 0;
  }

  private 取最大值(): number {
    let 最大: number = 0;
    for (let 组索引 = 0; 组索引 < this.组缓存.length; 组索引++) {
      for (let 类别 = 0; 类别 < 3; 类别++) {
        for (let 按钮 = 0; 按钮 < 4; 按钮++) {
          const 值: number = this.取按钮计数(this.组缓存[组索引], 类别, 按钮);
          if (值 > 最大) {
            最大 = 值;
          }
        }
      }
    }
    return 最大 === 0 ? 1 : 最大;
  }

  /** 组正确率（%）：按钮 2-4 计正确（Anki 手册 correct reviews）；无数据返回 -1 */
  private 取组正确率(组: ButtonCounts, 类别: number): number {
    let 正确: number = 0;
    let 总: number = 0;
    for (let 按钮 = 0; 按钮 < 4; 按钮++) {
      const 值: number = this.取按钮计数(组, 类别, 按钮);
      总 += 值;
      if (按钮 > 0) {
        正确 += 值;
      }
    }
    if (总 <= 0) {
      return -1;
    }
    return 正确 / 总 * 100;
  }

  private 数据为空(): boolean {
    return this.组缓存.length === 0 || this.取总计() === 0;
  }

  private 取总计(): number {
    let 总计: number = 0;
    for (let 组索引 = 0; 组索引 < this.组缓存.length; 组索引++) {
      for (let 类别 = 0; 类别 < 3; 类别++) {
        for (let 按钮 = 0; 按钮 < 4; 按钮++) {
          总计 += this.取按钮计数(this.组缓存[组索引], 类别, 按钮);
        }
      }
    }
    return 总计;
  }

  build() {
    Column({ space: 应用尺寸.间距_8 }) {
      范围切换条({
        当前索引: this.范围索引,
        标签集: this.是否显示全部 ? this.范围标签 : this.范围标签.slice(0, 3),
        onRangeChange: (): void => {
          this.更新缓存();
        }
      })

      if (this.数据为空()) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染按钮图(this.组缓存[0], this.取最大值())
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染按钮图(组: ButtonCounts, 最大值: number) {
    Row({ space: 应用尺寸.间距_16 }) {
      this.渲染按钮组(组, 0, $r('app.string.stats_cards_learn'), 最大值)
      this.渲染按钮组(组, 1, $r('app.string.stats_cards_young'), 最大值)
      this.渲染按钮组(组, 2, $r('app.string.stats_cards_mature'), 最大值)
    }
    .width('100%')
  }

  @Builder
  private 渲染按钮组(组: ButtonCounts, 类别: number, 标签: Resource, 最大值: number) {
    Column({ space: 应用尺寸.间距_4 }) {
      Row({ space: 应用尺寸.间距_7 }) {
        ForEach([0, 1, 2, 3], (按钮: number) => {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('100%')
              .height(`${this.取按钮计数(组, 类别, 按钮) / 最大值 * 100}%`)
              .backgroundColor(取按钮色(按钮 + 1))
              .opacity(0.8)
              .borderRadius(2)
          }
          .layoutWeight(1)
          .height('100%')
        }, (按钮: number) => `${按钮}`)
      }
      .width('100%')
      .height(this.柱区高度)
      .alignItems(VerticalAlign.Bottom)

      Text(标签)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
      // 各类正确率（Anki 手册：percentage of correct reviews for each type of card）
      if (this.取组正确率(组, 类别) >= 0) {
        Text($r('app.string.stats_buttons_correct_rate', `${this.取组正确率(组, 类别).toFixed(0)}%`))
          .fontSize(应用尺寸.字号_说明_小)
          .fontColor($r('app.color.text_tertiary'))
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}
