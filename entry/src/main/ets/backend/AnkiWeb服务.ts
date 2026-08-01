// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { AnkiWeb方法, 服务号 } from './服务索引';
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

export class AnkiWeb服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取插件信息(客户端版本号: number, 插件ID列表: number[]): Promise<GetAddonInfoResponse> {
    if (插件ID列表.length > 25) {
      throw new Error(`AnkiWeb GetAddonInfo: max 25 addon ids per call, got ${插件ID列表.length}`);
    }
    const 响应字节 = await this.会话.调用(
      服务号.后端AnkiWeb,
      AnkiWeb方法.获取插件信息,
      encodeGetAddonInfoRequest({ clientVersion: 客户端版本号, addonIds: 插件ID列表 })
    );
    return decodeGetAddonInfoResponse(响应字节);
  }

  async 检查更新(请求参数: CheckForUpdateRequest): Promise<CheckForUpdateResponse> {
    const 响应字节 = await this.会话.调用(
      服务号.后端AnkiWeb,
      AnkiWeb方法.检查更新,
      encodeCheckForUpdateRequest(请求参数)
    );
    return decodeCheckForUpdateResponse(响应字节);
  }
}
