// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-SCHED-001
// @名称 调度器服务边界
//
// @作用
// 包装后端调度器服务的 9 个 RPC：获取队首卡片 / 描述下一档状态 / 提交评分 /
// 今日计时 / 牌组今日计数 / 埋藏或暂停 / 按牌组恢复埋藏 / 恢复埋藏与暂停 / 完成页信息。
// 编解码 + 经 后端会话 调用；不持有 UI 状态。
//
// @输入
// 牌组ID / 状态字节 / 作答参数 / 卡片ID / 卡片ID列表 / 模式 等
//
// @输出
// Promise<QueuedCardsView> / Promise<string[]> / Promise<void> /
// Promise<SchedTimingToday> / Promise<DeckTodayCounts> / Promise<CongratsInfo>
//
// @业务规则
// 获取队首卡片：先 设置当前牌组（Anki 队列按当前牌组构建），再 获取队首卡片。
// 提交评分：新状态字节必须取 QueuedCard.states 对应档位字节；评分落库后队列立即变化。
// Anki flag 取值：0=无 / 1=红 / 2=橙 / 3=绿 / 4=蓝。
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥，可能修改 Anki collection 状态。
// ========================================================

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

  /**
   * 拉取指定牌组的队首卡片（最多 1 张）。
   * 先 设置当前牌组（Anki 队列按当前牌组构建），再 获取队首卡片。
   * 返回空 cards 表示该牌组当前无待学习卡片。
   */
  async 获取队首卡片(牌组ID: number): Promise<QueuedCardsView> {
    await this.设置当前牌组(牌组ID);
    const 请求字节: Uint8Array = encodeGetQueuedCardsRequest(1, false);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.获取队首卡片, 请求字节);
    return decodeQueuedCards(响应字节);
  }

  /**
   * 获取四档评分按钮的本地化文案（如「<10 分钟」「1 天」）。
   * 入参为 QueuedCard.states 原始字节，原样回传给后端。
   */
  async 描述下一档状态(状态字节: SchedulingStatesRaw): Promise<string[]> {
    const 请求字节: Uint8Array = encodeSchedulingStates(状态字节);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.描述下一档状态, 请求字节);
    return decodeStringList(响应字节);
  }

  /**
   * 提交评分。newState 必须取 QueuedCard.states 对应档位字节；
   * 评分落库后队列立即变化，调用方应重新 获取队首卡片 取下一张。
   */
  async 提交评分(作答参数: CardAnswerInput): Promise<void> {
    const 请求字节: Uint8Array = encodeCardAnswer(作答参数);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.提交评分, 请求字节);
  }

  /** 今日已学习卡片数/秒数上报前的计时锚点（M8 主页统计用）。 */
  async 获取今日计时(): Promise<SchedTimingToday> {
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.今日计时, new Uint8Array(0));
    return decodeSchedTimingToday(响应字节);
  }

  /** 指定牌组今日已完成（新+复习）卡片数；主页「今日完成」对顶层牌组求和。 */
  async 获取牌组今日计数(牌组ID: number): Promise<DeckTodayCounts> {
    const 请求字节: Uint8Array = encodeDeckId(牌组ID);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端调度器, 调度器方法.牌组今日计数, 请求字节);
    return decodeCountsForDeckToday(响应字节);
  }

  /**
   * 埋藏或暂停卡片。模式 取 BURY_SUSPEND_MODE_*：
   * 手动埋藏（BURY_USER，明天再见）/暂停（SUSPEND，手动恢复前不再出现）。
   * 成功后卡片立即离开今日队列，调用方应重新 获取队首卡片 取下一张。
   */
  async 埋藏或暂停卡片(卡片ID: number, 模式: number): Promise<void> {
    const 请求字节: Uint8Array = encodeBuryOrSuspendCardsRequest([卡片ID], [], 模式);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.埋藏或暂停, 请求字节);
  }

  /**
   * 批量埋藏或暂停卡片（浏览页 T8 批量操作栏用）。
   * 与单卡版同 RPC，只是 cardIds 传数组；encodeBuryOrSuspendCardsRequest 已支持 packed repeated int64。
   * 模式 取 BURY_SUSPEND_MODE_*（SUSPEND=0 / BURY_SCHED=1 / BURY_USER=2）。
   */
  async 批量埋藏或暂停卡片(卡片ID列表: number[], 模式: number): Promise<void> {
    const 请求字节: Uint8Array = encodeBuryOrSuspendCardsRequest(卡片ID列表, [], 模式);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.埋藏或暂停, 请求字节);
  }

  /**
   * 按牌组恢复被埋藏的卡片（模式 取 UNBURY_MODE_*）。
   * CongratsInfo 只给 haveSchedBuried/haveUserBuried 标记、不给卡片 id，
   * 因此完成页的「恢复」只能按牌组维度恢复，与桌面 overview 的 unbury 一致。
   */
  async 按牌组恢复埋藏(牌组ID: number, 模式: number): Promise<void> {
    const 请求字节: Uint8Array = encodeUnburyDeckRequest(牌组ID, 模式);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.按牌组恢复埋藏, 请求字节);
  }

  /** 按卡片 id 精确恢复埋藏/暂停卡；仅在调用方已知 id 时可用（如卡片列表多选）。 */
  async 恢复埋藏与暂停的卡片(卡片ID列表: number[]): Promise<void> {
    const 请求字节: Uint8Array = encodeCardIds(卡片ID列表);
    await this.会话.调用(
      服务号.后端调度器, 调度器方法.恢复埋藏与暂停, 请求字节);
  }

  /** 完成页真实数据：剩余学习卡/到期秒数/今日上限标记/埋藏标记等。 */
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
