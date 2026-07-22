// SPDX-License-Identifier: AGPL-3.0-or-later

// 首页视觉尺寸 token：与颜色、字符串资源同级管理。
// 调整设计或适配新形态时只改这里，页面与组件不再出现魔法数字。
export class AppDimens {
  // ---- 字号 ----
  static readonly FONT_CAPTION_S: number = 10; // 星期表头
  static readonly FONT_CAPTION: number = 11; // 日历格数字、辅助提示
  static readonly FONT_BODY_S: number = 12; // 指标标签、卡组分项计数、月份副标题
  static readonly FONT_BODY_M: number = 13; // 次级说明文字
  static readonly FONT_BODY: number = 14; // 描述、详情指标标签、空态提示
  static readonly FONT_BUTTON: number = 15; // 顶部工具栏按钮
  static readonly FONT_EMPHASIS: number = 16; // 待学数量
  static readonly FONT_TITLE: number = 17; // 卡组名、空态标题、开始学习
  static readonly FONT_CARD_TITLE: number = 18; // 卡片内标题、详情指标数值
  static readonly FONT_SUMMARY_TITLE: number = 19; // 今日进度标题
  static readonly FONT_SECTION_TITLE: number = 20; // 分区标题
  static readonly FONT_METRIC: number = 21; // 今日指标数值
  static readonly FONT_DECK_TITLE: number = 25; // 详情页卡组名
  static readonly FONT_PANEL_TITLE: number = 22; // 弹层面板标题
  static readonly FONT_HERO: number = 42; // 记忆状态百分比

  // ---- 圆角 ----
  static readonly RADIUS_TONE: number = 3; // 卡组色条
  static readonly RADIUS_PROGRESS: number = 4; // 进度条
  static readonly RADIUS_CELL: number = 6; // 日历格
  static readonly RADIUS_DECK: number = 15; // 卡组行
  static readonly RADIUS_METRIC: number = 16; // 详情指标卡
  static readonly RADIUS_CARD: number = 18; // 摘要卡
  static readonly RADIUS_PANEL: number = 12; // 弹层面板
  static readonly PANEL_PADDING: number = 20; // 居中浮卡内边距（纵向呼吸感）
  static readonly PARENT_OPTION_INDENT: number = 16; // 父牌组候选行每层缩进（整张选择卡向右偏移）
  static readonly RADIUS_PILL: number = 22; // 工具栏按钮
  static readonly RADIUS_CTA: number = 26; // 开始学习按钮

  // ---- 卡片 ----
  // CARD_HEIGHT 用于 TodaySummaryCard（内容较紧凑 ~150px）。
  // MonthCalendarCard 不再用此常量，改用 cardHeight() 按 weekCount 动态算（220-261px）。
  static readonly CARD_HEIGHT: number = 204;
  static readonly CARD_PADDING: number = 16;
  static readonly CARD_BORDER: number = 1;
  // SWIPER_HEIGHT 必须容下最高的 MonthCalendarCard（6 行 + hasActivity=false 时 ≈261），
  // 故从 220 提到 272；TodaySummaryCard 高度 204 仍顶对齐渲染，
  // 下方空隙由 Swiper 容器吸收（背景同 surface_page，视觉无突兀）。
  static readonly SWIPER_HEIGHT: number = 272;

  // ---- 页面骨架 ----
  static readonly PAGE_PADDING_H: number = 12;
  static readonly TOOLBAR_HEIGHT: number = 60;
  static readonly BUTTON_HEIGHT: number = 44;
  static readonly CTA_HEIGHT: number = 52;

  // ---- 宽屏限宽 ----
  static readonly CONTENT_MAX_WIDTH: number = 1200; // 首页超宽屏内容限宽，超出居中留白
  static readonly STUDY_CONTENT_MAX_WIDTH: number = 840; // 复习页内容限宽，保持卡片可读宽度

  // ---- 日历 ----
  static readonly CAL_CELL_HEIGHT: number = 21;
  static readonly CAL_GRID_HEIGHT: number = 138;
  static readonly CAL_GAP_COL: number = 5;
  static readonly CAL_GAP_ROW: number = 4;

  // ---- 卡组列表 ----
  static readonly TONE_BAR_WIDTH: number = 6;
  static readonly TONE_BAR_HEIGHT: number = 50;
  static readonly ARROW_SLOT_WIDTH: number = 36; // 父牌组展开箭头槽位宽（视觉+热区，无子牌组的行也占位对齐）
  static readonly ARROW_SLOT_HEIGHT: number = 48; // 父牌组展开箭头热区高
  static readonly LIST_SPACE: number = 9;
  static readonly EMPTY_PADDING_V: number = 28;
  static readonly LOADING_SIZE: number = 36; // 列表加载指示器
  // 牌组行实机高度：padding(13+13) + 计数 Column(FONT_EMPHASIS+SPACE_5+FONT_BODY_S+SPACE_5+Row FONT_BODY_S ≈ 66)
  // 用于 DeckCustomizePanel 预览框，保证用户裁剪选区与实际渲染一致
  static readonly DECK_ROW_HEIGHT: number = 92;

  // ---- 进度条 ----
  static readonly PROGRESS_HEIGHT: number = 7;

  // ---- 堆叠间距 ----
  static readonly SPACE_2: number = 2;
  static readonly SPACE_3: number = 3;
  static readonly SPACE_4: number = 4;
  static readonly SPACE_5: number = 5;
  static readonly SPACE_7: number = 7;
  static readonly SPACE_8: number = 8;
  static readonly SPACE_10: number = 10;
  static readonly SPACE_12: number = 12;
  static readonly SPACE_13: number = 13;
  static readonly SPACE_14: number = 14;
  static readonly SPACE_15: number = 15;
  static readonly SPACE_16: number = 16;
  static readonly SPACE_17: number = 17;
}
