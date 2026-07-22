// SPDX-License-Identifier: AGPL-3.0-or-later

// Anki 26.05 AnkiwebService 边界。
// 包装 BackendAnkiwebService 的 2 个 RPC：
//   - GetAddonInfo：从 AnkiWeb 拉取 addon 元信息（最多 25 个/次）
//   - CheckForUpdate：检查 Anki 客户端更新
// backend.rs 内部会通过 HTTP 调用 services.ankiweb.net，jidecards 不直接处理网络。

import { BackendSession } from './BackendSession';
import { ANKIWEB_METHOD, SERVICE } from './ServiceIds';
import {
  decodeCheckForUpdateResponse,
  decodeGetAddonInfoResponse,
  encodeCheckForUpdateRequest,
  encodeGetAddonInfoRequest
} from '../proto/messages/AnkiwebMessages';
import type {
  CheckForUpdateRequest,
  CheckForUpdateResponse,
  GetAddonInfoResponse
} from '../proto/messages/AnkiwebMessages';

export class AnkiwebService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 拉取 AnkiWeb addon 元信息。
   * AnkiWeb 限制：单次最多 25 个 addon id。
   * 没有匹配客户端版本的 addon 不会出现在响应里。
   */
  async getAddonInfo(clientVersion: number, addonIds: number[]): Promise<GetAddonInfoResponse> {
    if (addonIds.length > 25) {
      throw new Error(`AnkiWeb GetAddonInfo: max 25 addon ids per call, got ${addonIds.length}`);
    }
    const response = await this.session.run(
      SERVICE.BACKEND_ANKIWEB,
      ANKIWEB_METHOD.GET_ADDON_INFO,
      encodeGetAddonInfoRequest({ clientVersion, addonIds })
    );
    return decodeGetAddonInfoResponse(response);
  }

  /**
   * 检查 Anki 客户端更新。
   * 入参 client_version/buildhash/os/install_id 用于上报客户端信息；
   * 出参 new_version 为空串表示无需更新。
   */
  async checkForUpdate(req: CheckForUpdateRequest): Promise<CheckForUpdateResponse> {
    const response = await this.session.run(
      SERVICE.BACKEND_ANKIWEB,
      ANKIWEB_METHOD.CHECK_FOR_UPDATE,
      encodeCheckForUpdateRequest(req)
    );
    return decodeCheckForUpdateResponse(response);
  }
}
