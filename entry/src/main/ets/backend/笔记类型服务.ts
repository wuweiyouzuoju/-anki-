// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 笔记类型方法, 服务号 } from './服务索引';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';
import {
  decodeNotetype,
  decodeNotetypeNames,
  encodeNotetypeId
} from '../proto/messages/NotetypeMessages';

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
