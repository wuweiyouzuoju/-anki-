// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-TRANSFER-STORE-001
// @名称 数据迁移状态机
//
// @作用
// 集中托管数据迁移面板（导入/导出/替换集合）的共享状态与异步逻辑：
// 弹窗显隐、初始模式、进行中、错误、阶段、个人数据替换步骤。
// 由 首页 实例化、@Provide 注入；数据迁移协调器 @Consume 取用。
//
// @输入
// 打开导出牌组(牌组ID) / 打开导出全部() / 打开导入() / 打开替换集合()
// 处理(意图)
//
// @输出
// 持有面板显示态、初始模式/牌组ID、进行中/错误/阶段/替换步骤
//
// @业务规则
// 纯 TS 类，不持有 ArkUI 组件引用；不 import @kit.*
// 实际逻辑在 Phase 3 重写 首页.ets 时从 UI-PAGE-HOME-012 块迁移进来，块 ID 字符串保持不变。
//
// @副作用
// 调后端导出/导入/替换集合；读写沙箱临时文件；刷新内部状态字段
//
// @注意
// 当前为 Phase 2 骨架；Phase 3 会替换为真实实现。
// ========================================================

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
