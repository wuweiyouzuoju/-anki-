// SPDX-License-Identifier: AGPL-3.0-or-later
import type { 牌组服务 } from '../backend/牌组服务';

// ========================================================
// @块ID MODEL-CREATE-STORE-001
// @名称 创建牌组状态机
//
// @作用
// 集中托管新建牌组弹窗的显隐状态与提交逻辑。
// 由 首页 实例化、@Provide 注入；创建牌组协调器 @Consume 取用。
//
// @输入
// 构造时注入 牌组服务实例
// 打开(父牌组ID) / 提交(全名) / 关闭()
//
// @输出
// 持有 显示 / 父牌组ID / 进行中 / 错误 字段
// 提交成功返回新牌组 ID
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*
// 实际提交逻辑在 Phase 3 重写 首页.ets 时从 UI-PAGE-HOME-014 块迁移进来，块 ID 字符串保持不变。
//
// @副作用
// 调后端创建牌组；刷新内部状态字段
//
// @注意
// 当前为 Phase 2 骨架（打开/关闭已实现，提交为 stub）；Phase 3 会替换为真实实现。
// ========================================================
export class 创建牌组状态机 {
  public 显示: boolean = false;
  public 父牌组ID: string = '';
  public 进行中: boolean = false;
  public 错误: string = '';

  public constructor(private readonly 牌组服务实例: 牌组服务) {}

  public 打开(父牌组ID: string): void {
    this.父牌组ID = 父牌组ID;
    this.显示 = true;
    this.错误 = '';
  }

  public async 提交(全名: string): Promise<number> {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 关闭(): void {
    this.显示 = false;
    this.父牌组ID = '';
    this.错误 = '';
    this.进行中 = false;
  }
}
