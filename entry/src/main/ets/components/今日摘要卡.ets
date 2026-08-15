// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

// ========================================================
// @块ID UI-TODAY-SUMMARY-001
// @名称 今日摘要卡 组件主体字段
//
// @作用
// 今日进度摘要卡：完成/待学/今日回忆率与进度条。牌组数在顶部小字显示。
// 空态仅一种情况：deckCount=0（用户还没建牌组）→ "点击右上角新建牌组"。
// deckCount>0 但 completed+pending=0 时不再算空态，显示正常进度条（0%）+ 三列指标，
// 让用户看到牌组数和今日无待学状态（用户决策 2026-07-23：去掉"点击牌组开始学习"提示）。
// 折叠态支持：collapsed=true 时只渲染顶部（标题+小字+牌组数+▼箭头）+进度条/空态提示，
// 不渲染三列指标，整体可点击触发 切换展开回调 展开。
//
// @输入
// @Prop 已完成数 / 待学数 / 牌组数 / 今日回忆率（0-1，-1 表示无数据）。
// @Prop 已折叠：true=只渲染顶部+进度条，false=完整渲染。
// 切换展开回调：折叠态点击时上抛。
//
// @输出
// 渲染今日进度摘要卡；折叠态点击通过 切换展开回调 上抛。
//
// @业务规则
// 三个 计数指标 不能用 @Builder 方法接收 number 参数来实现——ArkUI 的 @Builder 对参数值
// 在首次渲染时被捕获，不响应 @Prop 后续变化，会导致学完卡后上方 小字更新但下方三个数字不刷新。
// 必须 inline 写在 build()。
// 折叠态高度自适应内容（顶部 Row~35 + 间距_8 + 进度条 7 + 内边距 32 = ~82），
// 展开态保持 卡片高度=204，与 月历卡 等高对齐。
//
// @副作用
// 无。仅渲染与上抛回调。
//
// @注意
// 修改折叠态高度常量时需同步 月历卡 折叠态高度（82）以保持视觉对齐。
// ========================================================
@Component
export struct 今日摘要卡 {
  @Prop 已完成数: number = 0;
  @Prop 待学数: number = 0;
  @Prop 牌组数: number = 0;
  // 今日回忆率 0-1（来自 graphs.today 的 1 - todayAgainRate）；-1 表示今日无数据（未学习/拉取失败）
  @Prop 今日回忆率: number = -1;
  // 折叠态：true=只渲染顶部+进度条（不渲染三列指标），false=完整渲染
  @Prop 已折叠: boolean = false;
  // 折叠态点击回调：Index 收到后切换 summaryCollapsed
  切换展开回调: (() => void) | null = null;

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @StorageProp(颜色键.新卡计数色) private 新卡计数色: string = '#3974D9';
  @StorageProp(颜色键.学习中计数色) private 学习中计数色: string = '#B56A22';
  @StorageProp(颜色键.复习中计数色) private 复习中计数色: string = '#7056C8';

  // ========================================================
  // @块ID UI-TODAY-SUMMARY-002
  // @名称 进度值 / 空态判断 / 空态提示
  //
  // @作用
  // 计算进度条百分比、判断是否空态、返回空态提示文案。
  //
  // @输入
  // this.已完成数 / 待学数 / 牌组数。
  //
  // @输出
  // 进度值 = 已完成数 / (已完成数 + 待学数) * 100（总数<=0 时返回 0）。
  // 是否空态 = 牌组数 === 0。
  // 空态提示 = $r('app.string.today_empty_no_decks_hint')。
  //
  // @业务规则
  // B12-Y2 2026-07-23：仅 牌组数=0 算空态。有牌组但今日无待学时显示正常进度条+指标。
  //
  // @副作用
  // 无。
  // ========================================================
  private 进度值(): number {
    const 总数: number = this.已完成数 + this.待学数;
    if (总数 <= 0) {
      return 0;
    }
    return this.已完成数 / 总数 * 100;
  }

  private 是否空态(): boolean {
    // B12-Y2 2026-07-23：仅 牌组数=0 算空态。有牌组但今日无待学时显示正常进度条+指标。
    return this.牌组数 === 0;
  }

  private 空态提示(): Resource {
    return $r('app.string.today_empty_no_decks_hint');
  }

  // ========================================================
  // @块ID UI-TODAY-SUMMARY-003
  // @名称 今日摘要卡主渲染
  //
  // @作用
  // 渲染整张今日摘要卡：标题行（标题 + 小字 + 牌组数 + ▼ 折叠按钮）+ 进度条/空态分支 + 三列指标（仅展开态）。
  //
  // @输入
  // 全部 @Prop + @StorageProp + 3 个私有方法。
  //
  // @输出
  // 整张今日摘要卡视觉；折叠态高度 82，展开态 卡片高度=204。
  //
  // @业务规则
  // ▼ 箭头：已折叠=true → angle=-90（旋转向右，"点击展开"）；已折叠=false → angle=0（朝下，"点击折叠"）。
  // .animation 跟在 .rotate 后：rotate 角度变化时自动播放 300ms EaseOut 过渡。
  // 箭头不独立 onClick——点击事件冒泡到 Column onClick 统一处理 切换展开回调，
  // 避免子父组件 onClick 都触发导致 切换展开回调 被调用两次状态反而切不回去。
  // 折叠态空态：只显示一行小字提示，不撑开空白；
  // 展开态空态：上下 Blank 撑开居中；
  // 非空态折叠：只保留进度条；
  // 非空态展开：进度条 + 三列指标（已完成/待学/今日回忆率）。
  // Swiper 内子组件 onClick 不会与左右滑动冲突：ArkUI gesture 路由在水平移动超过阈值时优先消费 panGesture，
  // onClick 仅在 Press→Release 且未触发滑动时才触发。
  //
  // @副作用
  // 无。仅上抛回调。
  // ========================================================
  build() {
    Column({ space: this.已折叠 ? 应用尺寸.间距_8 : 应用尺寸.间距_13 }) {
      Row() {
        Column({ space: 应用尺寸.间距_3 }) {
          Text($r('app.string.today_progress'))
            .fontSize(应用尺寸.字号_摘要标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.today_summary_detail', this.已完成数, this.待学数))
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        Text($r('app.string.deck_count_summary', this.牌组数))
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
        // B12-Y2 2026-07-21：统一三角形旋转模式 + 动画，与 牌组列表项 / 牌组详情面板 / 设置面板 一致
        // 已折叠=true → angle=-90 ▼ 旋转向右（表示"点击展开"）
        // 已折叠=false → angle=0 ▼ 朝下（表示"点击折叠"）
        // .animation 跟在 .rotate 后：rotate 角度变化时自动播放 150ms EaseOut 过渡
        // 箭头不独立 onClick——点击事件冒泡到 Column onClick 统一处理 切换展开回调，
        // 避免子父组件 onClick 都触发导致 切换展开回调 被调用两次状态反而切不回去
        Text('▼')
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 应用尺寸.间距_8 })
          .padding({ left: 应用尺寸.间距_4, right: 应用尺寸.间距_4, top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
          .rotate({ angle: this.已折叠 ? -90 : 0 })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')

      if (this.是否空态()) {
        if (this.已折叠) {
          // 折叠态空态：只显示一行小字提示，不撑开空白
          Text(this.空态提示())
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          // 展开态空态：上下 Blank 撑开居中
          Blank()
          Text(this.空态提示())
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          Blank()
        }
      } else {
        Progress({ value: this.进度值(), total: 100, type: ProgressType.Linear })
          .height(应用尺寸.进度条高度)
          .color(this.动作主色)
          .backgroundColor(this.主色容器色)
          .borderRadius(应用尺寸.圆角_进度条)

        // B12-Y2 2026-07-21：折叠态不渲染三列指标，只保留进度条
        if (!this.已折叠) {
          Row({ space: 应用尺寸.间距_10 }) {
            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.已完成数.toString())
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.新卡计数色)
              Text($r('app.string.completed_today'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.待学数.toString())
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.学习中计数色)
              Text($r('app.string.pending_today'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 应用尺寸.间距_3 }) {
              Text(this.今日回忆率 >= 0 ? `${Math.round(this.今日回忆率 * 100)}%` : '-')
                .fontSize(应用尺寸.字号_指标)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.复习中计数色)
              Text($r('app.string.today_recall_rate'))
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    // 展开态非空：标题、进度条、指标三部分用 SpaceBetween 均匀分布在整个卡片高度，
    // 消除原顶部堆叠导致的下半部分空白，也避免内容全沉底导致中间空白。
    .justifyContent(
      this.是否空态()
        ? FlexAlign.Center
        : (this.已折叠 ? FlexAlign.Start : FlexAlign.SpaceBetween)
    )
    // B12-Y2 2026-07-21：折叠态高度自适应内容（顶部 Row~35 + 间距_8 + 进度条 7 + 内边距 32 = ~82）
    // 展开态保持 卡片高度=204，与 月历卡 等高对齐
    // B12-Y2 2026-07-22：height 加 animation 与 ▼ rotate 同步过渡，避免 height 瞬变让旋转显得突兀
    .height(this.已折叠 ? 82 : 应用尺寸.卡片高度)
    .animation({ duration: 300, curve: Curve.EaseOut })
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
    .borderRadius(应用尺寸.圆角_卡片)
    // B12-Y2 2026-07-21：整张卡 onClick 触发 切换展开回调（折叠↔展开对称）
    // 折叠态点击展开；展开态点击折叠——与折叠态行为对称，用户反馈"点击边框也可以折叠也统一"
    // Swiper 内子组件 onClick 不会与左右滑动冲突：ArkUI gesture 路由在水平移动超过阈值时优先消费 panGesture，
    // onClick 仅在 Press→Release 且未触发滑动时才触发
    .onClick(() => {
      if (this.切换展开回调 !== null) {
        this.切换展开回调();
      }
    })
  }
}
