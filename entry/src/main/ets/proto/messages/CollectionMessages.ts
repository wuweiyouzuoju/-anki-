// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface OpenCollectionRequest {
  collectionPath: string;
  mediaFolderPath: string;
  mediaDbPath: string;
}

export function encodeOpenCollectionRequest(req: OpenCollectionRequest): Uint8Array {
  const w = new 协议写入器();
  if (req.collectionPath !== '') {
    w.写入字符串(1, req.collectionPath);
  }
  if (req.mediaFolderPath !== '') {
    w.写入字符串(2, req.mediaFolderPath);
  }
  if (req.mediaDbPath !== '') {
    w.写入字符串(3, req.mediaDbPath);
  }
  return w.转为字节();
}

export function encodeCloseCollectionRequest(downgradeToSchema11: boolean = false): Uint8Array {
  const w = new 协议写入器();
  if (downgradeToSchema11) {
    w.写入布尔(1, downgradeToSchema11);
  }
  return w.转为字节();
}

export function decodeOpChangesWithId(bytes: Uint8Array): number {
  const r = new 协议读取器(bytes);
  let id = 0;
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 2) {
      id = r.读取64位整数();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return id;
}

export function decodeOpChangesWithCount(bytes: Uint8Array): number {
  const r = new 协议读取器(bytes);
  let count = 0;
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 2) {
      count = r.读取变长整数();
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return count;
}

export interface OpChanges {
  card: boolean;
  note: boolean;
  deck: boolean;
  tag: boolean;
  notetype: boolean;
  config: boolean;
  deckConfig: boolean;
  mtime: boolean;
  browserTable: boolean;
  browserSidebar: boolean;
  noteText: boolean;
  studyQueues: boolean;
}

export function decodeOpChanges(bytes: Uint8Array): OpChanges {
  const r = new 协议读取器(bytes);
  const out: OpChanges = {
    card: false,
    note: false,
    deck: false,
    tag: false,
    notetype: false,
    config: false,
    deckConfig: false,
    mtime: false,
    browserTable: false,
    browserSidebar: false,
    noteText: false,
    studyQueues: false
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.card = r.读取布尔();
        break;
      case 2:
        out.note = r.读取布尔();
        break;
      case 3:
        out.deck = r.读取布尔();
        break;
      case 4:
        out.tag = r.读取布尔();
        break;
      case 5:
        out.notetype = r.读取布尔();
        break;
      case 6:
        out.config = r.读取布尔();
        break;
      case 7:
        out.browserTable = r.读取布尔();
        break;
      case 8:
        out.browserSidebar = r.读取布尔();
        break;
      case 9:
        out.noteText = r.读取布尔();
        break;
      case 10:
        out.studyQueues = r.读取布尔();
        break;
      case 11:
        out.deckConfig = r.读取布尔();
        break;
      case 12:
        out.mtime = r.读取布尔();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export interface UndoStatus {
  undo: string;
  redo: string;
  lastStep: number;
}

export function decodeUndoStatus(bytes: Uint8Array): UndoStatus {
  const r = new 协议读取器(bytes);
  const out: UndoStatus = { undo: '', redo: '', lastStep: 0 };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.undo = r.读取字符串();
        break;
      case 2:
        out.redo = r.读取字符串();
        break;
      case 3:
        out.lastStep = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export interface OpChangesAfterUndo {
  changes: OpChanges | null;
  operation: string;
  revertedToTimestamp: number;
  newStatus: UndoStatus | null;
  counter: number;
}

export function decodeOpChangesAfterUndo(bytes: Uint8Array): OpChangesAfterUndo {
  const r = new 协议读取器(bytes);
  const out: OpChangesAfterUndo = {
    changes: null,
    operation: '',
    revertedToTimestamp: 0,
    newStatus: null,
    counter: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.changes = decodeOpChanges(r.读取字节());
        break;
      case 2:
        out.operation = r.读取字符串();
        break;
      case 3:
        out.revertedToTimestamp = r.读取64位整数();
        break;
      case 4:
        out.newStatus = decodeUndoStatus(r.读取字节());
        break;
      case 5:
        out.counter = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeCheckDatabaseResponse(bytes: Uint8Array): string[] {
  const r = new 协议读取器(bytes);
  const problems: string[] = [];
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      problems.push(r.读取字符串());
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return problems;
}
