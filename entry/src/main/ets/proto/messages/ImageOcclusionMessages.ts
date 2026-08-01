// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface ImageOcclusionFieldIndexes {
  occlusions: number;
  image: number;
  header: number;
  backExtra: number;
}

export interface GetImageForOcclusionResponse {
  data: Uint8Array;
  name: string;
}

export function encodeGetImageOcclusionFieldsRequest(notetypeId: number): Uint8Array {
  const writer = new 协议写入器();
  if (notetypeId !== 0) {
    writer.写入64位整数(1, notetypeId);
  }
  return writer.转为字节();
}

function decodeImageOcclusionFieldIndexes(bytes: Uint8Array): ImageOcclusionFieldIndexes {
  const reader = new 协议读取器(bytes);
  const result: ImageOcclusionFieldIndexes = { occlusions: 0, image: 0, header: 0, backExtra: 0 };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        result.occlusions = reader.读取变长整数();
        break;
      case 2:
        result.image = reader.读取变长整数();
        break;
      case 3:
        result.header = reader.读取变长整数();
        break;
      case 4:
        result.backExtra = reader.读取变长整数();
        break;
      default:
        reader.跳过字段(tag.线类型);
    }
  }
  return result;
}

export function decodeGetImageOcclusionFieldsResponse(bytes: Uint8Array): ImageOcclusionFieldIndexes {
  const reader = new 协议读取器(bytes);
  let result: ImageOcclusionFieldIndexes = { occlusions: 0, image: 0, header: 0, backExtra: 0 };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      result = decodeImageOcclusionFieldIndexes(reader.读取字节());
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return result;
}

export function encodeGetImageForOcclusionRequest(path: string): Uint8Array {
  const writer = new 协议写入器();
  if (path !== '') {
    writer.写入字符串(1, path);
  }
  return writer.转为字节();
}

export function decodeGetImageForOcclusionResponse(bytes: Uint8Array): GetImageForOcclusionResponse {
  const reader = new 协议读取器(bytes);
  const result: GetImageForOcclusionResponse = { data: new Uint8Array(0), name: '' };
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        result.data = reader.读取字节();
        break;
      case 2:
        result.name = reader.读取字符串();
        break;
      default:
        reader.跳过字段(tag.线类型);
    }
  }
  return result;
}
