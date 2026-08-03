// SPDX-License-Identifier: AGPL-3.0-or-later
// ========================================================
// @块ID MODEL-SYNC-STORE-001
// @名称 同步面板状态机
//
// @作用
// 集中托管 AnkiWeb 云同步弹窗的显隐状态与认证信息。
// 由 首页 实例化、@Provide 注入；同步面板 @Consume 取用。
//
// @输入
// 打开(认证, 账号名) / 关闭()
//
// @输出
// 持有 显示 / 认证 / 账号名 三个字段
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*
// 同步流程本身在 同步面板 组件内执行，本 store 只管弹窗显隐与认证传递。
//
// @副作用
// 无（仅修改内部状态字段）。
//
// @注意
// 当前为 Phase 2 完整实现（逻辑足够简单）。
// ========================================================
import type { SyncAuth } from '../proto/messages/SyncMessages';

export class 同步面板状态机 {
  public 显示: boolean = false;
  public 认证: SyncAuth | null = null;
  public 账号名: string = '';

  public 打开(认证: SyncAuth, 账号名: string): void {
    this.认证 = 认证;
    this.账号名 = 账号名;
    this.显示 = true;
  }

  public 关闭(): void {
    this.显示 = false;
    this.认证 = null;
    this.账号名 = '';
  }
}
