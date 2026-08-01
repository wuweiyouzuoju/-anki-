// SPDX-License-Identifier: AGPL-3.0-or-later
import type { 牌组服务 } from '../backend/牌组服务';

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
