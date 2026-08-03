// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-CUSTOM-STORE-001
// @名称 牌组定制状态机
//
// @作用
// 集中托管牌组定制弹窗（色标条/别名/背景图）的显隐状态与应用逻辑。
// 由 首页 实例化、@Provide 注入；牌组定制面板 @Consume 取用。
//
// @输入
// 打开(牌组ID) / 应用(结果) / 关闭()
//
// @输出
// 持有 显示 / 牌组ID / 进行中 / 错误 字段
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*
// 实际应用逻辑在 Phase 3 重写 首页.ets 时从 UI-PAGE-HOME-011 块迁移进来，块 ID 字符串保持不变。
//
// @副作用
// 读写 preferences（牌组元数据）；可能复制/删除沙箱背景图；刷新内部状态字段
//
// @注意
// 当前为 Phase 2 骨架（打开/关闭已实现，应用为 stub）；Phase 3 会替换为真实实现。
// ========================================================

import type { 牌组定制结果 } from '../components/牌组定制面板';

export class 牌组定制状态机 {
  public 显示: boolean = false;
  public 牌组ID: string = '';
  public 进行中: boolean = false;
  public 错误: string = '';

  public 打开(牌组ID: string): void {
    this.牌组ID = 牌组ID;
    this.显示 = true;
    this.错误 = '';
  }

  public async 应用(结果: 牌组定制结果): Promise<void> {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 关闭(): void {
    this.显示 = false;
    this.牌组ID = '';
    this.错误 = '';
    this.进行中 = false;
  }
}
