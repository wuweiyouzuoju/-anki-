// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface EditableNote {
  id: number;
  guid: string;
  notetypeId: number;
  mtimeSecs: number;
  usn: number;
  tags: string[];
  fields: string[];
}

export interface DeckAndNotetype {
  deckId: number;
  notetypeId: number;
}

export enum NoteFieldsCheckState {
  NORMAL = 0,
  EMPTY = 1,
  DUPLICATE = 2,
  MISSING_CLOZE = 3,
  NOTETYPE_NOT_CLOZE = 4,
  FIELD_NOT_CLOZE = 5
}

export interface NoteFieldsCheckResponse {
  state: NoteFieldsCheckState;
}

export function encodeNote(note: EditableNote): Uint8Array {
  const writer = new 协议写入器();
  if (note.id !== 0) {
    writer.写入64位整数(1, note.id);
  }
  if (note.guid !== '') {
    writer.写入字符串(2, note.guid);
  }
  if (note.notetypeId !== 0) {
    writer.写入64位整数(3, note.notetypeId);
  }
  if (note.mtimeSecs !== 0) {
    writer.写入变长整数(4, note.mtimeSecs);
  }
  if (note.usn !== 0) {
    writer.写入64位整数(5, note.usn);
  }
  for (const tag of note.tags) {
    if (tag !== '') {
      writer.写入字符串(6, tag);
    }
  }
  for (const field of note.fields) {
    writer.写入字符串(7, field);
  }
  return writer.转为字节();
}

export function decodeNote(bytes: Uint8Array): EditableNote {
  const reader = new 协议读取器(bytes);
  const note: EditableNote = {
    id: 0,
    guid: '',
    notetypeId: 0,
    mtimeSecs: 0,
    usn: 0,
    tags: [],
    fields: []
  };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        note.id = reader.读取64位整数();
        break;
      case 2:
        note.guid = reader.读取字符串();
        break;
      case 3:
        note.notetypeId = reader.读取64位整数();
        break;
      case 4:
        note.mtimeSecs = reader.读取变长整数();
        break;
      case 5:
        note.usn = reader.读取64位整数();
        break;
      case 6:
        note.tags.push(reader.读取字符串());
        break;
      case 7:
        note.fields.push(reader.读取字符串());
        break;
      default:
        reader.跳过字段(tag.线类型);
    }
  }
  return note;
}

export function encodeNoteId(noteId: number): Uint8Array {
  const writer = new 协议写入器();
  if (noteId !== 0) {
    writer.写入64位整数(1, noteId);
  }
  return writer.转为字节();
}

export function encodeAddNoteRequest(note: EditableNote, deckId: number): Uint8Array {
  const writer = new 协议写入器();
  writer.写入字节(1, encodeNote(note));
  if (deckId !== 0) {
    writer.写入64位整数(2, deckId);
  }
  return writer.转为字节();
}

export function decodeAddNoteResponse(bytes: Uint8Array): number {
  const reader = new 协议读取器(bytes);
  let noteId = 0;
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 2) {
      noteId = reader.读取64位整数();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return noteId;
}

export function encodeDefaultsForAddingRequest(homeDeckOfCurrentReviewCard: number = 0): Uint8Array {
  const writer = new 协议写入器();
  if (homeDeckOfCurrentReviewCard !== 0) {
    writer.写入64位整数(1, homeDeckOfCurrentReviewCard);
  }
  return writer.转为字节();
}

export function decodeDeckAndNotetype(bytes: Uint8Array): DeckAndNotetype {
  const reader = new 协议读取器(bytes);
  const result: DeckAndNotetype = { deckId: 0, notetypeId: 0 };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      result.deckId = reader.读取64位整数();
    } else if (tag.字段号 === 2) {
      result.notetypeId = reader.读取64位整数();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return result;
}

export function decodeNoteFieldsCheckResponse(bytes: Uint8Array): NoteFieldsCheckResponse {
  const reader = new 协议读取器(bytes);
  let state: NoteFieldsCheckState = NoteFieldsCheckState.NORMAL;
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      state = reader.读取变长整数() as NoteFieldsCheckState;
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return { state };
}
