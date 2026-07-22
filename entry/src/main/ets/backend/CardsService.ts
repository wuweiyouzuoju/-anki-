import { BackendSession } from './BackendSession';
import { CARDS_METHOD, SERVICE } from './ServiceIds';
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

/**
 * Anki 26.05 BackendCardsService 边界。
 * 覆盖 5 个方法：GetCard / UpdateCards / RemoveCards / SetDeck / SetFlag。
 * 不持有 UI 状态；UI 通过返回值感知变更。
 *
 * 编号来源：backend.rs line 6672 run_backend_cards_service_method
 *   0 GetCard / 1 UpdateCards / 2 RemoveCards / 3 SetDeck / 4 SetFlag
 */
export class CardsService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /** 获取单张卡片完整信息（含调度状态、FSRS memory_state 等） */
  async getCard(cardId: number): Promise<Card> {
    const response = await this.session.run(
      SERVICE.BACKEND_CARDS, CARDS_METHOD.GET_CARD, encodeCardId(cardId));
    return decodeCard(response);
  }

  /**
   * 批量更新卡片字段。只传需要修改的字段，其余字段由 backend 保留原值。
   * 注意：FSRS memory_state / desired_retention / decay / last_review_time 等字段
   * 由 backend 维护，前端不在 UpdateCards 中回写。
   * @param cards 待更新卡片列表（必须含 id）
   * @param skipUndoEntry true 表示此操作不进入 undo 栈（用于批量操作）
   * @returns OpChanges 标记哪些实体类型受影响（card / note / deck 等）
   */
  async updateCards(cards: Card[], skipUndoEntry: boolean = false): Promise<OpChanges> {
    const response = await this.session.run(
      SERVICE.BACKEND_CARDS, CARDS_METHOD.UPDATE_CARDS,
      encodeUpdateCardsRequest(cards, skipUndoEntry));
    return decodeUpdateCardsResponse(response);
  }

  /**
   * 删除卡片（连同其所属笔记的关联）。
   * 若笔记只剩这一张卡片，笔记也会被删除。
   * @returns 实际删除的卡片数
   */
  async removeCards(cardIds: number[]): Promise<number> {
    const response = await this.session.run(
      SERVICE.BACKEND_CARDS, CARDS_METHOD.REMOVE_CARDS, encodeRemoveCardsRequest(cardIds));
    return decodeRemoveCardsResponse(response);
  }

  /**
   * 将多张卡片移动到指定牌组。
   * @returns 实际移动的卡片数
   */
  async setDeck(cardIds: number[], deckId: number): Promise<number> {
    const response = await this.session.run(
      SERVICE.BACKEND_CARDS, CARDS_METHOD.SET_DECK, encodeSetDeckRequest(cardIds, deckId));
    return decodeSetDeckResponse(response);
  }

  /**
   * 设置卡片标志（红/橙/绿/蓝）。
   * Anki flag 取值：0=无 / 1=红 / 2=橙 / 3=绿 / 4=蓝
   * @returns 实际设置标志的卡片数
   */
  async setFlag(cardIds: number[], flag: number): Promise<number> {
    const response = await this.session.run(
      SERVICE.BACKEND_CARDS, CARDS_METHOD.SET_FLAG, encodeSetFlagRequest(cardIds, flag));
    return decodeSetFlagResponse(response);
  }
}
