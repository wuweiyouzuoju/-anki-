// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 卡片方法, 服务号 } from './服务索引';
import type { Card } from '../proto/messages/CardsMessages';
import {
  decodeCard,
  decodeRemoveCardsResponse,
  decodeSetDeckResponse,
  decodeSetFlagResponse,
  decodeUpdateCardsResponse,
  encodeCardId,
  encodeRemoveCardsRequest,
  encodeSetDeckRequest,
  encodeSetFlagRequest,
  encodeUpdateCardsRequest
} from '../proto/messages/CardsMessages';
import type { OpChanges } from '../proto/messages/CollectionMessages';

export class 卡片服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取卡片(卡片ID: number): Promise<Card> {
    const 响应字节 = await this.会话.调用(
      服务号.后端卡片, 卡片方法.获取卡片, encodeCardId(卡片ID));
    return decodeCard(响应字节);
  }

  async 更新卡片(卡片列表: Card[], 跳过撤销栈: boolean = false): Promise<OpChanges> {
    const 响应字节 = await this.会话.调用(
      服务号.后端卡片, 卡片方法.更新卡片,
      encodeUpdateCardsRequest(卡片列表, 跳过撤销栈));
    return decodeUpdateCardsResponse(响应字节);
  }

  async 删除卡片(卡片ID列表: number[]): Promise<number> {
    const 响应字节 = await this.会话.调用(
      服务号.后端卡片, 卡片方法.删除卡片, encodeRemoveCardsRequest(卡片ID列表));
    return decodeRemoveCardsResponse(响应字节);
  }

  async 设置牌组(卡片ID列表: number[], 牌组ID: number): Promise<number> {
    const 响应字节 = await this.会话.调用(
      服务号.后端卡片, 卡片方法.设置牌组, encodeSetDeckRequest(卡片ID列表, 牌组ID));
    return decodeSetDeckResponse(响应字节);
  }

  async 设置标志(卡片ID列表: number[], 标志: number): Promise<number> {
    const 响应字节 = await this.会话.调用(
      服务号.后端卡片, 卡片方法.设置标志, encodeSetFlagRequest(卡片ID列表, 标志));
    return decodeSetFlagResponse(响应字节);
  }
}
