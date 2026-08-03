// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-STATS-001
// @名称 统计服务边界
//
// @作用
// 包装后端统计服务的 1 个 RPC：获取图表统计。
// 一次 Graphs 调用同时取回按日复习计数与平均可提取率；不持有 UI 状态。
// 方法索引来源：服务索引.ts（提取自 Anki 26.05 生成代码 backend.rs）。
//
// @输入
// 天数（number，回看天数；0=全部历史）
//
// @输出
// Promise<GraphsView>（含 reviewCountsByDaysAgo / retrievability，可能为 null）
//
// @业务规则
// search 固定空串 → 全库统计（graph_data_for_search 的 all 分支）。
// days 限定 revlog 回看窗口（含今天共 days+1 天），首页月历只需覆盖当月。
// reviews.count 键为「距今天数」（0=今天），按 Anki 日切分点（rollover）分桶。
// retrievability.average 为 0-100 百分制，无 FSRS 记忆状态卡片时为 0。
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥，仅读取 Anki collection 的统计聚合结果。
// ========================================================

import { 后端会话 } from './后端会话';
import { 服务号, 统计方法 } from './服务索引';
import type { GraphsView } from '../proto/messages/StatsMessages';
import { decodeGraphsResponse, encodeGraphsRequest } from '../proto/messages/StatsMessages';

export class 统计服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  /**
   * 拉取全库图表统计。天数 为回看天数（0=全部历史），首页传当月已过去的天数即可。
   * 返回值中 reviewCountsByDaysAgo / retrievability 可能为 null（响应缺省字段）。
   */
  async 获取图表统计(天数: number): Promise<GraphsView> {
    const 请求字节: Uint8Array = encodeGraphsRequest(天数);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端统计, 统计方法.图表, 请求字节);
    return decodeGraphsResponse(响应字节);
  }
}
