// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-NOTE-001
// @名称 笔记服务边界
//
// @作用
// 包装后端笔记服务的 4 个 RPC：获取添加默认值 / 新建笔记 / 获取笔记 / 添加笔记。
// 添加笔记前先做字段校验，校验失败抛 笔记字段校验错误 供 UI 本地化展示。
// Anki 26.05 note creation boundary；不持有 UI draft state。
//
// @输入
// 笔记类型ID / 笔记ID / 笔记 / 牌组ID
//
// @输出
// Promise<DeckAndNotetype> / Promise<EditableNote> / Promise<number>
//
// @业务规则
// 笔记字段校验三态映射：
//   EMPTY → add_note_empty_error
//   DUPLICATE → add_note_duplicate_error
//   MISSING_CLOZE / NOTETYPE_NOT_CLOZE / FIELD_NOT_CLOZE → add_note_invalid_cloze_error
// 校验通过后才提交 ADD_NOTE；messageKey 由 UI 层本地化，不在后端边界做翻译。
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥，可能修改 Anki collection 状态。
// ========================================================

import { 后端会话 } from './后端会话';
import { 笔记方法, 服务号 } from './服务索引';
import type { DeckAndNotetype, EditableNote } from '../proto/messages/NoteMessages';
import {
  decodeAddNoteResponse,
  decodeDeckAndNotetype,
  decodeNote,
  decodeNoteFieldsCheckResponse,
  encodeAddNoteRequest,
  encodeDefaultsForAddingRequest,
  encodeNote,
  encodeNoteId
} from '../proto/messages/NoteMessages';
import { encodeNotetypeId } from '../proto/messages/NotetypeMessages';
import { NoteFieldsCheckState } from '../proto/messages/NoteMessages';

export type 笔记字段校验键 =
  'add_note_empty_error' |
  'add_note_duplicate_error' |
  'add_note_invalid_cloze_error';

/** Error with a resource key, so presentation code—not the backend boundary—localizes it. */
export class 笔记字段校验错误 extends Error {
  readonly messageKey: 笔记字段校验键;

  constructor(messageKey: 笔记字段校验键) {
    super(messageKey);
    this.messageKey = messageKey;
  }
}

function 校验键对应状态(状态: NoteFieldsCheckState): 笔记字段校验键 | null {
  switch (状态) {
    case NoteFieldsCheckState.EMPTY:
      return 'add_note_empty_error';
    case NoteFieldsCheckState.DUPLICATE:
      return 'add_note_duplicate_error';
    case NoteFieldsCheckState.MISSING_CLOZE:
    case NoteFieldsCheckState.NOTETYPE_NOT_CLOZE:
    case NoteFieldsCheckState.FIELD_NOT_CLOZE:
      return 'add_note_invalid_cloze_error';
    default:
      return null;
  }
}

export class 笔记服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取添加默认值(): Promise<DeckAndNotetype> {
    const 响应 = await this.会话.调用(
      服务号.后端笔记,
      笔记方法.添加默认值,
      encodeDefaultsForAddingRequest());
    return decodeDeckAndNotetype(响应);
  }

  async 新建笔记(笔记类型ID: number): Promise<EditableNote> {
    const 响应 = await this.会话.调用(
      服务号.后端笔记, 笔记方法.新建笔记, encodeNotetypeId(笔记类型ID));
    return decodeNote(响应);
  }

  async 获取笔记(笔记ID: number): Promise<EditableNote> {
    const 响应 = await this.会话.调用(
      服务号.后端笔记, 笔记方法.获取笔记, encodeNoteId(笔记ID));
    return decodeNote(响应);
  }

  async 添加笔记(笔记: EditableNote, 牌组ID: number): Promise<number> {
    const 校验响应 = await this.会话.调用(
      服务号.后端笔记, 笔记方法.笔记字段校验, 编码笔记用于校验(笔记));
    const 校验键 = 校验键对应状态(decodeNoteFieldsCheckResponse(校验响应).state);
    if (校验键 !== null) {
      throw new 笔记字段校验错误(校验键);
    }
    const 响应 = await this.会话.调用(
      服务号.后端笔记, 笔记方法.添加笔记, encodeAddNoteRequest(笔记, 牌组ID));
    return decodeAddNoteResponse(响应);
  }
}

function 编码笔记用于校验(笔记: EditableNote): Uint8Array {
  return encodeNote(笔记);
}
