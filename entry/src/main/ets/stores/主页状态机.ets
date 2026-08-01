// SPDX-License-Identifier: AGPL-3.0-or-later

import type { 牌组服务 } from '../backend/牌组服务';
import type { 统计服务 } from '../backend/统计服务';
import type { 主页快照, 主页加载状态, 牌组列表数据源 } from '../model/主页模型';
import type { 月历数据 } from '../model/日历模型';

export class 主页状态机 {
  public 加载状态: 主页加载状态 = 'loading';
  public 主页快照数据: 主页快照 = null as any;
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

  public constructor(
    private readonly 牌组服务实例: 牌组服务,
    private readonly 统计服务实例: 统计服务,
  ) {}

  public async 加载主页数据(): Promise<void> {
    throw new Error('待 Phase 3 重写首页时实现');
  }

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
