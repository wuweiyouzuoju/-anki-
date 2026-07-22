// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.stats 轻量消息编解码：GraphsResponse 仅提取首页热力和记忆率所需的字段。
// 字段来源：third_party/anki/proto/anki/stats.proto（Anki 26.05）
// 语义来源：rslib/src/stats/graphs/（reviews.count 的键为「距今天数」，0=今天；
// retrievability.average 为 0-100 百分制，仅当存在带 FSRS 记忆状态的卡片时非零）。

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

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
  const w = new ProtoWriter();
  if (days > 0) {
    w.writeVarint(2, days);
  }
  return w.toBytes();
}

function decodeToday(bytes: Uint8Array): TodayCounts {
  const r = new ProtoReader(bytes);
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
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.answerCount = r.readVarint();
        break;
      case 2:
        out.answerMillis = r.readVarint();
        break;
      case 3:
        out.correctCount = r.readVarint();
        break;
      case 4:
        out.matureCorrect = r.readVarint();
        break;
      case 5:
        out.matureCount = r.readVarint();
        break;
      case 6:
        out.learnCount = r.readVarint();
        break;
      case 7:
        out.reviewCount = r.readVarint();
        break;
      case 8:
        out.relearnCount = r.readVarint();
        break;
      case 9:
        out.earlyReviewCount = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

function decodeRetrievability(bytes: Uint8Array): RetrievabilitySummary {
  const r = new ProtoReader(bytes);
  const out: RetrievabilitySummary = { average: 0, sumByCard: 0, sumByNote: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        r.skipField(tag.wireType);
        break;
      case 2:
        out.average = r.readFloat();
        break;
      case 3:
        out.sumByCard = r.readFloat();
        break;
      case 4:
        out.sumByNote = r.readFloat();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

function decodeReviews(bytes: Uint8Array): ReviewKindCounts {
  const r = new ProtoReader(bytes);
  const out: ReviewKindCounts = { learn: 0, relearn: 0, young: 0, mature: 0, filtered: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.learn = r.readVarint();
        break;
      case 2:
        out.relearn = r.readVarint();
        break;
      case 3:
        out.young = r.readVarint();
        break;
      case 4:
        out.mature = r.readVarint();
        break;
      case 5:
        out.filtered = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

/** map<int32, Reviews> 条目：field1=key（int32 varint，负数按补码），field2=value 子消息。 */
function decodeReviewCountEntry(bytes: Uint8Array, out: Map<number, ReviewKindCounts>): void {
  const r = new ProtoReader(bytes);
  let daysAgo: number = 0;
  let counts: ReviewKindCounts | null = null;
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        daysAgo = Number(BigInt.asIntN(32, r.readVarintBig()));
        break;
      case 2:
        counts = decodeReviews(r.readBytes());
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  if (counts !== null) {
    out.set(daysAgo, counts);
  }
}

function decodeReviewCountsAndTimes(bytes: Uint8Array): Map<number, ReviewKindCounts> {
  const r = new ProtoReader(bytes);
  const out: Map<number, ReviewKindCounts> = new Map<number, ReviewKindCounts>();
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        decodeReviewCountEntry(r.readBytes(), out);
        break;
      default:
        r.skipField(tag.wireType); // field2 time 图首页不用，跳过
    }
  }
  return out;
}

export function decodeGraphsResponse(bytes: Uint8Array): GraphsView {
  const r = new ProtoReader(bytes);
  const out: GraphsView = {
    today: null,
    retrievability: null,
    reviewCountsByDaysAgo: null,
    fsrs: false
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 4:
        out.today = decodeToday(r.readBytes());
        break;
      case 9:
        out.reviewCountsByDaysAgo = decodeReviewCountsAndTimes(r.readBytes());
        break;
      case 12:
        out.retrievability = decodeRetrievability(r.readBytes());
        break;
      case 13:
        out.fsrs = r.readBool();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}
