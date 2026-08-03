// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-CREATECOORD-001
// @名称 创建牌组协调器
//
// @作用
// 包装 创建牌组面板，作为 首页 与 创建牌组面板 之间的薄 UI 协调层。
// 条件渲染：仅当 显示=true 时挂载面板。
// 替换原 首页.ets 第 1612-1626 行散写的 创建牌组面板 调用。
//
// @输入
// 显示: boolean  面板显示开关
// 进行中: boolean  创建中标志（busy）
// 错误: string  错误文案
// 父牌组ID: string  初始父牌组 ID（'' 表示顶层）
// 牌组选项列表: 牌组汇总[]  可选父牌组列表（主页快照数据.decks）
// 是否深色: boolean  暗色模式
// onCancel: () => void  取消回调
// onConfirm: (name: string) => void  确认创建回调
//
// @输出
// 条件渲染 创建牌组面板；不显示时返回空
//
// @业务规则
// 取消时由父组件负责关闭面板（设置 显示=false）
// 确认时由父组件负责调后端创建牌组、刷新主页、选中新牌组
//
// @副作用
// 无。
// ========================================================

import { 创建牌组面板 } from '../创建牌组面板';
import type { 牌组汇总 } from '../../model/主页模型';

@Component
export struct 创建牌组协调器 {
  @Prop 显示: boolean;
  @Prop 进行中: boolean;
  @Prop 错误: string;
  @Prop 父牌组ID: string;
  @Prop 牌组选项列表: 牌组汇总[] = [];
  @Prop 是否深色: boolean;
  onCancel: () => void = (): void => {};
  onConfirm: (name: string) => void = (): void => {};

  build() {
    if (this.显示) {
      创建牌组面板({
        isDark: this.是否深色,
        busy: this.进行中,
        errorMessage: this.错误,
        parentOptions: this.牌组选项列表,
        initialParentId: this.父牌组ID,
        onCancel: (): void => {
          this.onCancel();
        },
        onConfirm: (name: string): void => {
          this.onConfirm(name);
        }
      })
    }
  }
}
