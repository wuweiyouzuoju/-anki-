// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-NOTETYPE-001
// @名称 笔记类型服务边界
//
// @作用
// 包装后端笔记类型服务的 7 个 RPC：
// - 获取笔记类型名列表 / 获取笔记类型 / 获取笔记类型旧版（只读）
// - 获取标准笔记类型JSON / 添加笔记类型旧版（用于兜底恢复缺失的标准类型）
// - 更新笔记类型旧版（T3 模板编辑器整体提交）
// - 移除笔记类型（T3 模板编辑器删除类型）
// 编解码 + 经 后端会话 调用；不持有 UI 状态。
//
// @输入
// ID（笔记类型 ID，number）/ kind（标准类型枚举，number）/ json（旧版 JSON 字符串）
//
// @输出
// Promise<NotetypeNameId[]> / Promise<NotetypeView>
// Promise<string>（标准类型 JSON / 旧版 JSON）/ Promise<number>（新类型 ID）
// Promise<void>（更新/移除，成功无返回值）
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥；只读方法不修改 collection，写入方法会修改。
// ========================================================

import { 后端会话 } from './后端会话';
import { 笔记类型方法, 服务号 } from './服务索引';
import type { NotetypeNameId, NotetypeView } from '../proto/messages/NotetypeMessages';
import {
  decodeNotetype,
  decodeNotetypeNames,
  decodeJsonString,
  encodeNotetypeId,
  encodeJsonString,
  encodeStockNotetype,
  encodeUpdateNotetypeLegacyRequest
} from '../proto/messages/NotetypeMessages';

/** AddNotePanel 所属页面使用的 Anki 笔记类型边界。 */
export class 笔记类型服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取笔记类型名列表(): Promise<NotetypeNameId[]> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取笔记类型名列表, new Uint8Array(0));
    return decodeNotetypeNames(响应字节);
  }

  async 获取笔记类型(ID: number): Promise<NotetypeView> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取笔记类型, encodeNotetypeId(ID));
    return decodeNotetype(响应字节);
  }

  /**
   * 获取标准笔记类型的 JSON 表示（Anki 桌面版「管理笔记类型 → 添加 → 选择基础类型」同款流程第一步）。
   * kind 取值见 标准笔记类型种类。
   */
  async 获取标准笔记类型JSON(kind: number): Promise<string> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取标准笔记类型JSON, encodeStockNotetype(kind));
    return decodeJsonString(响应字节);
  }

  /**
   * 用旧版 JSON 添加笔记类型到 collection（GetStockNotetypeLegacy 拿到的 JSON 直接传入即可）。
   * 返回新笔记类型的 ID。失败以 后端错误 抛出。
   */
  async 添加笔记类型旧版(json: string): Promise<number> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.添加笔记类型旧版, encodeJsonString(json));
    // 旧版 add 返回 generic.Json，其字段 1 为新笔记类型 id 的 JSON 字符串（如 "1"）。
    const idText = decodeJsonString(响应字节);
    const id = Number.parseInt(idText, 10);
    return Number.isFinite(id) ? id : 0;
  }

  /**
   * 获取笔记类型的完整 JSON 表示（含 fields/templates/css/config）。
   * T3 模板编辑器加载初始数据用。失败以 后端错误 抛出。
   */
  async 获取笔记类型旧版(ID: number): Promise<string> {
    const 响应字节 = await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.获取笔记类型旧版, encodeNotetypeId(ID));
    return decodeJsonString(响应字节);
  }

  /**
   * 用旧版 JSON 更新笔记类型（整体提交字段/模板/CSS 的修改）。
   * 走 JSON 路径避免前端编写完整 Notetype protobuf。
   * 成功无返回值（后端返回 OpChanges，前端只需知道不报错即成功）。
   * 失败以 后端错误 抛出。
   */
  async 更新笔记类型旧版(json: string, skipChecks: boolean = false): Promise<void> {
    await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.更新笔记类型旧版,
      encodeUpdateNotetypeLegacyRequest(json, skipChecks));
  }

  /**
   * 删除笔记类型。后端会递归删除使用该类型的所有卡片和笔记。
   * 成功无返回值。失败以 后端错误 抛出。
   */
  async 移除笔记类型(ID: number): Promise<void> {
    await this.会话.调用(
      服务号.后端笔记类型, 笔记类型方法.移除笔记类型, encodeNotetypeId(ID));
  }
}
