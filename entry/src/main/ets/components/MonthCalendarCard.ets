// SPDX-License-Identifier: AGPL-3.0-or-later

import { CalendarDay } from '../model/CalendarModels';
import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';

// 本月学习热力月历卡：星期表头 + 5/6 行热力图。
// hasActivity=false（reviewCountsByDate 为空）时在标题行下方加一行"本月还没有学习记录"提示，
// 月历本身仍正常渲染（让用户看到当月日期骨架）。
//
// 注意：title / days / weekCount / hasActivity 拆成原子 @Prop，不再传整个 MonthCalendar 对象——
// ArkUI @Prop 对引用对象只做浅层赋值，若日后改用 `this.calendar.days = newDays` 原地修改，
// @Prop 不会触发刷新。拆成原子 prop 后任何一处变化都会可靠刷新。
@Component
export struct MonthCalendarCard {
  @Prop title: Resource = $r('app.string.calendar_month_title', 0, 0);
  @Prop days: CalendarDay[] = [];
  @Prop weekCount: number = 6;
  @Prop hasActivity: boolean = false;
  // B12-Y2 2026-07-22：折叠态支持（与 TodaySummaryCard 一致）
  // collapsed=true 时只渲染标题行（含 ▼ 按钮），不渲染周表头/月历网格/空态提示
  @Prop collapsed: boolean = false;
  // 折叠态点击回调：Index 收到后切换 summaryCollapsed
  onToggleExpand: (() => void) | null = null;

  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.heat1) private heat1Color: string = '#DCE8FF';
  @StorageProp(COLOR_KEYS.heat2) private heat2Color: string = '#B8CEFA';
  @StorageProp(COLOR_KEYS.heat3) private heat3Color: string = '#7EA3EE';
  @StorageProp(COLOR_KEYS.heat4) private heat4Color: string = '#2F5FD0';

  private readonly weekdays: Resource[] = [
    $r('app.string.weekday_1'), $r('app.string.weekday_2'), $r('app.string.weekday_3'),
    $r('app.string.weekday_4'), $r('app.string.weekday_5'), $r('app.string.weekday_6'),
    $r('app.string.weekday_7')
  ];

  private heatColor(intensity: number): ResourceColor {
    switch (intensity) {
      case 1:
        return this.heat1Color;
      case 2:
        return this.heat2Color;
      case 3:
        return this.heat3Color;
      case 4:
        return this.heat4Color;
      case 0:
      default:
        return $r('app.color.heat_0');
    }
  }

  private heatTextColor(day: CalendarDay): Resource {
    if (!day.inCurrentMonth) {
      return $r('app.color.text_tertiary');
    }
    return day.intensity >= 3 ?
      $r('app.color.action_on_primary') : $r('app.color.text_primary');
  }

  // rowsTemplate 按 weekCount 动态生成：5 行 → '1fr 1fr 1fr 1fr 1fr'，6 行 → 6 个 '1fr'。
  // 旧实现固定 6 行，某些月份（如 2026-02 leading=0+28 天=4 行）会多出 2 行空格，且
  // 卡片高度溢出 204 容器后底部裁切。动态行数解决两个问题：避免空行 + 控制高度。
  private rowsTemplate(): string {
    const rows: string[] = [];
    for (let i: number = 0; i < this.weekCount; i++) {
      rows.push('1fr');
    }
    return rows.join(' ');
  }

  // Grid 高度按 weekCount 动态：每行 21 + 行间 gap 4，行数越多越高。
  private gridHeight(): number {
    return this.weekCount * AppDimens.CAL_CELL_HEIGHT
      + (this.weekCount - 1) * AppDimens.CAL_GAP_ROW;
  }

  // 卡片整体高度按内容算：标题行 36 + 可选空态行 16 + 周表头 14 + Grid + Column space + padding。
  // 不再硬用 CARD_HEIGHT=204，因为月历内容实测 220-261px，固定 204 必然裁切。
  private cardHeight(): number {
    const titleRow: number = 36;
    const emptyHintRow: number = this.hasActivity ? 0 : 16;
    const weekdayRow: number = 14;
    const padding: number = AppDimens.SPACE_14 * 2;
    const columnSpace: number = AppDimens.SPACE_7 * 3;
    return titleRow + emptyHintRow + weekdayRow + this.gridHeight() + padding + columnSpace;
  }

  @Builder
  private calendarCell(day: CalendarDay) {
    Text(day.dayNumber.toString())
      .width('100%')
      .height(AppDimens.CAL_CELL_HEIGHT)
      .fontSize(AppDimens.FONT_CAPTION)
      .fontWeight(day.isToday ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.heatTextColor(day))
      .textAlign(TextAlign.Center)
      .backgroundColor(day.inCurrentMonth ? this.heatColor(day.intensity) : Color.Transparent)
      .border({
        width: day.isToday ? AppDimens.CARD_BORDER : 0,
        color: this.actionPrimaryColor
      })
      .borderRadius(AppDimens.RADIUS_CELL)
      .opacity(day.inCurrentMonth ? 1 : 0.45)
  }

  build() {
    Column({ space: AppDimens.SPACE_7 }) {
      Row() {
        Column({ space: AppDimens.SPACE_2 }) {
          Text($r('app.string.month_learning'))
            .fontSize(AppDimens.FONT_CARD_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.title)
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text($r('app.string.heat_hint'))
          .fontSize(AppDimens.FONT_CAPTION)
          .fontColor($r('app.color.text_tertiary'))
        // B12-Y2 2026-07-22：折叠 ▼ 按钮（与 TodaySummaryCard 统一）
        // 箭头不独立 onClick，事件冒泡到 Column onClick 统一处理
        Text('▼')
          .fontSize(AppDimens.FONT_BODY_M)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: AppDimens.SPACE_8 })
          .padding({ left: AppDimens.SPACE_4, right: AppDimens.SPACE_4, top: AppDimens.SPACE_4, bottom: AppDimens.SPACE_4 })
          .rotate({ angle: this.collapsed ? -90 : 0 })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
      .width('100%')

      // B12-Y2 2026-07-22：折叠态只渲染标题行（与 TodaySummaryCard 行为一致）
      if (!this.collapsed) {
        if (!this.hasActivity) {
          Text($r('app.string.month_empty_hint'))
            .fontSize(AppDimens.FONT_CAPTION)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }

        Row() {
          ForEach(this.weekdays, (weekday: Resource, index: number) => {
            Text(weekday)
              .fontSize(AppDimens.FONT_CAPTION_S)
              .fontColor($r('app.color.text_tertiary'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }, (weekday: Resource, index: number) => `weekday-${index}`)
        }
        .width('100%')

        Grid() {
          ForEach(this.days, (day: CalendarDay) => {
            GridItem() {
              this.calendarCell(day)
            }
          }, (day: CalendarDay) => day.key)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsTemplate(this.rowsTemplate())
        .columnsGap(AppDimens.CAL_GAP_COL)
        .rowsGap(AppDimens.CAL_GAP_ROW)
        .width('100%')
        .height(this.gridHeight())
      }
    }
    .width('100%')
    // B12-Y2 2026-07-22：折叠态高度与 TodaySummaryCard 对齐（82），展开态保持动态 cardHeight
    .height(this.collapsed ? 82 : this.cardHeight())
    .animation({ duration: 300, curve: Curve.EaseOut })
    .padding(AppDimens.SPACE_14)
    .backgroundColor($r('app.color.surface_card'))
    .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
    .borderRadius(AppDimens.RADIUS_CARD)
    // B12-Y2 2026-07-22：整张卡 onClick 触发 onToggleExpand（折叠↔展开对称）
    .onClick(() => {
      if (this.onToggleExpand !== null) {
        this.onToggleExpand();
      }
    })
  }
}
