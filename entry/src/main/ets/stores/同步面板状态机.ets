// SPDX-License-Identifier: AGPL-3.0-or-later
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
