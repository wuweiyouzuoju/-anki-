// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 牌组方法, 服务号 } from './服务索引';
import type { Deck, DeckTreeNode } from '../proto/messages/DeckMessages';
import { decodeDeck, decodeDeckTreeNode, encodeDeck, encodeDeckIds, encodeDeckTreeRequest, encodeRenameDeckRequest } from '../proto/messages/DeckMessages';
import { decodeOpChangesWithCount, decodeOpChangesWithId } from '../proto/messages/CollectionMessages';

export class 牌组服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取牌组树(): Promise<DeckTreeNode> {
    const 当前秒数: number = Math.floor(Date.now() / 1000);
    const 请求: Uint8Array = encodeDeckTreeRequest(当前秒数);
    const 响应: Uint8Array = await this.会话.调用(
      服务号.后端牌组, 牌组方法.牌组树, 请求);
    return decodeDeckTreeNode(响应);
  }

  async 创建牌组(名称: string): Promise<number> {
    const 模板字节: Uint8Array = await this.会话.调用(
      服务号.后端牌组, 牌组方法.新建牌组, new Uint8Array(0));
    const 模板: Deck = decodeDeck(模板字节);
    模板.id = 0;
    模板.name = 名称;
    const 已添加: Uint8Array = await this.会话.调用(
      服务号.后端牌组, 牌组方法.添加牌组, encodeDeck(模板));
    return decodeOpChangesWithId(已添加);
  }

  async 重命名牌组(牌组ID: number, 新名称: string): Promise<void> {
    const 请求: Uint8Array = encodeRenameDeckRequest(牌组ID, 新名称);
    await this.会话.调用(
      服务号.后端牌组, 牌组方法.重命名牌组, 请求);
  }

  async 删除牌组(牌组ID列表: number[]): Promise<number> {
    const 请求: Uint8Array = encodeDeckIds(牌组ID列表);
    const 响应: Uint8Array = await this.会话.调用(
      服务号.后端牌组, 牌组方法.删除牌组, 请求);
    return decodeOpChangesWithCount(响应);
  }
}
