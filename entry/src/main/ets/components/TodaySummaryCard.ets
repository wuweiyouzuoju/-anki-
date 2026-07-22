// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';

// 今日进度摘要卡：完成/待学/今日回忆率与进度条。牌组数在顶部小字显示。
// 空态分两种情况提示：
// - deckCount=0：用户还没建牌组 → "点击右上角新建牌组"
// - deckCount>0 但 completed+pending=0：有牌组但今日没卡可学 → "点击牌组开始学习"
// 这两种情况下隐藏三列指标和进度条，只显示一行提示，避免 0/0/0 让用户分不清。
//
// 注意：三个 countMetric 不能用 @Builder 方法接收 number 参数来实现——ArkUI 的
// @Builder 对参数值在首次渲染时被捕获，不响应 @Prop 后续变化，会导致学完卡后
// 上方 today_summary_detail 小字更新但下方三个数字不刷新。必须 inline 写在 build()。
//
// B12-Y2 2026-07-21：新增 collapsed Prop 支持主页折叠态。
// collapsed=true 时只渲染顶部（标题+小字+牌组数+▼箭头）+进度条/空态提示，
// 不渲染三列指标，整体可点击触发 onToggleExpand 展开。
@Component
export struct TodaySummaryCard {
  @Prop completedCount: number = 0;
  @Prop pendingCount: number = 0;
  @Prop deckCount: number = 0;
  // 今日回忆率 0-1（来自 graphs.today 的 1 - todayAgainRate）；-1 表示今日无数据（未学习/拉取失败）
  @Prop todayRecallRate: number = -1;
  // 折叠态：true=只渲染顶部+进度条（不渲染三列指标），false=完整渲染
  @Prop collapsed: boolean = false;
  // 折叠态点击回调：Index 收到后切换 summaryCollapsed
  onToggleExpand: (() => void) | null = null;

  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.primaryContainer) private primaryContainerColor: string = '#E8EEFC';
  @StorageProp(COLOR_KEYS.countNew) private countNewColor: string = '#3974D9';
  @StorageProp(COLOR_KEYS.countLearning) private countLearningColor: string = '#B56A22';
  @StorageProp(COLOR_KEYS.countReview) private countReviewColor: string = '#7056C8';

  private progressValue(): number {
    const total: number = this.completedCount + this.pendingCount;
    if (total <= 0) {
      return 0;
    }
    return this.completedCount / total * 100;
  }

  private isEmptyState(): boolean {
    return this.deckCount === 0 || (this.completedCount === 0 && this.pendingCount === 0);
  }

  private emptyHint(): Resource {
    if (this.deckCount === 0) {
      return $r('app.string.today_empty_no_decks_hint');
    }
    return $r('app.string.today_empty_no_activity_hint');
  }

  build() {
    Column({ space: this.collapsed ? AppDimens.SPACE_8 : AppDimens.SPACE_13 }) {
      Row() {
        Column({ space: AppDimens.SPACE_3 }) {
          Text($r('app.string.today_progress'))
            .fontSize(AppDimens.FONT_SUMMARY_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.today_summary_detail', this.completedCount, this.pendingCount))
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Blank()
        Text($r('app.string.deck_count_summary', this.deckCount))
          .fontSize(AppDimens.FONT_BODY_M)
          .fontColor($r('app.color.text_secondary'))
        // B12-Y2 2026-07-21：统一三角形旋转模式 + 动画，与 DeckListItem / DeckDetailPane / SettingsPanel 一致
        // collapsed=true → angle=-90 ▼ 旋转向右（表示"点击展开"）
        // collapsed=false → angle=0 ▼ 朝下（表示"点击折叠"）
        // .animation 跟在 .rotate 后：rotate 角度变化时自动播放 150ms EaseOut 过渡
        // 箭头不独立 onClick——点击事件冒泡到 Column onClick 统一处理 onToggleExpand，
        // 避免子父组件 onClick 都触发导致 onToggleExpand 被调用两次状态反而切不回去
        Text('▼')
          .fontSize(AppDimens.FONT_BODY_M)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: AppDimens.SPACE_8 })
          .padding({ left: AppDimens.SPACE_4, right: AppDimens.SPACE_4, top: AppDimens.SPACE_4, bottom: AppDimens.SPACE_4 })
          .rotate({ angle: this.collapsed ? -90 : 0 })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')

      if (this.isEmptyState()) {
        if (this.collapsed) {
          // 折叠态空态：只显示一行小字提示，不撑开空白
          Text(this.emptyHint())
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          // 展开态空态：上下 Blank 撑开居中
          Blank()
          Text(this.emptyHint())
            .fontSize(AppDimens.FONT_BODY)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
          Blank()
        }
      } else {
        Progress({ value: this.progressValue(), total: 100, type: ProgressType.Linear })
          .height(AppDimens.PROGRESS_HEIGHT)
          .color(this.actionPrimaryColor)
          .backgroundColor(this.primaryContainerColor)
          .borderRadius(AppDimens.RADIUS_PROGRESS)

        // B12-Y2 2026-07-21：折叠态不渲染三列指标，只保留进度条
        if (!this.collapsed) {
          Row({ space: AppDimens.SPACE_10 }) {
            Column({ space: AppDimens.SPACE_3 }) {
              Text(this.completedCount.toString())
                .fontSize(AppDimens.FONT_METRIC)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.countNewColor)
              Text($r('app.string.completed_today'))
                .fontSize(AppDimens.FONT_BODY_S)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: AppDimens.SPACE_3 }) {
              Text(this.pendingCount.toString())
                .fontSize(AppDimens.FONT_METRIC)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.countLearningColor)
              Text($r('app.string.pending_today'))
                .fontSize(AppDimens.FONT_BODY_S)
                .fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: AppDimens.SPACE_3 }) {
              Text(this.todayRecallRate >= 0 ? `${Math.round(this.todayRecallRate * 100)}%` : '-')
                .fontSize(AppDimens.FONT_METRIC)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.countReviewColor)
              Text($r('app.string.today_recall_rate'))
                .fontSize(AppDimens.FONT_BODY_S)
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
    // B12-Y2 2026-07-21：折叠态高度自适应内容（顶部 Row~35 + SPACE_8 + 进度条 7 + padding 32 = ~82）
    // 展开态保持 CARD_HEIGHT=204，与 MonthCalendarCard 等高对齐
    // B12-Y2 2026-07-22：height 加 animation 与 ▼ rotate 同步过渡，避免 height 瞬变让旋转显得突兀
    .height(this.collapsed ? 82 : AppDimens.CARD_HEIGHT)
    .animation({ duration: 300, curve: Curve.EaseOut })
    .padding(AppDimens.CARD_PADDING)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
    .borderRadius(AppDimens.RADIUS_CARD)
    // B12-Y2 2026-07-21：整张卡 onClick 触发 onToggleExpand（折叠↔展开对称）
    // 折叠态点击展开；展开态点击折叠——与折叠态行为对称，用户反馈"点击边框也可以折叠也统一"
    // Swiper 内子组件 onClick 不会与左右滑动冲突：ArkUI gesture 路由在水平移动超过阈值时优先消费 panGesture，
    // onClick 仅在 Press→Release 且未触发滑动时才触发
    .onClick(() => {
      if (this.onToggleExpand !== null) {
        this.onToggleExpand();
      }
    })
  }
}
