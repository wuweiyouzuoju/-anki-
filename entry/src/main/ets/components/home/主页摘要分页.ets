// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UI-HOME-SUMMARY-001
// @名称 主页摘要分页
//
// @作用
// 渲染主页顶部摘要 Swiper：今日摘要卡 + 月历卡。
// 折叠态仅显示今日摘要卡（Swiper 高度 82 + hitTestBehavior None 禁用滑动）；
// 展开态恢复 Swiper 滑动（高度 应用尺寸.滑动器高度 + indicator 显示）。
// 替换原 首页.ets 的 @Builder 摘要分页()。
//
// @输入
// 摘要折叠: boolean  折叠态标志
// onToggleExpand: () => void  切换折叠/展开
// 主页快照数据: 主页快照  今日完成/记忆率/复习计数等数据
// 月历: 月历数据  月历标题与单日列表
//
// @输出
// 渲染 Swiper(今日摘要卡 + 月历卡)，高度与交互随 摘要折叠 切换
//
// @业务规则
// 始终渲染同一 Swiper 实例（不 if 切换），让 collapsed Prop 变化时 ▼ 旋转 .animation 生效
// 折叠态 hitTestBehavior(None) 禁用滑动但允许子组件 onClick
// loop=false：2 张卡不需要首末循环
//
// @副作用
// 无。
// ========================================================

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
