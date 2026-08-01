// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 调度器方法, 牌组方法, 服务号 } from './服务索引';
import type {
  CardAnswerInput,
  CongratsInfo,
  DeckTodayCounts,
  QueuedCardsView,
  SchedTimingToday,
  SchedulingStatesRaw
} from '../proto/messages/SchedulerMessages';
import {
  decodeCongratsInfo,
  decodeCountsForDeckToday,
  decodeQueuedCards,
  decodeSchedTimingToday,
  decodeStringList,
  encodeBuryOrSuspendCardsRequest,
  encodeCardAnswer,
  encodeCardIds,
  encodeGetQueuedCardsRequest,
  encodeSchedulingStates,
  encodeUnburyDeckRequest
} from '../proto/messages/SchedulerMessages';
import { encodeDeckId } from '../proto/messages/DeckMessages';

export class 调度器服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取队首卡片(牌组ID: number): Promise<QueuedCardsView> {
    await this.设置当前牌组(牌组ID);
    const 请求字节: Uint8Array = encodeGetQueuedCardsRequest(1, false);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.获取队首卡片, 请求字节);
    return decodeQueuedCards(响应字节);
  }

  async 描述下一档状态(状态字节: SchedulingStatesRaw): Promise<string[]> {
    const 请求字节: Uint8Array = encodeSchedulingStates(状态字节);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.描述下一档状态, 请求字节);
    return decodeStringList(响应字节);
  }

  async 提交评分(作答参数: CardAnswerInput): Promise<void> {
    const 请求字节: Uint8Array = encodeCardAnswer(作答参数);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.提交评分, 请求字节);
  }

  async 获取今日计时(): Promise<SchedTimingToday> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.今日计时, new Uint8Array(0));
    return decodeSchedTimingToday(响应字节);
  }

  async 获取牌组今日计数(牌组ID: number): Promise<DeckTodayCounts> {
    const 请求字节: Uint8Array = encodeDeckId(牌组ID);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.牌组今日计数, 请求字节);
    return decodeCountsForDeckToday(响应字节);
  }

  async 埋藏或暂停卡片(卡片ID: number, 模式: number): Promise<void> {
    const 请求字节: Uint8Array = encodeBuryOrSuspendCardsRequest([卡片ID], [], 模式);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.埋藏或暂停, 请求字节);
  }

  async 按牌组恢复埋藏(牌组ID: number, 模式: number): Promise<void> {
    const 请求字节: Uint8Array = encodeUnburyDeckRequest(牌组ID, 模式);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.按牌组恢复埋藏, 请求字节);
  }

  async 恢复埋藏与暂停的卡片(卡片ID列表: number[]): Promise<void> {
    const 请求字节: Uint8Array = encodeCardIds(卡片ID列表);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.恢复埋藏与暂停, 请求字节);
  }

  async 获取完成页信息(): Promise<CongratsInfo> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.完成页信息, new Uint8Array(0));
    return decodeCongratsInfo(响应字节);
  }

  private async 设置当前牌组(牌组ID: number): Promise<void> {
    const 请求字节: Uint8Array = encodeDeckId(牌组ID);
    await this.会话.调用(
      服务号.后端牌组, 牌组方法.设置当前牌组, 请求字节);
  }
}
