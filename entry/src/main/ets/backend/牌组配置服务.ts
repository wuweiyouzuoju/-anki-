// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 牌组配置方法, 服务号 } from './服务索引';
import { encodeDeckId } from '../proto/messages/DeckMessages';
import type {
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import {
  decodeDeckConfigsForUpdate,
  encodeUpdateDeckConfigsRequest
} from '../proto/messages/DeckConfigMessages';

export class 牌组配置服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取牌组配置编辑视图(牌组ID: number): Promise<DeckConfigsForUpdateView> {
    const 请求: Uint8Array = encodeDeckId(牌组ID);
    const 响应: Uint8Array = await this.会话.调用(
      服务号.后端牌组配置, 牌组配置方法.获取牌组配置编辑视图, 请求);
    return decodeDeckConfigsForUpdate(响应);
  }

  async 更新牌组配置(请求: UpdateDeckConfigsInput): Promise<void> {
    const 编码字节: Uint8Array = encodeUpdateDeckConfigsRequest(请求);
    await this.会话.调用(
      服务号.后端牌组配置, 牌组配置方法.更新牌组配置, 编码字节);
  }
}
