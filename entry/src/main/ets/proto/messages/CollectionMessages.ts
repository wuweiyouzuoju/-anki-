// anki.collection.OpenCollectionRequest / OpChanges 族 / UndoStatus /
// OpChangesAfterUndo / CheckDatabaseResponse 编解码。
// 字段来源：third_party/anki/proto/anki/collection.proto（Anki 26.05）

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

export interface OpenCollectionRequest {
  collectionPath: string;
  mediaFolderPath: string;
  mediaDbPath: string;
}

export function encodeOpenCollectionRequest(req: OpenCollectionRequest): Uint8Array {
  const w = new ProtoWriter();
  if (req.collectionPath !== '') {
    w.writeString(1, req.collectionPath);
  }
  if (req.mediaFolderPath !== '') {
    w.writeString(2, req.mediaFolderPath);
  }
  if (req.mediaDbPath !== '') {
    w.writeString(3, req.mediaDbPath);
  }
  return w.toBytes();
}

/** BackendCollectionService.CloseCollectionRequest, with schema downgrade disabled. */
export function encodeCloseCollectionRequest(downgradeToSchema11: boolean = false): Uint8Array {
  const w = new ProtoWriter();
  if (downgradeToSchema11) {
    w.writeBool(1, downgradeToSchema11);
  }
  return w.toBytes();
}

/** OpChangesWithId：仅需 id，changes 子消息跳过 */
export function decodeOpChangesWithId(bytes: Uint8Array): number {
  const r = new ProtoReader(bytes);
  let id = 0;
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 2) {
      id = r.readInt64();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return id;
}

/** OpChangesWithCount：仅需 count */
export function decodeOpChangesWithCount(bytes: Uint8Array): number {
  const r = new ProtoReader(bytes);
  let count = 0;
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 2) {
      count = r.readVarint();
    } else {
      r.skipField(tag.wireType);
    }
  }
  return count;
}

/** OpChanges：各实体变更标记，Undo/BuryOrSuspend 等写操作的响应 */
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
  const r = new ProtoReader(bytes);
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
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.card = r.readBool();
        break;
      case 2:
        out.note = r.readBool();
        break;
      case 3:
        out.deck = r.readBool();
        break;
      case 4:
        out.tag = r.readBool();
        break;
      case 5:
        out.notetype = r.readBool();
        break;
      case 6:
        out.config = r.readBool();
        break;
      case 7:
        out.browserTable = r.readBool();
        break;
      case 8:
        out.browserSidebar = r.readBool();
        break;
      case 9:
        out.noteText = r.readBool();
        break;
      case 10:
        out.studyQueues = r.readBool();
        break;
      case 11:
        out.deckConfig = r.readBool();
        break;
      case 12:
        out.mtime = r.readBool();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

/** UndoStatus：undo/redo 为空串表示对应方向不可操作 */
export interface UndoStatus {
  undo: string;
  redo: string;
  lastStep: number;
}

export function decodeUndoStatus(bytes: Uint8Array): UndoStatus {
  const r = new ProtoReader(bytes);
  const out: UndoStatus = { undo: '', redo: '', lastStep: 0 };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.undo = r.readString();
        break;
      case 2:
        out.redo = r.readString();
        break;
      case 3:
        out.lastStep = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

/** OpChangesAfterUndo：Undo/Redo 的响应 */
export interface OpChangesAfterUndo {
  changes: OpChanges | null;
  operation: string;
  revertedToTimestamp: number;
  newStatus: UndoStatus | null;
  counter: number;
}

export function decodeOpChangesAfterUndo(bytes: Uint8Array): OpChangesAfterUndo {
  const r = new ProtoReader(bytes);
  const out: OpChangesAfterUndo = {
    changes: null,
    operation: '',
    revertedToTimestamp: 0,
    newStatus: null,
    counter: 0
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.changes = decodeOpChanges(r.readBytes());
        break;
      case 2:
        out.operation = r.readString();
        break;
      case 3:
        out.revertedToTimestamp = r.readInt64();
        break;
      case 4:
        out.newStatus = decodeUndoStatus(r.readBytes());
        break;
      case 5:
        out.counter = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

/** CheckDatabaseResponse：问题列表，空数组表示检查通过 */
export function decodeCheckDatabaseResponse(bytes: Uint8Array): string[] {
  const r = new ProtoReader(bytes);
  const problems: string[] = [];
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      problems.push(r.readString());
    } else {
      r.skipField(tag.wireType);
    }
  }
  return problems;
}
