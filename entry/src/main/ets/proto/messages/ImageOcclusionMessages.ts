// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID PROTO-MSG-IMAGEOCCLUSION-001
// @名称 图片遮罩消息编解码
//
// @作用
// 编解码 anki.image_occlusion.proto 消息（Anki 26.05），服务于「图片遮盖建卡」流程：
// - GetImageOcclusionFieldsRequest / Response：取该笔记类型 4 个字段在 fields 数组中的索引
// - ImageOcclusionFieldIndexes：occlusions / image / header / back_extra 的 uint32 索引
// - GetImageForOcclusionRequest / Response：按 path 取图片字节与最终文件名
// AddImageOcclusionNotetype 入参为 generic.Empty，无字段，由服务层直接传 new Uint8Array(0)。
// 字段来源：third_party/anki/proto/anki/image_occlusion.proto
//
// @输入
// 编码：notetypeId / path
// 解码：字节流
//
// @输出
// 编码：Uint8Array 字节
// 解码：ImageOcclusionFieldIndexes / GetImageForOcclusionResponse
//
// @业务规则
// proto3 默认值（uint32=0、string=''）不在网络上传输，解码时按默认值填充。
// ImageOcclusionFieldIndexes.occlusions=0 是合法值（字段索引 0），解码必须保留。
//
// @副作用
// 无
// ========================================================

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
