// SPDX-License-Identifier: AGPL-3.0-or-later

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
