// SPDX-License-Identifier: AGPL-3.0-or-later

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
