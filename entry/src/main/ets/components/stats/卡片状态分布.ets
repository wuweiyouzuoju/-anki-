// SPDX-License-Identifier: AGPL-3.0-or-later

// 卡片状态分布：渲染 GraphsView.cardCounts 为水平条形图。
// separateInactive=true 时用 excludingInactive（暂停/埋藏单独计数），
// false 时用 includingInactive（暂停/埋藏为 0）。

import type { CardCounts, CardCountsBreakdown } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';

interface 卡片状态项 {
  标签: Resource;
  数值: number;
  色键: string;
}

@Component
export struct 卡片状态分布 {
  @Prop 卡片计数: CardCounts | null = null;
  @Prop 分离暂停: boolean = false;
  @StorageProp(颜色键.动作主色) private 主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 容器色: string = '#E8EEFC';

  private 取数据(): CardCountsBreakdown | null {
    if (this.卡片计数 === null) return null;
    if (this.分离暂停) {
      return this.卡片计数.excludingInactive ?? this.卡片计数.includingInactive;
    }
    return this.卡片计数.includingInactive ?? this.卡片计数.excludingInactive;
  }

  private 取总数(数据: CardCountsBreakdown): number {
    return 数据.newCards + 数据.learn + 数据.relearn + 数据.young + 数据.mature
      + 数据.suspended + 数据.buried;
  }

  private 取色(项: 卡片状态项): string {
    // 所有卡片状态统一用主题色，靠浅色铺底+深色填充的比例长度区分
    // 暂停/埋藏是特殊状态用中性灰
    switch (项.色键) {
      case 'suspended': return '#999999';
      case 'buried': return '#CCCCCC';
      default: return this.主色;
    }
  }

  @Builder
  private 状态行(项: 卡片状态项, 比例: number, 总数: number) {
    Row({ space: 应用尺寸.间距_8 }) {
      Text(项.标签)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width(60)
      Stack({ alignContent: Alignment.Start }) {
        // 背景槽
        Column()
          .width('100%')
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.容器色)
          .borderRadius(应用尺寸.圆角_进度条)
        // 数据条
        Column()
          .width(`${比例 * 100}%`)
          .height(应用尺寸.进度条高度)
          .backgroundColor(this.取色(项))
          .borderRadius(应用尺寸.圆角_进度条)
      }
      .layoutWeight(1)
      .height(应用尺寸.进度条高度)
      Text(`${项.数值}`)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_primary'))
        .width(40)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.取数据() === null || this.取总数(this.取数据() as CardCountsBreakdown) === 0) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染分布(this.取数据() as CardCountsBreakdown, this.取总数(this.取数据() as CardCountsBreakdown))
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染分布(数据: CardCountsBreakdown, 总数: number) {
    Column({ space: 应用尺寸.间距_5 }) {
      this.状态行({ 标签: $r('app.string.stats_cards_new'), 数值: 数据.newCards, 色键: 'new' }, 数据.newCards / 总数, 总数)
      this.状态行({ 标签: $r('app.string.stats_cards_learn'), 数值: 数据.learn, 色键: 'learn' }, 数据.learn / 总数, 总数)
      this.状态行({ 标签: $r('app.string.stats_cards_relearn'), 数值: 数据.relearn, 色键: 'relearn' }, 数据.relearn / 总数, 总数)
      this.状态行({ 标签: $r('app.string.stats_cards_young'), 数值: 数据.young, 色键: 'young' }, 数据.young / 总数, 总数)
      this.状态行({ 标签: $r('app.string.stats_cards_mature'), 数值: 数据.mature, 色键: 'mature' }, 数据.mature / 总数, 总数)
      if (数据.suspended > 0) {
        this.状态行({ 标签: $r('app.string.stats_cards_suspended'), 数值: 数据.suspended, 色键: 'suspended' }, 数据.suspended / 总数, 总数)
      }
      if (数据.buried > 0) {
        this.状态行({ 标签: $r('app.string.stats_cards_buried'), 数值: 数据.buried, 色键: 'buried' }, 数据.buried / 总数, 总数)
      }
      Text($r('app.string.stats_cards_total', 总数))
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.End)
        .padding({ top: 应用尺寸.间距_4 })
    }
    .width('100%')
  }
}
