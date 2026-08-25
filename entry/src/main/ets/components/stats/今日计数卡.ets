// SPDX-License-Identifier: AGPL-3.0-or-later

// 今日计数卡：渲染 GraphsView.today 为 4 行文字列表（对齐 Anki TodayStats）。
// 行 1 今天学习了 N 张，用时 X（Y 秒/张）；行 2 重来次数 N (P%)；
// 行 3 学习/复习/重学/过滤 计数；行 4 成熟卡正确率（无成熟卡时提示）。
// Invariants: build 单根 Column；未答题时仅显示"今天还没有学习卡片"一行。

import { common } from '@kit.AbilityKit';
import type { TodayCounts } from '../../proto/messages/StatsMessages';
import { 应用尺寸 } from '../../utils/应用尺寸';

@Component
export struct 今日计数卡 {
  @Prop 今日数据: TodayCounts | null = null;

  private 取能力上下文(): common.UIAbilityContext | null {
    const ctx: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return ctx === undefined ? null : ctx;
  }

  private 格式化用时(毫秒: number): string {
    const 总秒: number = Math.floor(毫秒 / 1000);
    if (总秒 < 1) return '0s';
    const 分钟: number = Math.floor(总秒 / 60);
    const 秒: number = 总秒 % 60;
    if (分钟 < 1) return `${秒}s`;
    if (分钟 < 60) {
      const ctx = this.取能力上下文();
      if (ctx !== null) {
        return ctx.resourceManager.getStringSync($r('app.string.stats_time_format').id, 分钟, 秒);
      }
      return `${分钟}m${秒}s`;
    }
    const 小时: number = Math.floor(分钟 / 60);
    const 余分: number = 分钟 % 60;
    const ctx = this.取能力上下文();
    if (ctx !== null) {
      return ctx.resourceManager.getStringSync($r('app.string.stats_time_format_hour').id, 小时, 余分);
    }
    return `${小时}h${余分}m`;
  }

  /** 每张卡平均用时（秒，1 位小数；Anki secsPerCard） */
  private 取每卡秒(数据: TodayCounts): string {
    if (数据.answerCount <= 0) {
      return '0';
    }
    return (数据.answerMillis / 1000 / 数据.answerCount).toFixed(1);
  }

  /** 重来次数 = 已答 - 正确（Anki againCount） */
  private 取重来次数(数据: TodayCounts): number {
    return Math.max(0, 数据.answerCount - 数据.correctCount);
  }

  private 取重来百分比(数据: TodayCounts): string {
    if (数据.answerCount <= 0) {
      return '0%';
    }
    return `${(this.取重来次数(数据) / 数据.answerCount * 100).toFixed(2)}%`;
  }

  private 取成熟正确率(数据: TodayCounts): string {
    if (数据.matureCount <= 0) {
      return '0%';
    }
    return `${(数据.matureCorrect / 数据.matureCount * 100).toFixed(2)}%`;
  }

  build() {
    Column() {
      if (this.今日数据 === null || this.今日数据.answerCount === 0) {
        Text($r('app.string.stats_today_no_cards'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        this.渲染今日(this.今日数据 as TodayCounts)
      }
    }
    .width('100%')
  }

  @Builder
  private 渲染今日(d: TodayCounts) {
    Column({ space: 应用尺寸.间距_10 }) {
      Text($r('app.string.stats_today_studied', d.answerCount,
        this.格式化用时(d.answerMillis), this.取每卡秒(d)))
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text($r('app.string.stats_today_again', this.取重来次数(d), this.取重来百分比(d)))
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text($r('app.string.stats_today_types', d.learnCount, d.reviewCount, d.relearnCount, d.earlyReviewCount))
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
      if (d.matureCount > 0) {
        Text($r('app.string.stats_today_mature_line', d.matureCorrect, d.matureCount, this.取成熟正确率(d)))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        Text($r('app.string.stats_today_no_mature'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }
}
