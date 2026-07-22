// SchedulerService：复习调度域的高层调用封装（M7）。
// 职责：取卡队列（含调度状态）、按钮文案、提交评分；不持有 UI 状态。
// 方法索引来源：ServiceIds.ts（提取自 Anki 26.05 生成代码）。
//
// 链路语义（与桌面 Anki 一致）：
// - GetQueuedCards 一次只取队首 1 张（fetchLimit=1），QueuedCard.states 已含四档目标状态；
// - 按钮文案由 DescribeNextStates 本地化生成（BackendInit 已配 zh-Hans）；
// - AnswerCard 需原样回传 current/new 调度状态字节（raw passthrough，见 SchedulerMessages）。

import { BackendSession } from './BackendSession';
import { SCHEDULER_METHOD, SERVICE } from './ServiceIds';
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
import { DECKS_METHOD } from './ServiceIds';

export class SchedulerService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 拉取指定牌组的队首卡片（最多 1 张）。
   * 先 SetCurrentDeck（Anki 队列按当前牌组构建），再 GetQueuedCards。
   * 返回空 cards 表示该牌组当前无待学习卡片。
   */
  async getQueuedCards(deckId: number): Promise<QueuedCardsView> {
    await this.setCurrentDeck(deckId);
    const request: Uint8Array = encodeGetQueuedCardsRequest(1, false);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.GET_QUEUED_CARDS, request);
    return decodeQueuedCards(response);
  }

  /**
   * 获取四档评分按钮的本地化文案（如「<10 分钟」「1 天」）。
   * 入参为 QueuedCard.states 原始字节，原样回传给后端。
   */
  async describeNextStates(states: SchedulingStatesRaw): Promise<string[]> {
    const request: Uint8Array = encodeSchedulingStates(states);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.DESCRIBE_NEXT_STATES, request);
    return decodeStringList(response);
  }

  /**
   * 提交评分。newState 必须取 QueuedCard.states 对应档位字节；
   * 评分落库后队列立即变化，调用方应重新 getQueuedCards 取下一张。
   */
  async answerCard(answer: CardAnswerInput): Promise<void> {
    const request: Uint8Array = encodeCardAnswer(answer);
    await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.ANSWER_CARD, request);
  }

  /** 今日已学习卡片数/秒数上报前的计时锚点（M8 主页统计用）。 */
  async getSchedTimingToday(): Promise<SchedTimingToday> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.SCHED_TIMING_TODAY, new Uint8Array(0));
    return decodeSchedTimingToday(response);
  }

  /** 指定牌组今日已完成（新+复习）卡片数；主页「今日完成」对顶层牌组求和。 */
  async countsForDeckToday(deckId: number): Promise<DeckTodayCounts> {
    const request: Uint8Array = encodeDeckId(deckId);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.COUNTS_FOR_DECK_TODAY, request);
    return decodeCountsForDeckToday(response);
  }

  /**
   * 埋藏或暂停卡片。mode 取 BURY_SUSPEND_MODE_*：
   * 手动埋藏（BURY_USER，明天再见）/暂停（SUSPEND，手动恢复前不再出现）。
   * 成功后卡片立即离开今日队列，调用方应重新 getQueuedCards 取下一张。
   */
  async buryOrSuspendCards(cardId: number, mode: number): Promise<void> {
    const request: Uint8Array = encodeBuryOrSuspendCardsRequest([cardId], [], mode);
    await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.BURY_OR_SUSPEND, request);
  }

  /**
   * 按牌组恢复被埋藏的卡片（mode 取 UNBURY_MODE_*）。
   * CongratsInfo 只给 haveSchedBuried/haveUserBuried 标记、不给卡片 id，
   * 因此完成页的「恢复」只能按牌组维度恢复，与桌面 overview 的 unbury 一致。
   */
  async unburyDeck(deckId: number, mode: number): Promise<void> {
    const request: Uint8Array = encodeUnburyDeckRequest(deckId, mode);
    await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.UNBURY_DECK, request);
  }

  /** 按卡片 id 精确恢复埋藏/暂停卡；仅在调用方已知 id 时可用（如卡片列表多选）。 */
  async restoreBuriedAndSuspendedCards(cardIds: number[]): Promise<void> {
    const request: Uint8Array = encodeCardIds(cardIds);
    await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.RESTORE_BURIED_AND_SUSPENDED, request);
  }

  /** 完成页真实数据：剩余学习卡/到期秒数/今日上限标记/埋藏标记等。 */
  async congratsInfo(): Promise<CongratsInfo> {
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_SCHEDULER, SCHEDULER_METHOD.CONGRATS_INFO, new Uint8Array(0));
    return decodeCongratsInfo(response);
  }

  private async setCurrentDeck(deckId: number): Promise<void> {
    const request: Uint8Array = encodeDeckId(deckId);
    await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.SET_CURRENT_DECK, request);
  }
}
