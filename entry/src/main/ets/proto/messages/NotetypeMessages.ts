// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID PROTO-MSG-NOTETYPE-001
// @名称 笔记类型消息编解码
//
// @作用
// 只读解码 anki.notetypes.proto 消息（Anki 26.05），服务于「添加卡片」动态字段：
// - NotetypeView：笔记类型视图（id/name/fields，按 ord 排序）
// - NotetypeNames：所有笔记类型的 id+name 列表
// 字段来源：third_party/anki/proto/anki/notetypes.proto
//
// @输入
// 编码：notetypeId
// 解码：字节流
//
// @输出
// 编码：Uint8Array 字节（NotetypeId 子消息）
// 解码：NotetypeView / NotetypeNameId[]
//
// @业务规则
// 解码：NotetypeView / NotetypeNameId[]
// 编码：UpdateNotetypeLegacyRequest（JSON 路径整体更新，不走完整 Notetype proto 编码）
// NotetypeField.ord 解码后用作排序键，确保字段顺序与 Anki 桌面端一致。
// NotetypeField 内的 Field config 等子字段只读跳过。
//
// @副作用
// 无
// ========================================================

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface NotetypeNameId {
  id: number;
  name: string;
}

export interface NotetypeField {
  ord: number;
  name: string;
}

export interface NotetypeView {
  id: number;
  name: string;
  fields: NotetypeField[];
  fieldNames: string[];
}

export function encodeNotetypeId(id: number): Uint8Array {
  const writer = new 协议写入器();
  if (id !== 0) {
    writer.写入64位整数(1, id);
  }
  return writer.转为字节();
}

/** 标准笔记类型种类（与 anki.notetypes.proto StockNotetype.Kind 一一对应） */
export const 标准笔记类型种类 = {
  BASIC: 0,
  BASIC_AND_REVERSED: 1,
  BASIC_OPTIONAL_REVERSED: 2,
  BASIC_TYPING: 3,
  CLOZE: 4,
  IMAGE_OCCLUSION: 5
} as const;

/** 编码 StockNotetype{kind}：字段 1 为 varint Kind 枚举。 */
export function encodeStockNotetype(kind: number): Uint8Array {
  const writer = new 协议写入器();
  if (kind !== 0) {
    writer.写入变长整数(1, kind);
  }
  return writer.转为字节();
}

/** 解码 generic.Json（字段 1 为 JSON 字符串）。 */
export function decodeJsonString(bytes: Uint8Array): string {
  const reader = new 协议读取器(bytes);
  let value = '';
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      value = reader.读取字符串();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return value;
}

/** 编码 generic.Json{json}：字段 1 为 JSON 字符串。 */
export function encodeJsonString(json: string): Uint8Array {
  const writer = new 协议写入器();
  if (json.length > 0) {
    writer.写入字符串(1, json);
  }
  return writer.转为字节();
}

function decodeUInt32(bytes: Uint8Array): number {
  const reader = new 协议读取器(bytes);
  let value = 0;
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      value = reader.读取变长整数();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return value;
}

function decodeNotetypeField(bytes: Uint8Array): NotetypeField {
  const reader = new 协议读取器(bytes);
  const field: NotetypeField = { ord: 0, name: '' };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      field.ord = decodeUInt32(reader.读取字节());
    } else if (tag.字段号 === 2) {
      field.name = reader.读取字符串();
    } else {
      // Field config and any future fields are read-only for this flow.
      reader.跳过字段(tag.线类型);
    }
  }
  return field;
}

export function decodeNotetype(bytes: Uint8Array): NotetypeView {
  const reader = new 协议读取器(bytes);
  const result: NotetypeView = { id: 0, name: '', fields: [], fieldNames: [] };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      result.id = reader.读取64位整数();
    } else if (tag.字段号 === 2) {
      result.name = reader.读取字符串();
    } else if (tag.字段号 === 8) {
      result.fields.push(decodeNotetypeField(reader.读取字节()));
    } else {
      // This UI never writes Notetype protobufs, so preserve its source bytes in Anki.
      reader.跳过字段(tag.线类型);
    }
  }
  result.fields.sort((left: NotetypeField, right: NotetypeField): number => left.ord - right.ord);
  result.fieldNames = result.fields.map((field: NotetypeField): string => field.name);
  return result;
}

function decodeNotetypeNameId(bytes: Uint8Array): NotetypeNameId {
  const reader = new 协议读取器(bytes);
  const result: NotetypeNameId = { id: 0, name: '' };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      result.id = reader.读取64位整数();
    } else if (tag.字段号 === 2) {
      result.name = reader.读取字符串();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return result;
}

export function decodeNotetypeNames(bytes: Uint8Array): NotetypeNameId[] {
  const reader = new 协议读取器(bytes);
  const entries: NotetypeNameId[] = [];
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      entries.push(decodeNotetypeNameId(reader.读取字节()));
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return entries;
}

/**
 * 编码 UpdateNotetypeLegacyRequest{json: bytes, skip_checks: bool}。
 * 用于 UpdateNotetypeLegacy RPC（方法号 3），走 JSON 路径整体更新笔记类型，
 * 避免前端编写完整 Notetype protobuf。
 * proto 定义：anki/notetypes.proto UpdateNotetypeLegacyRequest
 */
export function encodeUpdateNotetypeLegacyRequest(json: string, skipChecks: boolean): Uint8Array {
  const writer = new 协议写入器();
  if (json.length > 0) {
    // bytes json = 1（wire type 2，与 string 编码方式一致）
    writer.写入字符串(1, json);
  }
  if (skipChecks) {
    writer.写入布尔(2, skipChecks);
  }
  return writer.转为字节();
}
