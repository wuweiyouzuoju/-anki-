// anki.scheduler 复习链路消息编解码。
// 字段来源：third_party/anki/proto/anki/scheduler.proto、cards.proto、generic.proto（Anki 26.05）
//
// 设计要点：SchedulingState 是深层 oneof 结构（New/Learning/Review/Relearning/
// Filtered…），前端不需要理解其内容——按钮文案由后端 DescribeNextStates 给出。
// 因此解码时把每个状态的原始字节原样保留（raw passthrough），作答时原样回写，
// 既保证字节级保真，又避免在前端维护一份易过期的 oneof 重编码。
// custom_data（插件用）当前版本不填充：后端注释明确「不设置则不会更新」。

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

/** SchedulingState 的不透明原始字节，作答时原样回传 */
export type RawSchedulingState = Uint8Array;

export interface SchedulingStatesRaw {
  current: RawSchedulingState;
  again: RawSchedulingState;
  hard: RawSchedulingState;
  good: RawSchedulingState;
  easy: RawSchedulingState;
}

/** 评分档位，与 CardAnswer.Rating 对应 */
export const RATING_AGAIN = 0;
export const RATING_HARD = 1;
export const RATING_GOOD = 2;
export const RATING_EASY = 3;

/** 卡片所属队列，与 QueuedCards.Queue 对应 */
export const QUEUE_NEW = 0;
export const QUEUE_LEARNING = 1;
export const QUEUE_REVIEW = 2;

export function decodeSchedulingStates(bytes: Uint8Array): SchedulingStatesRaw {
  const r = new ProtoReader(bytes);
  const states: SchedulingStatesRaw = {
    current: new Uint8Array(0),
    again: new Uint8Array(0),
    hard: new Uint8Array(0),
    good: new Uint8Array(0),
    easy: new Uint8Array(0)
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        states.current = r.readBytes();
        break;
      case 2:
        states.again = r.readBytes();
        break;
      case 3:
        states.hard = r.readBytes();
        break;
      case 4:
        states.good = r.readBytes();
        break;
      case 5:
        states.easy = r.readBytes();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return states;
}

export interface StudyCard {
  cardId: number;
  noteId: number;
  deckId: number;
  queue: number;
  states: SchedulingStatesRaw;
}

export interface QueuedCardsView {
  cards: StudyCard[];
  newCount: number;
  learningCount: number;
  reviewCount: number;
}

export function encodeGetQueuedCardsRequest(fetchLimit: number, intradayLearningOnly: boolean): Uint8Array {
  const w = new ProtoWriter();
  if (fetchLimit !== 0) {
    w.writeVarint(1, fetchLimit);
  }
  if (intradayLearningOnly) {
    w.writeBool(2, true);
  }
  return w.toBytes();
}

/** 只取学习链路需要的 Card 字段（id/note_id/deck_id），其余跳过 */
interface CardSummary {
  cardId: number;
  noteId: number;
  deckId: number;
}

function decodeCardSummary(bytes: Uint8Array): CardSummary {
  const r = new ProtoReader(bytes);
  const out: CardSummary = { cardId: 0, noteId: 0, deckId: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.cardId = r.readInt64();
        break;
      case 2:
        out.noteId = r.readInt64();
        break;
      case 3:
        out.deckId = r.readInt64();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

function decodeQueuedCard(bytes: Uint8Array): StudyCard {
  const r = new ProtoReader(bytes);
  const card: StudyCard = {
    cardId: 0,
    noteId: 0,
    deckId: 0,
    queue: QUEUE_NEW,
    states: {
      current: new Uint8Array(0),
      again: new Uint8Array(0),
      hard: new Uint8Array(0),
      good: new Uint8Array(0),
      easy: new Uint8Array(0)
    }
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1: {
        const summary = decodeCardSummary(r.readBytes());
        card.cardId = summary.cardId;
        card.noteId = summary.noteId;
        card.deckId = summary.deckId;
        break;
      }
      case 2:
        card.queue = r.readVarint();
        break;
      case 3:
        card.states = decodeSchedulingStates(r.readBytes());
        break;
      default:
        // context（牌组名/随机种子）UI 暂不需要
        r.skipField(tag.wireType);
    }
  }
  return card;
}

export function decodeQueuedCards(bytes: Uint8Array): QueuedCardsView {
  const r = new ProtoReader(bytes);
  const view: QueuedCardsView = { cards: [], newCount: 0, learningCount: 0, reviewCount: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        view.cards.push(decodeQueuedCard(r.readBytes()));
        break;
      case 2:
        view.newCount = r.readVarint();
        break;
      case 3:
        view.learningCount = r.readVarint();
        break;
      case 4:
        view.reviewCount = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return view;
}

export interface CardAnswerInput {
  cardId: number;
  currentState: RawSchedulingState;
  newState: RawSchedulingState;
  rating: number;
  answeredAtMillis: number;
  millisecondsTaken: number;
}

export function encodeCardAnswer(answer: CardAnswerInput): Uint8Array {
  const w = new ProtoWriter();
  if (answer.cardId !== 0) {
    w.writeInt64(1, answer.cardId);
  }
  if (answer.currentState.length > 0) {
    w.writeBytes(2, answer.currentState);
  }
  if (answer.newState.length > 0) {
    w.writeBytes(3, answer.newState);
  }
  if (answer.rating !== 0) {
    w.writeVarint(4, answer.rating);
  }
  if (answer.answeredAtMillis !== 0) {
    w.writeInt64(5, answer.answeredAtMillis);
  }
  if (answer.millisecondsTaken !== 0) {
    w.writeVarint(6, answer.millisecondsTaken);
  }
  return w.toBytes();
}

/** cards.CardId：GetSchedulingStates / RenderExistingCard 等的入参 */
export function encodeCardId(cardId: number): Uint8Array {
  const w = new ProtoWriter();
  if (cardId !== 0) {
    w.writeInt64(1, cardId);
  }
  return w.toBytes();
}

/** cards.CardIds：RestoreBuriedAndSuspendedCards 的入参（packed repeated int64） */
export function encodeCardIds(cardIds: number[]): Uint8Array {
  const w = new ProtoWriter();
  w.writePackedInt64(1, cardIds);
  return w.toBytes();
}

/** CongratsInfoResponse：完成页状态（剩余卡片/待解压标记/牌组描述） */
export interface CongratsInfo {
  learnRemaining: number;
  secsUntilNextLearn: number;
  reviewRemaining: boolean;
  newRemaining: boolean;
  haveSchedBuried: boolean;
  haveUserBuried: boolean;
  isFilteredDeck: boolean;
  bridgeCommandsSupported: boolean;
  deckDescription: string;
}

export function decodeCongratsInfo(bytes: Uint8Array): CongratsInfo {
  const r = new ProtoReader(bytes);
  const out: CongratsInfo = {
    learnRemaining: 0,
    secsUntilNextLearn: 0,
    reviewRemaining: false,
    newRemaining: false,
    haveSchedBuried: false,
    haveUserBuried: false,
    isFilteredDeck: false,
    bridgeCommandsSupported: false,
    deckDescription: ''
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.learnRemaining = r.readVarint();
        break;
      case 2:
        out.secsUntilNextLearn = r.readVarint();
        break;
      case 3:
        out.reviewRemaining = r.readBool();
        break;
      case 4:
        out.newRemaining = r.readBool();
        break;
      case 5:
        out.haveSchedBuried = r.readBool();
        break;
      case 6:
        out.haveUserBuried = r.readBool();
        break;
      case 7:
        out.isFilteredDeck = r.readBool();
        break;
      case 8:
        out.bridgeCommandsSupported = r.readBool();
        break;
      case 9:
        out.deckDescription = r.readString();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

/** BuryOrSuspendCardsRequest.Mode */
export const BURY_SUSPEND_MODE_SUSPEND = 0;
export const BURY_SUSPEND_MODE_BURY_SCHED = 1;
export const BURY_SUSPEND_MODE_BURY_USER = 2;

/** BuryOrSuspendCardsRequest：card_ids/note_ids 为 packed repeated int64 */
export function encodeBuryOrSuspendCardsRequest(cardIds: number[], noteIds: number[], mode: number): Uint8Array {
  const w = new ProtoWriter();
  w.writePackedInt64(1, cardIds);
  w.writePackedInt64(2, noteIds);
  if (mode !== 0) {
    w.writeVarint(3, mode);
  }
  return w.toBytes();
}

/** UnburyDeckRequest.Mode */
export const UNBURY_MODE_ALL = 0;
export const UNBURY_MODE_SCHED_ONLY = 1;
export const UNBURY_MODE_USER_ONLY = 2;

export function encodeUnburyDeckRequest(deckId: number, mode: number): Uint8Array {
  const w = new ProtoWriter();
  if (deckId !== 0) {
    w.writeInt64(1, deckId);
  }
  if (mode !== 0) {
    w.writeVarint(2, mode);
  }
  return w.toBytes();
}

export interface SchedTimingToday {
  daysElapsed: number;
  nextDayAt: number;
}

/** CountsForDeckTodayResponse：某牌组今日已完成的新卡/复习卡数（scheduler.proto 181 行） */
export interface DeckTodayCounts {
  newCount: number;
  reviewCount: number;
}

export function decodeCountsForDeckToday(bytes: Uint8Array): DeckTodayCounts {
  const r = new ProtoReader(bytes);
  const out: DeckTodayCounts = { newCount: 0, reviewCount: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      out.newCount = r.readVarint();
    } else if (tag.fieldNumber === 2) {
      out.reviewCount = r.readVarint();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeSchedTimingToday(bytes: Uint8Array): SchedTimingToday {
  const r = new ProtoReader(bytes);
  const out: SchedTimingToday = { daysElapsed: 0, nextDayAt: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      out.daysElapsed = r.readVarint();
    } else if (tag.fieldNumber === 2) {
      out.nextDayAt = r.readInt64();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return out;
}

/** generic.StringList：DescribeNextStates 的返回（按钮文案列表） */
export function decodeStringList(bytes: Uint8Array): string[] {
  const r = new ProtoReader(bytes);
  const vals: string[] = [];
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      vals.push(r.readString());
    } else {
      r.skipField(tag.wireType);
    }
  }
  return vals;
}

/** 把 SchedulingStatesRaw 重新编码为 SchedulingStates 字节（DescribeNextStates 入参） */
export function encodeSchedulingStates(states: SchedulingStatesRaw): Uint8Array {
  const w = new ProtoWriter();
  if (states.current.length > 0) {
    w.writeBytes(1, states.current);
  }
  if (states.again.length > 0) {
    w.writeBytes(2, states.again);
  }
  if (states.hard.length > 0) {
    w.writeBytes(3, states.hard);
  }
  if (states.good.length > 0) {
    w.writeBytes(4, states.good);
  }
  if (states.easy.length > 0) {
    w.writeBytes(5, states.easy);
  }
  return w.toBytes();
}
