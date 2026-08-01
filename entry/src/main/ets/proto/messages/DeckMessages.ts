// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface DeckDayLimit {
  limit: number;
  today: number;
}

export interface DeckCommon {
  studyCollapsed: boolean;
  browserCollapsed: boolean;
  lastDayStudied: number;
  newStudied: number;
  learningStudied: number;
  millisecondsStudied: number;
  other: Uint8Array | null;
}

export interface DeckNormal {
  configId: number;
  extendNew: number;
  extendReview: number;
  description: string;
  markdownDescription: boolean;
  reviewLimit: number | null;
  newLimit: number | null;
  reviewLimitToday: DeckDayLimit | null;
  newLimitToday: DeckDayLimit | null;
  desiredRetention: number | null;
}

export interface Deck {
  id: number;
  name: string;
  mtimeSecs: number;
  usn: number;
  common: DeckCommon | null;
  normal: DeckNormal | null;
}

function encodeDayLimit(value: DeckDayLimit): 协议写入器 {
  const w = new 协议写入器();
  if (value.limit !== 0) {
    w.写入变长整数(1, value.limit);
  }
  if (value.today !== 0) {
    w.写入变长整数(2, value.today);
  }
  return w;
}

function decodeDayLimit(bytes: Uint8Array): DeckDayLimit {
  const r = new 协议读取器(bytes);
  const out: DeckDayLimit = { limit: 0, today: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      out.limit = r.读取变长整数();
    } else if (tag.字段号 === 2) {
      out.today = r.读取变长整数();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function encodeCommon(value: DeckCommon): 协议写入器 {
  const w = new 协议写入器();
  if (value.studyCollapsed) {
    w.写入布尔(1, true);
  }
  if (value.browserCollapsed) {
    w.写入布尔(2, true);
  }
  if (value.lastDayStudied !== 0) {
    w.写入变长整数(3, value.lastDayStudied);
  }
  if (value.newStudied !== 0) {
    w.写入变长整数(4, value.newStudied);
  }
  if (value.learningStudied !== 0) {
    w.写入变长整数(6, value.learningStudied);
  }
  if (value.millisecondsStudied !== 0) {
    w.写入变长整数(7, value.millisecondsStudied);
  }
  if (value.other !== null && value.other.length > 0) {
    w.写入字节(255, value.other);
  }
  return w;
}

function decodeCommon(bytes: Uint8Array): DeckCommon {
  const r = new 协议读取器(bytes);
  const out: DeckCommon = {
    studyCollapsed: false,
    browserCollapsed: false,
    lastDayStudied: 0,
    newStudied: 0,
    learningStudied: 0,
    millisecondsStudied: 0,
    other: null
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.studyCollapsed = r.读取布尔();
        break;
      case 2:
        out.browserCollapsed = r.读取布尔();
        break;
      case 3:
        out.lastDayStudied = r.读取变长整数();
        break;
      case 4:
        out.newStudied = r.读取32位整数();
        break;
      case 6:
        out.learningStudied = r.读取32位整数();
        break;
      case 7:
        out.millisecondsStudied = r.读取32位整数();
        break;
      case 255:
        out.other = r.读取字节();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function encodeNormal(value: DeckNormal): 协议写入器 {
  const w = new 协议写入器();
  if (value.configId !== 0) {
    w.写入64位整数(1, value.configId);
  }
  if (value.extendNew !== 0) {
    w.写入变长整数(2, value.extendNew);
  }
  if (value.extendReview !== 0) {
    w.写入变长整数(3, value.extendReview);
  }
  if (value.description !== '') {
    w.写入字符串(4, value.description);
  }
  if (value.markdownDescription) {
    w.写入布尔(5, true);
  }
  if (value.reviewLimit !== null) {
    w.写入变长整数(6, value.reviewLimit);
  }
  if (value.newLimit !== null) {
    w.写入变长整数(7, value.newLimit);
  }
  if (value.reviewLimitToday !== null) {
    w.写入子消息(8, encodeDayLimit(value.reviewLimitToday));
  }
  if (value.newLimitToday !== null) {
    w.写入子消息(9, encodeDayLimit(value.newLimitToday));
  }
  if (value.desiredRetention !== null) {
    w.写入浮点(10, value.desiredRetention);
  }
  return w;
}

function decodeNormal(bytes: Uint8Array): DeckNormal {
  const r = new 协议读取器(bytes);
  const out: DeckNormal = {
    configId: 0,
    extendNew: 0,
    extendReview: 0,
    description: '',
    markdownDescription: false,
    reviewLimit: null,
    newLimit: null,
    reviewLimitToday: null,
    newLimitToday: null,
    desiredRetention: null
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.configId = r.读取64位整数();
        break;
      case 2:
        out.extendNew = r.读取变长整数();
        break;
      case 3:
        out.extendReview = r.读取变长整数();
        break;
      case 4:
        out.description = r.读取字符串();
        break;
      case 5:
        out.markdownDescription = r.读取布尔();
        break;
      case 6:
        out.reviewLimit = r.读取变长整数();
        break;
      case 7:
        out.newLimit = r.读取变长整数();
        break;
      case 8:
        out.reviewLimitToday = decodeDayLimit(r.读取字节());
        break;
      case 9:
        out.newLimitToday = decodeDayLimit(r.读取字节());
        break;
      case 10:
        out.desiredRetention = r.读取浮点();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function encodeDeck(deck: Deck): Uint8Array {
  const w = new 协议写入器();
  if (deck.id !== 0) {
    w.写入64位整数(1, deck.id);
  }
  if (deck.name !== '') {
    w.写入字符串(2, deck.name);
  }
  if (deck.mtimeSecs !== 0) {
    w.写入64位整数(3, deck.mtimeSecs);
  }
  if (deck.usn !== 0) {
    w.写入变长整数(4, deck.usn);
  }
  if (deck.common !== null) {
    w.写入子消息(5, encodeCommon(deck.common));
  }
  if (deck.normal !== null) {
    w.写入子消息(6, encodeNormal(deck.normal));
  }
  return w.转为字节();
}

export function encodeRenameDeckRequest(deckId: number, newName: string): Uint8Array {
  const w = new 协议写入器();
  if (deckId !== 0) {
    w.写入64位整数(1, deckId);
  }
  if (newName !== '') {
    w.写入字符串(2, newName);
  }
  return w.转为字节();
}

export function decodeDeck(bytes: Uint8Array): Deck {
  const r = new 协议读取器(bytes);
  const deck: Deck = { id: 0, name: '', mtimeSecs: 0, usn: 0, common: null, normal: null };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        deck.id = r.读取64位整数();
        break;
      case 2:
        deck.name = r.读取字符串();
        break;
      case 3:
        deck.mtimeSecs = r.读取64位整数();
        break;
      case 4:
        deck.usn = r.读取32位整数();
        break;
      case 5:
        deck.common = decodeCommon(r.读取字节());
        break;
      case 6:
        deck.normal = decodeNormal(r.读取字节());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return deck;
}

export function encodeDeckTreeRequest(now: number): Uint8Array {
  const w = new 协议写入器();
  if (now !== 0) {
    w.写入64位整数(1, now);
  }
  return w.转为字节();
}

export interface DeckTreeNode {
  deckId: number;
  name: string;
  level: number;
  collapsed: boolean;
  reviewCount: number;
  learnCount: number;
  newCount: number;
  totalInDeck: number;
  totalIncludingChildren: number;
  filtered: boolean;
  children: DeckTreeNode[];
}

export function decodeDeckTreeNode(bytes: Uint8Array): DeckTreeNode {
  const r = new 协议读取器(bytes);
  const node: DeckTreeNode = {
    deckId: 0,
    name: '',
    level: 0,
    collapsed: false,
    reviewCount: 0,
    learnCount: 0,
    newCount: 0,
    totalInDeck: 0,
    totalIncludingChildren: 0,
    filtered: false,
    children: []
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        node.deckId = r.读取64位整数();
        break;
      case 2:
        node.name = r.读取字符串();
        break;
      case 3:
        node.children.push(decodeDeckTreeNode(r.读取字节()));
        break;
      case 4:
        node.level = r.读取变长整数();
        break;
      case 5:
        node.collapsed = r.读取布尔();
        break;
      case 6:
        node.reviewCount = r.读取变长整数();
        break;
      case 7:
        node.learnCount = r.读取变长整数();
        break;
      case 8:
        node.newCount = r.读取变长整数();
        break;
      case 13:
        node.totalInDeck = r.读取变长整数();
        break;
      case 14:
        node.totalIncludingChildren = r.读取变长整数();
        break;
      case 16:
        node.filtered = r.读取布尔();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return node;
}

export function encodeGetDeckNamesRequest(skipEmptyDefault: boolean, includeFiltered: boolean): Uint8Array {
  const w = new 协议写入器();
  if (skipEmptyDefault) {
    w.写入布尔(1, true);
  }
  if (includeFiltered) {
    w.写入布尔(2, true);
  }
  return w.转为字节();
}

export function encodeDeckId(deckId: number): Uint8Array {
  const w = new 协议写入器();
  if (deckId !== 0) {
    w.写入64位整数(1, deckId);
  }
  return w.转为字节();
}

export function encodeDeckIds(deckIds: number[]): Uint8Array {
  const w = new 协议写入器();
  for (let i = 0; i < deckIds.length; i++) {
    w.写入64位整数(1, deckIds[i]);
  }
  return w.转为字节();
}

export interface DeckNameId {
  id: number;
  name: string;
}

export function decodeDeckNames(bytes: Uint8Array): DeckNameId[] {
  const r = new 协议读取器(bytes);
  const entries: DeckNameId[] = [];
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      entries.push(decodeDeckNameId(r.读取字节()));
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return entries;
}

function decodeDeckNameId(bytes: Uint8Array): DeckNameId {
  const r = new 协议读取器(bytes);
  const entry: DeckNameId = { id: 0, name: '' };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      entry.id = r.读取64位整数();
    } else if (tag.字段号 === 2) {
      entry.name = r.读取字符串();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return entry;
}
