// SPDX-License-Identifier: AGPL-3.0-or-later

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
