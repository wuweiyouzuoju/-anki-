// SPDX-License-Identifier: AGPL-3.0-or-later

import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import type { GraphsView, RetrievabilitySummary, ReviewKindCounts } from '../proto/messages/StatsMessages';
import type { 牌组汇总, 牌组色调, 主页快照, 记忆表现汇总 } from './主页模型';
import { 平铺牌组树 } from './牌组层级';

function 统计牌组树节点数(节点: DeckTreeNode): number {
  let 总数: number = 节点.children.length;
  for (const 子节点 of 节点.children) {
    总数 += 统计牌组树节点数(子节点);
  }
  return 总数;
}

function 补零两位(值: number): string {
  return 值 < 10 ? `0${值}` : 值.toString();
}

function 日历日期键(日期: Date): string {
  return `${日期.getFullYear()}-${补零两位(日期.getMonth() + 1)}-${补零两位(日期.getDate())}`;
}

function 转为按日期复习计数(图表数据: GraphsView | null, 当前时刻: Date): Map<string, number> {
  const 输出: Map<string, number> = new Map<string, number>();
  if (图表数据 === null || 图表数据.reviewCountsByDaysAgo === null) {
    return 输出;
  }
  图表数据.reviewCountsByDaysAgo.forEach((各阶段计数: ReviewKindCounts, 天偏移: number) => {
    const 合计: number =
      各阶段计数.learn + 各阶段计数.relearn + 各阶段计数.young + 各阶段计数.mature + 各阶段计数.filtered;
    if (合计 <= 0) {
      return;
    }
    const 日期: Date = new Date(当前时刻.getFullYear(), 当前时刻.getMonth(), 当前时刻.getDate() + 天偏移);
    输出.set(日历日期键(日期), 合计);
  });
  return 输出;
}

function 转为记忆表现汇总(图表数据: GraphsView | null): 记忆表现汇总 {
  if (图表数据 === null) {
    return {
      state: 'load_error',
      todayAgainRate: 0, todayAnsweredCount: 0,
      matureCorrectRate: 0, hasMatureData: false,
      averageRetrievability: 0, hasRetrievability: false
    };
  }
  const 可提取率: RetrievabilitySummary | null = 图表数据.retrievability;
  const 有可提取率: boolean = 图表数据.fsrs
    && 可提取率 !== null && 可提取率.average > 0;
  const 全库平均可提取率: number = 有可提取率
    ? 可提取率!.average / 100 : 0;

  const 今日数据 = 图表数据.today;
  if (今日数据 === null || 今日数据.answerCount <= 0) {
    return {
      state: 'today_empty',
      todayAgainRate: 0, todayAnsweredCount: 0,
      matureCorrectRate: 0, hasMatureData: false,
      averageRetrievability: 全库平均可提取率,
      hasRetrievability: 有可提取率
    };
  }
  const 不会次数: number = 今日数据.answerCount - 今日数据.correctCount;
  const 今日不会率: number = 不会次数 / 今日数据.answerCount;
  const 有熟练卡数据: boolean = 今日数据.matureCount > 0;
  const 熟练卡正确率: number = 有熟练卡数据
    ? 今日数据.matureCorrect / 今日数据.matureCount : 0;
  return {
    state: 'today_answered',
    todayAgainRate: 今日不会率,
    todayAnsweredCount: 今日数据.answerCount,
    matureCorrectRate: 熟练卡正确率,
    hasMatureData: 有熟练卡数据,
    averageRetrievability: 全库平均可提取率,
    hasRetrievability: 有可提取率
  };
}

export function 构建主页快照(根节点: DeckTreeNode,
  图表数据: GraphsView | null = null, 当前时刻: Date = new Date(),
  色调覆盖: Map<string, 牌组色调> | null = null,
  别名覆盖: Map<string, string> | null = null,
  顺序覆盖: Map<string, string[]> | null = null,
  背景图覆盖: Map<string, string> | null = null): 主页快照 {
  const 牌组列表: 牌组汇总[] = 平铺牌组树(根节点, 色调覆盖, 别名覆盖,
    顺序覆盖, 背景图覆盖);
  let 总待办数: number = 0;
  for (const 子节点 of 根节点.children) {
    总待办数 += 子节点.newCount + 子节点.learnCount + 子节点.reviewCount;
  }
  return {
    today: {
      completedCount: 转为今日完成数(图表数据),
      pendingCount: 总待办数,
      deckCount: 统计牌组树节点数(根节点)
    },
    decks: 牌组列表,
    reviewCountsByDate: 转为按日期复习计数(图表数据, 当前时刻),
    memory: 转为记忆表现汇总(图表数据)
  };
}

function 转为今日完成数(图表数据: GraphsView | null): number {
  if (图表数据 === null || 图表数据.today === null) {
    return 0;
  }
  return 图表数据.today.answerCount;
}
