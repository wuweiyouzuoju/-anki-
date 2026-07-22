// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.decks 相关消息编解码：Deck（新建牌组往返）、DeckTreeRequest、
// DeckTreeNode（主页计数树）、GetDeckNamesRequest、DeckNames。
// 字段来源：third_party/anki/proto/anki/decks.proto（Anki 26.05）
// 约定：proto3 optional 字段用 null 表示「未设置」；编码时跳过默认值，与 prost 对齐。

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

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
  /** 保留字节（field 255），原样往返 */
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

/** 仅覆盖普通牌组；NewDeck 模板与新建流程不会遇到 Filtered */
export interface Deck {
  id: number;
  name: string;
  mtimeSecs: number;
  usn: number;
  common: DeckCommon | null;
  normal: DeckNormal | null;
}

function encodeDayLimit(value: DeckDayLimit): ProtoWriter {
  const w = new ProtoWriter();
  if (value.limit !== 0) {
    w.writeVarint(1, value.limit);
  }
  if (value.today !== 0) {
    w.writeVarint(2, value.today);
  }
  return w;
}

function decodeDayLimit(bytes: Uint8Array): DeckDayLimit {
  const r = new ProtoReader(bytes);
  const out: DeckDayLimit = { limit: 0, today: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      out.limit = r.readVarint();
    } else if (tag.fieldNumber === 2) {
      out.today = r.readVarint();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return out;
}

function encodeCommon(value: DeckCommon): ProtoWriter {
  const w = new ProtoWriter();
  if (value.studyCollapsed) {
    w.writeBool(1, true);
  }
  if (value.browserCollapsed) {
    w.writeBool(2, true);
  }
  if (value.lastDayStudied !== 0) {
    w.writeVarint(3, value.lastDayStudied);
  }
  if (value.newStudied !== 0) {
    w.writeVarint(4, value.newStudied);
  }
  if (value.learningStudied !== 0) {
    w.writeVarint(6, value.learningStudied);
  }
  if (value.millisecondsStudied !== 0) {
    w.writeVarint(7, value.millisecondsStudied);
  }
  if (value.other !== null && value.other.length > 0) {
    w.writeBytes(255, value.other);
  }
  return w;
}

function decodeCommon(bytes: Uint8Array): DeckCommon {
  const r = new ProtoReader(bytes);
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
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.studyCollapsed = r.readBool();
        break;
      case 2:
        out.browserCollapsed = r.readBool();
        break;
      case 3:
        out.lastDayStudied = r.readVarint();
        break;
      case 4:
        out.newStudied = r.readInt32();
        break;
      case 6:
        out.learningStudied = r.readInt32();
        break;
      case 7:
        out.millisecondsStudied = r.readInt32();
        break;
      case 255:
        out.other = r.readBytes();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

function encodeNormal(value: DeckNormal): ProtoWriter {
  const w = new ProtoWriter();
  if (value.configId !== 0) {
    w.writeInt64(1, value.configId);
  }
  if (value.extendNew !== 0) {
    w.writeVarint(2, value.extendNew);
  }
  if (value.extendReview !== 0) {
    w.writeVarint(3, value.extendReview);
  }
  if (value.description !== '') {
    w.writeString(4, value.description);
  }
  if (value.markdownDescription) {
    w.writeBool(5, true);
  }
  if (value.reviewLimit !== null) {
    w.writeVarint(6, value.reviewLimit);
  }
  if (value.newLimit !== null) {
    w.writeVarint(7, value.newLimit);
  }
  if (value.reviewLimitToday !== null) {
    w.writeMessage(8, encodeDayLimit(value.reviewLimitToday));
  }
  if (value.newLimitToday !== null) {
    w.writeMessage(9, encodeDayLimit(value.newLimitToday));
  }
  if (value.desiredRetention !== null) {
    w.writeFloat(10, value.desiredRetention);
  }
  return w;
}

function decodeNormal(bytes: Uint8Array): DeckNormal {
  const r = new ProtoReader(bytes);
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
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.configId = r.readInt64();
        break;
      case 2:
        out.extendNew = r.readVarint();
        break;
      case 3:
        out.extendReview = r.readVarint();
        break;
      case 4:
        out.description = r.readString();
        break;
      case 5:
        out.markdownDescription = r.readBool();
        break;
      case 6:
        out.reviewLimit = r.readVarint();
        break;
      case 7:
        out.newLimit = r.readVarint();
        break;
      case 8:
        out.reviewLimitToday = decodeDayLimit(r.readBytes());
        break;
      case 9:
        out.newLimitToday = decodeDayLimit(r.readBytes());
        break;
      case 10:
        out.desiredRetention = r.readFloat();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function encodeDeck(deck: Deck): Uint8Array {
  const w = new ProtoWriter();
  if (deck.id !== 0) {
    w.writeInt64(1, deck.id);
  }
  if (deck.name !== '') {
    w.writeString(2, deck.name);
  }
  if (deck.mtimeSecs !== 0) {
    w.writeInt64(3, deck.mtimeSecs);
  }
  if (deck.usn !== 0) {
    w.writeVarint(4, deck.usn);
  }
  if (deck.common !== null) {
    w.writeMessage(5, encodeCommon(deck.common));
  }
  if (deck.normal !== null) {
    w.writeMessage(6, encodeNormal(deck.normal));
  }
  return w.toBytes();
}

/**
 * 编码 RenameDeckRequest（decks.proto）：
 * - field 1: int64 deck_id
 * - field 2: string new_name
 * 仅在 deckId 非 0、newName 非空时编码；后端 rename_deck 会自动级联重命名子牌组前缀。
 */
export function encodeRenameDeckRequest(deckId: number, newName: string): Uint8Array {
  const w = new ProtoWriter();
  if (deckId !== 0) {
    w.writeInt64(1, deckId);
  }
  if (newName !== '') {
    w.writeString(2, newName);
  }
  return w.toBytes();
}

export function decodeDeck(bytes: Uint8Array): Deck {
  const r = new ProtoReader(bytes);
  const deck: Deck = { id: 0, name: '', mtimeSecs: 0, usn: 0, common: null, normal: null };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        deck.id = r.readInt64();
        break;
      case 2:
        deck.name = r.readString();
        break;
      case 3:
        deck.mtimeSecs = r.readInt64();
        break;
      case 4:
        deck.usn = r.readInt32();
        break;
      case 5:
        deck.common = decodeCommon(r.readBytes());
        break;
      case 6:
        deck.normal = decodeNormal(r.readBytes());
        break;
      default:
        // kind=7 Filtered 等不处理：新建流程不会产生
        r.skipField(tag.wireType);
    }
  }
  return deck;
}

export function encodeDeckTreeRequest(now: number): Uint8Array {
  const w = new ProtoWriter();
  if (now !== 0) {
    w.writeInt64(1, now);
  }
  return w.toBytes();
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
  const r = new ProtoReader(bytes);
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
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        node.deckId = r.readInt64();
        break;
      case 2:
        node.name = r.readString();
        break;
      case 3:
        node.children.push(decodeDeckTreeNode(r.readBytes()));
        break;
      case 4:
        node.level = r.readVarint();
        break;
      case 5:
        node.collapsed = r.readBool();
        break;
      case 6:
        node.reviewCount = r.readVarint();
        break;
      case 7:
        node.learnCount = r.readVarint();
        break;
      case 8:
        node.newCount = r.readVarint();
        break;
      case 13:
        node.totalInDeck = r.readVarint();
        break;
      case 14:
        node.totalIncludingChildren = r.readVarint();
        break;
      case 16:
        node.filtered = r.readBool();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return node;
}

export function encodeGetDeckNamesRequest(skipEmptyDefault: boolean, includeFiltered: boolean): Uint8Array {
  const w = new ProtoWriter();
  if (skipEmptyDefault) {
    w.writeBool(1, true);
  }
  if (includeFiltered) {
    w.writeBool(2, true);
  }
  return w.toBytes();
}

/** decks.DeckId：SetCurrentDeck 等的入参（字段来源：decks.proto 第 46 行） */
export function encodeDeckId(deckId: number): Uint8Array {
  const w = new ProtoWriter();
  if (deckId !== 0) {
    w.writeInt64(1, deckId);
  }
  return w.toBytes();
}

/**
 * 编码 DeckIds（decks.proto 第 50-52 行）：
 * - field 1: repeated int64 dids（packed 或非 packed 均可，后端兼容）
 * RemoveDecks RPC 的入参；后端 remove_decks_and_child_decks 会递归删除所有子牌组。
 */
export function encodeDeckIds(deckIds: number[]): Uint8Array {
  const w = new ProtoWriter();
  for (let i = 0; i < deckIds.length; i++) {
    w.writeInt64(1, deckIds[i]);
  }
  return w.toBytes();
}

export interface DeckNameId {
  id: number;
  name: string;
}

export function decodeDeckNames(bytes: Uint8Array): DeckNameId[] {
  const r = new ProtoReader(bytes);
  const entries: DeckNameId[] = [];
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      entries.push(decodeDeckNameId(r.readBytes()));
    } else {
      r.skipField(tag.wireType);
    }
  }
  return entries;
}

function decodeDeckNameId(bytes: Uint8Array): DeckNameId {
  const r = new ProtoReader(bytes);
  const entry: DeckNameId = { id: 0, name: '' };
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      entry.id = r.readInt64();
    } else if (tag.fieldNumber === 2) {
      entry.name = r.readString();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return entry;
}
