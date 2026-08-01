// SPDX-License-Identifier: AGPL-3.0-or-later

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
