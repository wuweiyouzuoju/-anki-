// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 服务号, 统计方法 } from './服务索引';
import type { GraphsView } from '../proto/messages/StatsMessages';
import { decodeGraphsResponse, encodeGraphsRequest } from '../proto/messages/StatsMessages';

export class 统计服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取图表统计(天数: number): Promise<GraphsView> {
    const 请求字节: Uint8Array = encodeGraphsRequest(天数);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端统计, 统计方法.图表, 请求字节);
    return decodeGraphsResponse(响应字节);
  }
}
