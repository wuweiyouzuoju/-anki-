// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-OPTCOORD-001
// @名称 牌组选项协调器
//
// @作用
// 包装 牌组选项面板，作为 首页 与 牌组选项面板 之间的薄 UI 协调层。
// 由首页在外层 if 守卫 显示牌组选项 && 编辑表单!==null && 编辑选项!==null 后条件挂载。
//
// @输入
// 进行中: boolean  保存中标志（禁用取消）
// 错误: string  错误文案
// 牌组名: string  当前编辑牌组名
// 编辑表单: 牌组配置表单  表单数据（@ObjectLink 引用共享）
// 编辑选项: 牌组选项编辑  选项数据（@ObjectLink 引用共享）
// 是否深色: boolean  暗色模式
// onCancel: () => void  关闭面板回调
// onSave: (form, options) => void  保存回调
//
// @输出
// 渲染 牌组选项面板
//
// @业务规则
// 进行中=true 时 onCancel 不触发（避免保存中关闭）
// 编辑表单/编辑选项 用 @ObjectLink（非 @Prop）保持 @Observed 代理链，
// 使面板内字段编辑能被 @ObjectLink 观察并触发 canSubmit() 重算。
// B12-Y5 2026-07-29：原 @Prop 深拷贝破坏 @Observed 代理，导致面板
// @ObjectLink 无法观察字段变化，保存按钮 enabled 状态不随输入更新。
//
// @副作用
// 无。
// ========================================================

import { 牌组选项面板 } from '../牌组选项面板';
import { 牌组配置表单 } from '../../model/牌组配置表单';
import { 牌组选项编辑 } from '../../model/牌组选项编辑';

@Component
export struct 牌组选项协调器 {
  @Prop 进行中: boolean = false;
  @Prop 错误: string = '';
  @Prop 牌组名: string = '';
  @ObjectLink 编辑表单: 牌组配置表单;
  @ObjectLink 编辑选项: 牌组选项编辑;
  @Prop 是否深色: boolean = false;
  onCancel: () => void = (): void => {};
  onSave: (form: 牌组配置表单, options: 牌组选项编辑) => void = (_form: 牌组配置表单, _options: 牌组选项编辑): void => {};

  build() {
    牌组选项面板({
      isDark: this.是否深色,
      deckName: this.牌组名,
      form: this.编辑表单,
      options: this.编辑选项,
      busy: this.进行中,
      errorMessage: this.错误,
      onCancel: (): void => {
        if (!this.进行中) this.onCancel();
      },
      onSave: (form: 牌组配置表单, options: 牌组选项编辑): void => {
        this.onSave(form, options);
      }
    })
  }
}
