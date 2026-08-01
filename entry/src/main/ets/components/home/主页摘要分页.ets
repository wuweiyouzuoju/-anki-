// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../../utils/应用尺寸';
import { 今日摘要卡 } from '../今日摘要卡';
import { 月历卡 } from '../月历卡';
import { 主页快照 } from '../../model/主页模型';
import { 月历数据 } from '../../model/日历模型';

@Component
export struct 主页摘要分页 {
  @Prop 摘要折叠: boolean;
  onToggleExpand: () => void = (): void => {};
  @Prop 主页快照数据: 主页快照;
  @Prop 月历: 月历数据;

  build() {
    Swiper() {
      今日摘要卡({
        已完成数: this.主页快照数据.today.completedCount,
        待学数: this.主页快照数据.today.pendingCount,
        牌组数: this.主页快照数据.today.deckCount,
        今日回忆率: this.主页快照数据.memory.state === 'today_answered'
          ? 1 - this.主页快照数据.memory.todayAgainRate : -1,
        已折叠: this.摘要折叠,
        切换展开回调: (): void => { this.onToggleExpand(); }
      })
      月历卡({
        标题: this.月历.标题,
        日期列表: this.月历.单日列表,
        周数: this.月历.周数,
        有学习记录: this.主页快照数据.reviewCountsByDate.size > 0,
        已折叠: this.摘要折叠,
        切换展开回调: (): void => { this.onToggleExpand(); }
      })
    }
    .width('100%')
    .height(this.摘要折叠 ? 82 : 应用尺寸.滑动器高度)
    .animation({ duration: 300, curve: Curve.EaseOut })
    .hitTestBehavior(this.摘要折叠 ? HitTestMode.None : HitTestMode.Default)
    .autoPlay(false)
    .loop(false)
    .indicator(this.摘要折叠 ? false : true)
    .itemSpace(应用尺寸.间距_10)
  }
}
