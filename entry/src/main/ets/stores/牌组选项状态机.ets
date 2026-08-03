// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-OPT-STORE-001
// @名称 牌组选项状态机
//
// @作用
// 集中托管牌组选项面板的共享状态与异步逻辑：打开/保存/关闭，编辑视图拉取、
// 表单校验、配置回写后端。
// 由 首页 实例化、@Provide 注入；牌组选项协调器 @Consume 取用。
//
// @输入
// 构造时注入 牌组配置服务实例
// 打开(牌组ID, 牌组名) / 保存(form, options)
//
// @输出
// 持有面板显示态、加载态、错误态、编辑视图/配置/表单/选项
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*
// 实际逻辑在 Phase 3 重写 首页.ets 时从 UI-PAGE-HOME-015 / 016 块迁移进来，块 ID 字符串保持不变。
//
// @副作用
// 调后端拉取/更新牌组配置；刷新内部状态字段
//
// @注意
// 当前为 Phase 2 骨架；Phase 3 会替换为真实实现。
// ========================================================

import type { 牌组配置服务 } from '../backend/牌组配置服务';
import type { 牌组配置表单, 校验问题 } from '../model/牌组配置表单';
import type { 牌组选项编辑 } from '../model/牌组选项编辑';

export class 牌组选项状态机 {
  public 显示: boolean = false;
  public 加载中: boolean = false;
  public 进行中: boolean = false;
  public 错误: string = '';
  public 牌组ID: number = 0;
  public 牌组名: string = '';
  // 编辑视图 / 编辑配置 类型来自 proto，用 any 简化
  public 编辑视图: any = null;
  public 编辑配置: any = null;
  public 编辑表单: 牌组配置表单 | null = null;
  public 编辑选项: 牌组选项编辑 | null = null;

  public constructor(private readonly 牌组配置服务实例: 牌组配置服务) {}

  public async 打开(牌组ID: number, 牌组名: string): Promise<void> { throw new Error('待 Phase 3 重写首页时实现'); }
  public async 保存(form: 牌组配置表单, options: 牌组选项编辑): Promise<void> { throw new Error('待 Phase 3 重写首页时实现'); }
  public 关闭(): void { throw new Error('待 Phase 3 重写首页时实现'); }
  public 校验消息(issue: 校验问题): string { throw new Error('待 Phase 3 重写首页时实现'); }
}
