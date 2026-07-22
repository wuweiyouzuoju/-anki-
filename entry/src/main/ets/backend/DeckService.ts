// DeckService：牌组域的高层调用封装（M4 起逐步扩展）。
// 职责：编解码 + 经 BackendSession 调用；不持有 UI 状态，不做数据映射。
// 数据语义见 HomeSnapshotMapper 与 third_party/anki/rslib/src/decks/tree.rs。

import { BackendSession } from './BackendSession';
import { DECKS_METHOD, SERVICE } from './ServiceIds';
import type { Deck, DeckTreeNode } from '../proto/messages/DeckMessages';
import { decodeDeck, decodeDeckTreeNode, encodeDeck, encodeDeckIds, encodeDeckTreeRequest, encodeRenameDeckRequest } from '../proto/messages/DeckMessages';
import { decodeOpChangesWithCount, decodeOpChangesWithId } from '../proto/messages/CollectionMessages';

export class DeckService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 拉取牌组树（DeckTree）。
   * 返回根节点占位（deckId=0、name=''），真实牌组在 children；
   * 每个节点的 new/learn/review 计数已按日限裁剪且包含子节点合计。
   */
  async getDeckTree(): Promise<DeckTreeNode> {
    const nowSecs: number = Math.floor(Date.now() / 1000);
    const request: Uint8Array = encodeDeckTreeRequest(nowSecs);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.DECK_TREE, request);
    return decodeDeckTreeNode(response);
  }

  /**
   * 新建牌组：NewDeck 模板 → 改名 → AddDeck，返回新牌组 id。
   * 名称支持「父::子」层级（缺失的父级由后端自动创建）。
   * 重复名等失败以 BackendError 抛出，message 可直接展示。
   */
  async createDeck(name: string): Promise<number> {
    const templateBytes: Uint8Array = await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.NEW_DECK, new Uint8Array(0));
    const template: Deck = decodeDeck(templateBytes);
    template.id = 0;
    template.name = name;
    const added: Uint8Array = await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.ADD_DECK, encodeDeck(template));
    return decodeOpChangesWithId(added);
  }

  /**
   * 重命名牌组：调用后端 rename_deck（method 18），自动级联重命名子牌组前缀。
   * 名称冲突等失败以 BackendError 抛出，message 可直接展示。
   */
  async renameDeck(deckId: number, newName: string): Promise<void> {
    const request: Uint8Array = encodeRenameDeckRequest(deckId, newName);
    await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.RENAME_DECK, request);
  }

  /**
   * 删除牌组：调用后端 remove_decks（method 16）。
   *
   * 后端语义（rslib/src/decks/remove.rs:6 remove_decks_and_child_decks）：
   * - 递归删除所有子牌组及其卡片
   * - 牌组内所有卡片会移到「已删除」状态（可通过 undo 恢复）
   * - 返回 OpChangesWithCount.count = 实际删除的牌组数（不含被级联删除的子牌组）
   *
   * 二次确认防误删（与 Anki 桌面端 deckbrowser.py:369 行为一致）。
   */
  async removeDecks(deckIds: number[]): Promise<number> {
    const request: Uint8Array = encodeDeckIds(deckIds);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_DECKS, DECKS_METHOD.REMOVE_DECKS, request);
    return decodeOpChangesWithCount(response);
  }
}
