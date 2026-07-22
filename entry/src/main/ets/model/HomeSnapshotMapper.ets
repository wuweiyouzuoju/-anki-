// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 牌组树 → 主页快照映射（纯函数，无 UI/后端依赖，可单测）。
// 数据语义（third_party/anki/rslib/src/decks/tree.rs）：
// - 根节点为占位（deckId=0、name=''），真实牌组在 children；
// - 节点 name 为末级名（顶层节点即完整牌组名）；
// - 节点 new/learn/review 计数已按日限裁剪，且含全部子节点合计。
// 月历热力/记忆率语义（third_party/anki/rslib/src/stats/graphs/）：
// - reviews.count 键为相对今天的 day offset（0=今天、-1=昨天、-2=前天…，
//   见 reviews.rs `(elapsed_secs_since(next_day_start) / 86_400) as i32`）；
// - retrievability.average 为 0-100 百分制，仅 FSRS 开启且有 memory_state 卡片时非零。

import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import type { GraphsView, RetrievabilitySummary, ReviewKindCounts } from '../proto/messages/StatsMessages';
import type { DeckSummary, DeckTone, HomeSnapshot, MemorySummary } from './HomeModels';
import { flattenDeckTree } from './DeckHierarchy';

function countTreeDecks(node: DeckTreeNode): number {
  let total: number = node.children.length;
  for (const child of node.children) {
    total += countTreeDecks(child);
  }
  return total;
}

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : value.toString();
}

/** 与 CalendarModels.dateKey 同一格式：YYYY-MM-DD（本地时区）。 */
function calendarDateKey(date: Date): string {
  return `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}`;
}

/** day offset（0=今天、-1=昨天…） → 本地日历日期的复习计数；各阶段（新学/重学/年轻/熟练/筛选）求和，0 记为无热力。 */
function toReviewCountsByDate(graphs: GraphsView | null, now: Date): Map<string, number> {
  const out: Map<string, number> = new Map<string, number>();
  if (graphs === null || graphs.reviewCountsByDaysAgo === null) {
    return out;
  }
  graphs.reviewCountsByDaysAgo.forEach((counts: ReviewKindCounts, dayOffset: number) => {
    const total: number =
      counts.learn + counts.relearn + counts.young + counts.mature + counts.filtered;
    if (total <= 0) {
      return;
    }
    // Anki 返回的 dayOffset 是「相对今天的偏移」（0=今天、负数=过去），
    // 直接相加即可得到对应日历日（ getDate() + 0 = 今天、getDate() + (-1) = 昨天）。
    const date: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset);
    out.set(calendarDateKey(date), total);
  });
  return out;
}

/** 主页第三张卡：B12-X 改造 2026-07-21（详见 decisions.md）。
 *
 *  旧口径:retrievability.average = 全库 FSRS 卡平均可提取率。mature 卡占比高时拉到 95%+，
 *  掩盖"今天答不会的卡很多"的真实状态——用户主观感受与数字严重脱节。
 *
 *  新口径:主指标改用 today.againRate = (answerCount - correctCount) / answerCount
 *  （Anki Desktop today.ts 同款算法，rslib/src/stats/graphs/today.rs 提供数据）。
 *  全库平均可提取率保留为副标题（仅在 FSRS 已开且有 memory_state 卡片时显示）。
 *
 *  state:
 *  - load_error: graphs 拉取失败（null）
 *  - today_empty: 今日 answerCount=0，提示去学习
 *  - today_answered: 今日已答卡，显示今日不会率 + 副指标
 *  - loading: 调用方传入的初始态（buildHomeSnapshot 不会返回此态）
 */
function toMemorySummary(graphs: GraphsView | null): MemorySummary {
  if (graphs === null) {
    return {
      state: 'load_error',
      todayAgainRate: 0, todayAnsweredCount: 0,
      matureCorrectRate: 0, hasMatureData: false,
      averageRetrievability: 0, hasRetrievability: false
    };
  }
  // 副指标2：全库平均可提取率（FSRS 已开且有 memory_state 卡片时才有意义）
  // 在 today_answered 与 today_empty 两种状态下都计算，让用户在还没学习时也能看全库参考。
  const retrievability: RetrievabilitySummary | null = graphs.retrievability;
  const hasRetrievability: boolean = graphs.fsrs
    && retrievability !== null && retrievability.average > 0;
  const averageRetrievability: number = hasRetrievability
    ? retrievability!.average / 100 : 0;

  const today = graphs.today;
  if (today === null || today.answerCount <= 0) {
    return {
      state: 'today_empty',
      todayAgainRate: 0, todayAnsweredCount: 0,
      matureCorrectRate: 0, hasMatureData: false,
      averageRetrievability: averageRetrievability,
      hasRetrievability: hasRetrievability
    };
  }
  // 主指标：今日不会率 = (answer - correct) / answer
  const againCount: number = today.answerCount - today.correctCount;
  const todayAgainRate: number = againCount / today.answerCount;
  // 副指标1：今日 mature 卡正确率（仅 matureCount>0 时有意义）
  const hasMatureData: boolean = today.matureCount > 0;
  const matureCorrectRate: number = hasMatureData
    ? today.matureCorrect / today.matureCount : 0;
  return {
    state: 'today_answered',
    todayAgainRate: todayAgainRate,
    todayAnsweredCount: today.answerCount,
    matureCorrectRate: matureCorrectRate,
    hasMatureData: hasMatureData,
    averageRetrievability: averageRetrievability,
    hasRetrievability: hasRetrievability
  };
}

/**
 * 主页列表按前序保留完整牌组树。父牌组计数直接沿用 Anki Core 的聚合计数，
 * 不从已平铺的子牌组重新求和。
 *
 * 今日完成（completedCount）来源：graphs.today.answerCount（Anki 后端 today.rs
 * 遍历 revlog 统计 learn+review+relearn+filtered，全库聚合、含全部子牌组学习）。
 * 旧实现用 CountsForDeckToday RPC 对顶层牌组求 new+review，既漏子牌组学习、
 * 又缺 learn/relearn 口径，已废弃。
 *
 * graphs 为 StatsService.getGraphs 结果（拉取失败传 null 时 completedCount/
 * 热力/记忆率均保持空态）；now 供测试锚定「今天」以校验热力日期映射。
 */
export function buildHomeSnapshot(root: DeckTreeNode,
  graphs: GraphsView | null = null, now: Date = new Date(),
  toneOverrides: Map<string, DeckTone> | null = null,
  displayNameOverrides: Map<string, string> | null = null,
  orderOverrides: Map<string, string[]> | null = null,
  backgroundImageOverrides: Map<string, string> | null = null): HomeSnapshot {
  const decks: DeckSummary[] = flattenDeckTree(root, toneOverrides, displayNameOverrides,
    orderOverrides, backgroundImageOverrides);
  let pending: number = 0;
  for (const child of root.children) {
    pending += child.newCount + child.learnCount + child.reviewCount;
  }
  return {
    today: {
      completedCount: toCompletedToday(graphs),
      pendingCount: pending,
      deckCount: countTreeDecks(root)
    },
    decks: decks,
    reviewCountsByDate: toReviewCountsByDate(graphs, now),
    memory: toMemorySummary(graphs)
  };
}

/** 今日完成 = graphs.today.answerCount（含 learn/review/relearn/filtered，全库聚合）；缺省为 0。 */
function toCompletedToday(graphs: GraphsView | null): number {
  if (graphs === null || graphs.today === null) {
    return 0;
  }
  return graphs.today.answerCount;
}
