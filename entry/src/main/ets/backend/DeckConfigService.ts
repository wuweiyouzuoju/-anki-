// SPDX-License-Identifier: AGPL-3.0-or-later

// DeckConfigService：牌组选项（DeckConfig）域的高层调用封装（T4）。
// 职责：拉取编辑视图（GetDeckConfigsForUpdate）与整体回写（UpdateDeckConfigs）；
// 不持有 UI 状态，不做字段映射——三字段建模与未建模字段保真回写见 DeckConfigMessages。
//
// 保存语义对齐桌面端 deck-options（third_party/anki/ts/routes/deck-options/lib.ts）：
// 当前牌组选中的 config 始终随 configs 回传（最后一项决定牌组使用哪个预设）；
// currentDeck.limits 与全局 flag（fsrs 等）原样回传，避免静默重置。

import { BackendSession } from './BackendSession';
import { DECK_CONFIG_METHOD, SERVICE } from './ServiceIds';
import { encodeDeckId } from '../proto/messages/DeckMessages';
import type {
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import {
  decodeDeckConfigsForUpdate,
  encodeUpdateDeckConfigsRequest
} from '../proto/messages/DeckConfigMessages';

export class DeckConfigService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 拉取指定牌组的选项编辑视图：全部预设（含使用计数）、当前牌组选中项
   * （configId/limits）与全局 flag。编辑面板据此定位 currentDeck.configId
   * 对应的 DeckConfig，修改三字段（new_per_day / reviews_per_day / learn_steps）。
   */
  async getDeckConfigsForUpdate(deckId: number): Promise<DeckConfigsForUpdateView> {
    const request: Uint8Array = encodeDeckId(deckId);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_DECK_CONFIG, DECK_CONFIG_METHOD.GET_DECK_CONFIGS_FOR_UPDATE, request);
    return decodeDeckConfigsForUpdate(response);
  }

  /**
   * 整体回写牌组选项。request 需携带编辑后的 configs、当前牌组 limits
   * 与视图中的全局 flag；未建模字段经 DeckConfigMessages 保真字节回写。
   * 失败以 BackendError 抛出，message 可直接展示。
   */
  async updateDeckConfigs(request: UpdateDeckConfigsInput): Promise<void> {
    const encoded: Uint8Array = encodeUpdateDeckConfigsRequest(request);
    await this.session.run(
      SERVICE.BACKEND_DECK_CONFIG, DECK_CONFIG_METHOD.UPDATE_DECK_CONFIGS, encoded);
  }
}
