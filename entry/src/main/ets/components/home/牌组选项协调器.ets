// SPDX-License-Identifier: AGPL-3.0-or-later

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
