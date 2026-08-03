// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-TRANSFERCOORD-001
// @名称 数据迁移协调器
//
// @作用
// 包装 数据迁移面板，作为 首页 与 数据迁移面板 之间的薄 UI 协调层。
// 条件渲染：仅当 显示=true 时挂载面板。
// 替换原 首页.ets 第 1628-1649 行散写的 数据迁移面板 调用。
//
// @输入
// 显示: boolean  面板显示开关
// 进行中: boolean  导入/导出中标志（禁用关闭）
// 错误: string  错误文案
// 阶段: number  进度阶段（-1=无, 0=准备文件, 1=导入/导出中, 2=刷新列表, 4=刷新列表）
// 个人数据替换步骤: number  替换集合二次确认步骤（0/1）
// 初始模式: 数据迁移模式  'exportDeck' / 'exportPersonalData' / 'importDeck' / 'importPersonalData'
// 初始牌组ID: number  导出牌组时选中的 deckId
// 允许选牌组: boolean  是否允许用户选牌组（导出全部时 false）
// 牌组选项列表: 导出牌组选项[]  可选导出的牌组列表
// 是否深色: boolean  暗色模式
// onIntent: (intent: 数据迁移意图) => void  用户操作意图回调
// onClose: () => void  关闭面板回调
//
// @输出
// 条件渲染 数据迁移面板；不显示时返回空
//
// @业务规则
// 进行中=true 时 onClose 不触发（避免保存中关闭）
// 关闭时由父组件负责重置 个人数据替换步骤=0
//
// @副作用
// 无。
// ========================================================

import { 数据迁移面板 } from '../数据迁移面板';
import type { 数据迁移意图, 数据迁移模式, 导出牌组选项 } from '../数据迁移面板';

@Component
export struct 数据迁移协调器 {
  @Prop 显示: boolean;
  @Prop 进行中: boolean;
  @Prop 错误: string;
  @Prop 阶段: number;
  @Prop 个人数据替换步骤: number;
  @Prop 初始模式: 数据迁移模式;
  @Prop 初始牌组ID: number;
  @Prop 允许选牌组: boolean;
  @Prop 牌组选项列表: 导出牌组选项[] = [];
  @Prop 是否深色: boolean;
  onIntent: (intent: 数据迁移意图) => void = (): void => {};
  onClose: () => void = (): void => {};

  build() {
    if (this.显示) {
      数据迁移面板({
        deckId: this.初始牌组ID,
        initialMode: this.初始模式,
        deckOptions: this.牌组选项列表,
        allowDeckSelection: this.允许选牌组,
        busy: this.进行中,
        errorMessage: this.错误,
        personalReplacementStep: this.个人数据替换步骤,
        stage: this.阶段,
        isDark: this.是否深色,
        onIntent: (intent: 数据迁移意图): void => {
          this.onIntent(intent);
        },
        onClose: (): void => {
          if (!this.进行中) this.onClose();
        }
      })
    }
  }
}
