// SPDX-License-Identifier: AGPL-3.0-or-later

import type { 数据迁移意图, 数据迁移模式 } from '../components/数据迁移面板';

export class 数据迁移状态机 {
  public 显示: boolean = false;
  public 初始模式: 数据迁移模式 = 'exportDeck';
  public 初始牌组ID: number = 0;
  public 允许选牌组: boolean = false;
  public 进行中: boolean = false;
  public 错误: string = '';
  public 阶段: number = -1;
  public 个人数据替换步骤: number = 0;

  public 打开导出牌组(牌组ID: number): void { throw new Error('待 Phase 3 重写首页时实现'); }
  public 打开导出全部(): void { throw new Error('待 Phase 3 重写首页时实现'); }
  public 打开导入(): void { throw new Error('待 Phase 3 重写首页时实现'); }
  public 打开替换集合(): void { throw new Error('待 Phase 3 重写首页时实现'); }
  public async 处理(意图: 数据迁移意图): Promise<void> { throw new Error('待 Phase 3 重写首页时实现'); }
  public 关闭(): void { throw new Error('待 Phase 3 重写首页时实现'); }
}
