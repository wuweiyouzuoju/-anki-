// SPDX-License-Identifier: AGPL-3.0-or-later

// StatsService：统计域的高层调用封装（T6 首页月历热力 + 记忆率）。
// 职责：一次 Graphs 调用同时取回按日复习计数（reviews.count map）与
// 平均可提取率（retrievability.average + fsrs 标志），不持有 UI 状态。
// 方法索引来源：ServiceIds.ts（提取自 Anki 26.05 生成代码 backend.rs）。
//
// 语义（third_party/anki/rslib/src/stats/graphs/）：
// - search 固定空串 → 全库统计（graph_data_for_search 的 all 分支）；
// - days 限定 revlog 回看窗口（含今天共 days+1 天），首页月历只需覆盖当月；
// - reviews.count 键为「距今天数」（0=今天），按 Anki 日切分点（rollover）分桶；
// - retrievability.average 为 0-100 百分制，无 FSRS 记忆状态卡片时为 0。

import { BackendSession } from './BackendSession';
import { SERVICE, STATS_METHOD } from './ServiceIds';
import type { GraphsView } from '../proto/messages/StatsMessages';
import { decodeGraphsResponse, encodeGraphsRequest } from '../proto/messages/StatsMessages';

export class StatsService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 拉取全库图表统计。days 为回看天数（0=全部历史），首页传当月已过去的天数即可。
   * 返回值中 reviewCountsByDaysAgo / retrievability 可能为 null（响应缺省字段）。
   */
  async getGraphs(days: number): Promise<GraphsView> {
    const request: Uint8Array = encodeGraphsRequest(days);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_STATS, STATS_METHOD.GRAPHS, request);
    return decodeGraphsResponse(response);
  }
}
