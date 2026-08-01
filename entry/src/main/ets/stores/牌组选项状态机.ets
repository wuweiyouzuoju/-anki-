// SPDX-License-Identifier: AGPL-3.0-or-later

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
