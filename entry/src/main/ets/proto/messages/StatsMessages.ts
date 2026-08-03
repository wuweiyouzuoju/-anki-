// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID PROTO-MSG-STATS-001
// @名称 统计消息编解码
//
// @作用
// 编解码 anki.stats.proto 消息（Anki 26.05），仅提取首页热力图与记忆率所需字段：
// - GraphsRequest：search 固定为空（全库统计，与 rslib graph_data_for_search 的 all 分支一致）
// - GraphsView：今日计数 + 按日复习计数（热力图）+ 记忆率 + FSRS 标志
// 字段来源：third_party/anki/proto/anki/stats.proto
// 语义来源：rslib/src/stats/graphs/
//
// @输入
// 编码：days（统计天数）
// 解码：字节流
//
// @输出
// 编码：Uint8Array 字节
// 解码：GraphsView（today / retrievability / reviewCountsByDaysAgo / fsrs）
//
// @业务规则
// reviews.count 的键为「距今天数」，0=今天，1=昨天，与 rslib reviews.rs 分桶一致。
// retrievability.average 为 0-100 百分制，仅当存在带 FSRS 记忆状态的卡片时非零。
// ReviewCountsAndTimes 的 time 字段（field 2）首页不用，跳过。
// map<int32, Reviews> 的 key 是 int32 varint，负数按补码解释。
//
// @副作用
// 无
// ========================================================

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface TodayCounts {
  answerCount: number;
  answerMillis: number;
  correctCount: number;
  matureCorrect: number;
  matureCount: number;
  learnCount: number;
  reviewCount: number;
  relearnCount: number;
  earlyReviewCount: number;
}

export interface RetrievabilitySummary {
  average: number;
  sumByCard: number;
  sumByNote: number;
}

/** 单日内按卡片阶段拆分的复习计数（ReviewCountsAndTimes.Reviews）。 */
export interface ReviewKindCounts {
  learn: number;
  relearn: number;
  young: number;
  mature: number;
  filtered: number;
}

export interface GraphsView {
  today: TodayCounts | null;
  retrievability: RetrievabilitySummary | null;
  /** 按日复习计数：键为距今天数（0=今天，1=昨天……），与 rslib reviews.rs 分桶一致。 */
  reviewCountsByDaysAgo: Map<number, ReviewKindCounts> | null;
  fsrs: boolean;
}

/** GraphsRequest：search 固定为空（全库统计，与 rslib graph_data_for_search 的 all 分支一致）。 */
export function encodeGraphsRequest(days: number): Uint8Array {
  const w = new 协议写入器();
  if (days > 0) {
    w.写入变长整数(2, days);
  }
  return w.转为字节();
}

function decodeToday(bytes: Uint8Array): TodayCounts {
  const r = new 协议读取器(bytes);
  const out: TodayCounts = {
    answerCount: 0,
    answerMillis: 0,
    correctCount: 0,
    matureCorrect: 0,
    matureCount: 0,
    learnCount: 0,
    reviewCount: 0,
    relearnCount: 0,
    earlyReviewCount: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.answerCount = r.读取变长整数();
        break;
      case 2:
        out.answerMillis = r.读取变长整数();
        break;
      case 3:
        out.correctCount = r.读取变长整数();
        break;
      case 4:
        out.matureCorrect = r.读取变长整数();
        break;
      case 5:
        out.matureCount = r.读取变长整数();
        break;
      case 6:
        out.learnCount = r.读取变长整数();
        break;
      case 7:
        out.reviewCount = r.读取变长整数();
        break;
      case 8:
        out.relearnCount = r.读取变长整数();
        break;
      case 9:
        out.earlyReviewCount = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function decodeRetrievability(bytes: Uint8Array): RetrievabilitySummary {
  const r = new 协议读取器(bytes);
  const out: RetrievabilitySummary = { average: 0, sumByCard: 0, sumByNote: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        r.跳过字段(tag.线类型);
        break;
      case 2:
        out.average = r.读取浮点();
        break;
      case 3:
        out.sumByCard = r.读取浮点();
        break;
      case 4:
        out.sumByNote = r.读取浮点();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function decodeReviews(bytes: Uint8Array): ReviewKindCounts {
  const r = new 协议读取器(bytes);
  const out: ReviewKindCounts = { learn: 0, relearn: 0, young: 0, mature: 0, filtered: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.learn = r.读取变长整数();
        break;
      case 2:
        out.relearn = r.读取变长整数();
        break;
      case 3:
        out.young = r.读取变长整数();
        break;
      case 4:
        out.mature = r.读取变长整数();
        break;
      case 5:
        out.filtered = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

/** map<int32, Reviews> 条目：field1=key（int32 varint，负数按补码），field2=value 子消息。 */
function decodeReviewCountEntry(bytes: Uint8Array, out: Map<number, ReviewKindCounts>): void {
  const r = new 协议读取器(bytes);
  let daysAgo: number = 0;
  let counts: ReviewKindCounts | null = null;
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        daysAgo = Number(BigInt.asIntN(32, r.读取大变长整数()));
        break;
      case 2:
        counts = decodeReviews(r.读取字节());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  if (counts !== null) {
    out.set(daysAgo, counts);
  }
}

function decodeReviewCountsAndTimes(bytes: Uint8Array): Map<number, ReviewKindCounts> {
  const r = new 协议读取器(bytes);
  const out: Map<number, ReviewKindCounts> = new Map<number, ReviewKindCounts>();
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        decodeReviewCountEntry(r.读取字节(), out);
        break;
      default:
        r.跳过字段(tag.线类型); // field2 time 图首页不用，跳过
    }
  }
  return out;
}

export function decodeGraphsResponse(bytes: Uint8Array): GraphsView {
  const r = new 协议读取器(bytes);
  const out: GraphsView = {
    today: null,
    retrievability: null,
    reviewCountsByDaysAgo: null,
    fsrs: false
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 4:
        out.today = decodeToday(r.读取字节());
        break;
      case 9:
        out.reviewCountsByDaysAgo = decodeReviewCountsAndTimes(r.读取字节());
        break;
      case 12:
        out.retrievability = decodeRetrievability(r.读取字节());
        break;
      case 13:
        out.fsrs = r.读取布尔();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}
