// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-NOTETYPE-001
// @名称 笔记类型服务边界
//
// @作用
// 包装后端笔记类型服务的 2 个 RPC：获取笔记类型名列表 / 获取笔记类型。
// 编解码 + 经 后端会话 调用；不持有 UI 状态。
//
// @输入
// ID（笔记类型 ID，number）
//
// @输出
// Promise<NotetypeNameId[]> / Promise<NotetypeView>
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥，仅读取 Anki collection 中的笔记类型定义。
// ========================================================

import { 后端会话 } from './后端会话';
import { 笔记类型方法, 服务号 } from './服务索引';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';
import {
  decodeNotetype,
  decodeNotetypeNames,
  encodeNotetypeId
} from '../proto/messages/NotetypeMessages';

/** AddNotePanel 所属页面使用的只读 Anki 笔记类型边界。 */
export class 笔记类型服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取笔记类型名列表(): Promise<NotetypeNameId[]> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取笔记类型名列表, new Uint8Array(0));
    return decodeNotetypeNames(响应字节);
  }

  async 获取笔记类型(ID: number): Promise<NotetypeView> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取笔记类型, encodeNotetypeId(ID));
    return decodeNotetype(响应字节);
  }
}
