// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-MEDIA-001
// @名称 媒体服务边界
//
// @作用
// 包装后端媒体服务的 添加媒体文件 RPC：把字节写入 collection.media 并返回最终文件名。
// 编解码内联（无独立 MediaMessages 文件），经 后端会话 调用；不持有 UI 状态。
//
// @输入
// 添加媒体文件：文件名（期望名，string）/ 字节（Uint8Array）
//
// @输出
// 添加媒体文件：Promise<string>（最终写入 collection.media 的文件名）
//
// @业务规则
// AddMediaFileRequest { desired_name: string = 1; data: bytes = 2 }。
// 返回 generic.String { val: string = 1 }，val 即最终文件名。
// proto3 默认值（空串）不在网络上传输。
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥；会在 collection.media 目录写入新文件。
// ========================================================

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

/** 图片遮盖建卡流程中把图片写入 collection.media 的后端边界。 */
export class 媒体服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 添加媒体文件(文件名: string, 字节: Uint8Array): Promise<string> {
    const 响应字节 = await this.会话.调用(
      服务号.后端媒体, 媒体方法.添加媒体文件, encodeAddMediaFileRequest(文件名, 字节));
    return decodeString(响应字节);
  }
}
