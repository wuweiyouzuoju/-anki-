// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export type RawSchedulingState = Uint8Array;

export interface SchedulingStatesRaw {
  current: RawSchedulingState;
  again: RawSchedulingState;
  hard: RawSchedulingState;
  good: RawSchedulingState;
  easy: RawSchedulingState;
}

export const RATING_AGAIN = 0;
export const RATING_HARD = 1;
export const RATING_GOOD = 2;
export const RATING_EASY = 3;

export const QUEUE_NEW = 0;
export const QUEUE_LEARNING = 1;
export const QUEUE_REVIEW = 2;

export function decodeSchedulingStates(bytes: Uint8Array): SchedulingStatesRaw {
  const r = new 协议读取器(bytes);
  const states: SchedulingStatesRaw = {
    current: new Uint8Array(0),
    again: new Uint8Array(0),
    hard: new Uint8Array(0),
    good: new Uint8Array(0),
    easy: new Uint8Array(0)
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        states.current = r.读取字节();
        break;
      case 2:
        states.again = r.读取字节();
        break;
      case 3:
        states.hard = r.读取字节();
        break;
      case 4:
        states.good = r.读取字节();
        break;
      case 5:
        states.easy = r.读取字节();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return states;
}

export interface StudyCard {
  cardId: number;
  noteId: number;
  deckId: number;
  templateIdx: number;
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
  const w = new 协议写入器();
  if (fetchLimit !== 0) {
    w.写入变长整数(1, fetchLimit);
  }
  if (intradayLearningOnly) {
    w.写入布尔(2, true);
  }
  return w.转为字节();
}

interface CardSummary {
  cardId: number;
  noteId: number;
  deckId: number;
  templateIdx: number;
}

function decodeCardSummary(bytes: Uint8Array): CardSummary {
  const r = new 协议读取器(bytes);
  const out: CardSummary = { cardId: 0, noteId: 0, deckId: 0, templateIdx: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.cardId = r.读取64位整数();
        break;
      case 2:
        out.noteId = r.读取64位整数();
        break;
      case 3:
        out.deckId = r.读取64位整数();
        break;
      case 4:
        out.templateIdx = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function decodeQueuedCard(bytes: Uint8Array): StudyCard {
  const r = new 协议读取器(bytes);
  const card: StudyCard = {
    cardId: 0,
    noteId: 0,
    deckId: 0,
    templateIdx: 0,
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
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1: {
        const summary = decodeCardSummary(r.读取字节());
        card.cardId = summary.cardId;
        card.noteId = summary.noteId;
        card.deckId = summary.deckId;
        card.templateIdx = summary.templateIdx;
        break;
      }
      case 2:
        card.queue = r.读取变长整数();
        break;
      case 3:
        card.states = decodeSchedulingStates(r.读取字节());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return card;
}

export function decodeQueuedCards(bytes: Uint8Array): QueuedCardsView {
  const r = new 协议读取器(bytes);
  const view: QueuedCardsView = { cards: [], newCount: 0, learningCount: 0, reviewCount: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        view.cards.push(decodeQueuedCard(r.读取字节()));
        break;
      case 2:
        view.newCount = r.读取变长整数();
        break;
      case 3:
        view.learningCount = r.读取变长整数();
        break;
      case 4:
        view.reviewCount = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
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
  const w = new 协议写入器();
  if (answer.cardId !== 0) {
    w.写入64位整数(1, answer.cardId);
  }
  if (answer.currentState.length > 0) {
    w.写入字节(2, answer.currentState);
  }
  if (answer.newState.length > 0) {
    w.写入字节(3, answer.newState);
  }
  if (answer.rating !== 0) {
    w.写入变长整数(4, answer.rating);
  }
  if (answer.answeredAtMillis !== 0) {
    w.写入64位整数(5, answer.answeredAtMillis);
  }
  if (answer.millisecondsTaken !== 0) {
    w.写入变长整数(6, answer.millisecondsTaken);
  }
  return w.转为字节();
}

export function encodeCardId(cardId: number): Uint8Array {
  const w = new 协议写入器();
  if (cardId !== 0) {
    w.写入64位整数(1, cardId);
  }
  return w.转为字节();
}

export function encodeCardIds(cardIds: number[]): Uint8Array {
  const w = new 协议写入器();
  w.写入打包64位整数(1, cardIds);
  return w.转为字节();
}

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
  const r = new 协议读取器(bytes);
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
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.learnRemaining = r.读取变长整数();
        break;
      case 2:
        out.secsUntilNextLearn = r.读取变长整数();
        break;
      case 3:
        out.reviewRemaining = r.读取布尔();
        break;
      case 4:
        out.newRemaining = r.读取布尔();
        break;
      case 5:
        out.haveSchedBuried = r.读取布尔();
        break;
      case 6:
        out.haveUserBuried = r.读取布尔();
        break;
      case 7:
        out.isFilteredDeck = r.读取布尔();
        break;
      case 8:
        out.bridgeCommandsSupported = r.读取布尔();
        break;
      case 9:
        out.deckDescription = r.读取字符串();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export const BURY_SUSPEND_MODE_SUSPEND = 0;
export const BURY_SUSPEND_MODE_BURY_SCHED = 1;
export const BURY_SUSPEND_MODE_BURY_USER = 2;

export function encodeBuryOrSuspendCardsRequest(cardIds: number[], noteIds: number[], mode: number): Uint8Array {
  const w = new 协议写入器();
  w.写入打包64位整数(1, cardIds);
  w.写入打包64位整数(2, noteIds);
  if (mode !== 0) {
    w.写入变长整数(3, mode);
  }
  return w.转为字节();
}

export const UNBURY_MODE_ALL = 0;
export const UNBURY_MODE_SCHED_ONLY = 1;
export const UNBURY_MODE_USER_ONLY = 2;

export function encodeUnburyDeckRequest(deckId: number, mode: number): Uint8Array {
  const w = new 协议写入器();
  if (deckId !== 0) {
    w.写入64位整数(1, deckId);
  }
  if (mode !== 0) {
    w.写入变长整数(2, mode);
  }
  return w.转为字节();
}

export interface SchedTimingToday {
  daysElapsed: number;
  nextDayAt: number;
}

export interface DeckTodayCounts {
  newCount: number;
  reviewCount: number;
}

export function decodeCountsForDeckToday(bytes: Uint8Array): DeckTodayCounts {
  const r = new 协议读取器(bytes);
  const out: DeckTodayCounts = { newCount: 0, reviewCount: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      out.newCount = r.读取变长整数();
    } else if (tag.字段号 === 2) {
      out.reviewCount = r.读取变长整数();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeSchedTimingToday(bytes: Uint8Array): SchedTimingToday {
  const r = new 协议读取器(bytes);
  const out: SchedTimingToday = { daysElapsed: 0, nextDayAt: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      out.daysElapsed = r.读取变长整数();
    } else if (tag.字段号 === 2) {
      out.nextDayAt = r.读取64位整数();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeStringList(bytes: Uint8Array): string[] {
  const r = new 协议读取器(bytes);
  const vals: string[] = [];
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      vals.push(r.读取字符串());
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return vals;
}

export function encodeSchedulingStates(states: SchedulingStatesRaw): Uint8Array {
  const w = new 协议写入器();
  if (states.current.length > 0) {
    w.写入字节(1, states.current);
  }
  if (states.again.length > 0) {
    w.写入字节(2, states.again);
  }
  if (states.hard.length > 0) {
    w.写入字节(3, states.hard);
  }
  if (states.good.length > 0) {
    w.写入字节(4, states.good);
  }
  if (states.easy.length > 0) {
    w.写入字节(5, states.easy);
  }
  return w.转为字节();
}
