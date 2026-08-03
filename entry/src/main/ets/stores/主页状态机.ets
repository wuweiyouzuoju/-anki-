// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-HOME-STORE-001
// @名称 主页状态机
//
// @作用
// 集中托管主页跨组件共享状态与异步逻辑：加载主页数据、牌组展开/折叠/拖拽排序、
// 上次牌组恢复、AnkiWeb 引导、同步后 FSRS 检查。
// 由 首页 在 aboutToAppear 实例化、通过 @Provide 注入；子组件通过 @Consume 取用。
//
// @输入
// 构造时注入 牌组服务实例 / 统计服务实例
// 各方法接收业务参数（牌组 ID、上下文等）
//
// @输出
// 持有主页全部状态字段；方法被调用时更新字段
// 调用方（首页）负责把字段映射到 @State / @Provide 触发 UI 刷新
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*（model 层保持纯函数无副作用）。
// 实际逻辑在 Phase 3 重写 首页.ets 时从 UI-PAGE-HOME-* 块迁移进来，块 ID 字符串保持不变。
//
// @副作用
// 调后端服务、读写 preferences、刷新内部状态字段
//
// @注意
// 当前为 Phase 2 骨架，方法体为 stub；Phase 3 会替换为真实实现。
// 修改字段时注意 首页.ets 中对应 @State 字段需同步更新。
// ========================================================

import type { 牌组服务 } from '../backend/牌组服务';
import type { 统计服务 } from '../backend/统计服务';
import type { 主页快照, 主页加载状态, 牌组列表数据源 } from '../model/主页模型';
import type { 月历数据 } from '../model/日历模型';

export class 主页状态机 {
  // 状态字段
  public 加载状态: 主页加载状态 = 'loading';
  // 默认值用 null as any 规避对 model 层 空主页快照 常量的运行时 import，保持 store 仅类型依赖 model。
  public 主页快照数据: 主页快照 = null as any;
  // 默认值用 null as any 规避对 model 层 构建月历 函数的运行时 import，保持 store 仅类型依赖 model。
  public 月历: 月历数据 = null as any;
  public 展开的牌组ID集合: Set<string> = new Set<string>();
  public 隐藏的牌组ID集合: Set<string> = new Set<string>();
  public 排序模式中: boolean = false;
  public 摘要折叠: boolean = true;
  public 上次牌组已恢复: boolean = false;
  public 牌组展开已初始化: boolean = false;
  public 已知牌组ID集合: Set<string> = new Set<string>();
  public 刷新中: boolean = false;
  public 显示AnkiWeb引导: boolean = false;

  // 服务实例（构造注入）
  public constructor(
    private readonly 牌组服务实例: 牌组服务,
    private readonly 统计服务实例: 统计服务,
  ) {}

  // 方法签名（stub，待 Phase 3 重写 首页.ets 时迁入实际逻辑）
  public async 加载主页数据(): Promise<void> {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  // 返回类型实际为 GraphsView | null；此处用 any 避免 import GraphsView 导致 stub 签名复杂。
  public async 静默加载图表(): Promise<any> {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 切换展开(deckId: string): void {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 递归切换(deckId: string): void {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 进入排序模式(): void {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 退出排序模式(): void {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public 恢复上次牌组(): void {
    throw new Error('待 Phase 3 重写首页时实现');
  }

  public async 同步后检查FSRS(): Promise<void> {
    throw new Error('待 Phase 3 重写首页时实现');
  }
}
