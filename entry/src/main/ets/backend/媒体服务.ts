// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 媒体方法, 服务号 } from './服务索引';
import { 协议读取器 } from '../proto/core/ProtoReader';
import { 协议写入器 } from '../proto/core/ProtoWriter';

function encodeAddMediaFileRequest(文件名: string, 字节: Uint8Array): Uint8Array {
  const writer = new 协议写入器();
  if (文件名 !== '') {
    writer.写入字符串(1, 文件名);
  }
  writer.写入字节(2, 字节);
  return writer.转为字节();
}

function decodeString(bytes: Uint8Array): string {
  const reader = new 协议读取器(bytes);
  let val = '';
  let tag;
  while ((tag = reader.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      val = reader.读取字符串();
    } else {
      reader.跳过字段(tag.线类型);
    }
  }
  return val;
}

export class 媒体服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 添加媒体文件(文件名: string, 字节: Uint8Array): Promise<string> {
    const 响应字节 = await this.会话.调用(
      服务号.后端媒体, 媒体方法.添加媒体文件, encodeAddMediaFileRequest(文件名, 字节));
    return decodeString(响应字节);
  }
}
