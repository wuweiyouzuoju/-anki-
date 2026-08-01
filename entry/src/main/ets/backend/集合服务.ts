// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 集合方法, 服务号 } from './服务索引';
import type {
  OpChangesAfterUndo,
  UndoStatus
} from '../proto/messages/CollectionMessages';
import {
  decodeCheckDatabaseResponse,
  decodeOpChangesAfterUndo,
  decodeUndoStatus
} from '../proto/messages/CollectionMessages';

export class 集合服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取撤销状态(): Promise<UndoStatus> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端集合, 集合方法.获取撤销状态, new Uint8Array(0));
    return decodeUndoStatus(响应字节);
  }

  async 撤销(): Promise<OpChangesAfterUndo> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端集合, 集合方法.撤销, new Uint8Array(0));
    return decodeOpChangesAfterUndo(响应字节);
  }

  async 重做(): Promise<OpChangesAfterUndo> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端集合, 集合方法.重做, new Uint8Array(0));
    return decodeOpChangesAfterUndo(响应字节);
  }

  async 检查数据库(): Promise<string[]> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端集合, 集合方法.检查数据库, new Uint8Array(0));
    return decodeCheckDatabaseResponse(响应字节);
  }
}
