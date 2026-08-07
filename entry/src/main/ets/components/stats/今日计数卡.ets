// SPDX-License-Identifier: AGPL-3.0-or-later

// 今日计数卡：渲染 GraphsView.today 的统计指标网格。
// 用 2 列 Grid 展示已答/正确/学习/复习/重学/提前/成熟卡正确率/用时。

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

  @Builder
  private 指标格(标签: Resource, 数值: string) {
    Column({ space: 应用尺寸.间距_2 }) {
      Text(数值)
        .fontSize(应用尺寸.字号_指标)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(标签)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 应用尺寸.间距_8, bottom: 应用尺寸.间距_8 })
  }

  build() {
    Column() {
      if (this.今日数据 === null) {
        Text($r('app.string.stats_empty_section'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 应用尺寸.间距_16, bottom: 应用尺寸.间距_16 })
      } else {
        Grid() {
          GridItem() { this.指标格($r('app.string.stats_today_answered'), `${this.今日数据.answerCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_correct'), `${this.今日数据.correctCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_learn'), `${this.今日数据.learnCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_review'), `${this.今日数据.reviewCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_relearn'), `${this.今日数据.relearnCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_early'), `${this.今日数据.earlyReviewCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_mature_correct'), `${this.今日数据.matureCorrect}/${this.今日数据.matureCount}`) }
          GridItem() { this.指标格($r('app.string.stats_today_time'), this.格式化用时(this.今日数据.answerMillis)) }
        }
        .columnsTemplate('1fr 1fr')
        .width('100%')
      }
    }
    .width('100%')
  }
}
