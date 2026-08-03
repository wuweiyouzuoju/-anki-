// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-CALENDAR-001
// @名称 月历构建模型
//
// @作用
// 为复习日历热力图构建月历数据结构：根据当月天数、复习次数热力分布，
// 生成可渲染的日历单日列表，并按实际行数（5 或 6）裁剪格数。
//
// @输入
// 当前时间 now: Date
// 复习次数按日期映射 reviewCountsByDate: Map<string, number>
//
// @输出
// 月历数据（含标题资源、日历单日列表、所需行数）
//
// @业务规则
// 月历最多 6 行（42 格），但实际只需 ceil((leadingDays + currentMonthDays) / 7) 行：
// 28 天 + 0 leading = 4 行；30 天 + 1 leading = 5 行；31 天 + 5 leading = 6 行。
// 固定 6 行会让某些月份多一行空格且加剧卡片高度溢出，故按实际行数渲染。
// 至少 5 行避免某些 4 行月份日历过矮（如 2026-02-01 周日 → 4 行，仍按 5 行渲染）。
//
// @副作用
// 无。纯函数，不读写持久化。
//
// @注意
// dateKey 输出的 'YYYY-MM-DD' 是与外部 Map 协议的字符串键格式，保留英文连字符。
// ========================================================

const 月历最大周数: number = 6;
const 日历列数: number = 7;

// ========================================================
// @块ID MODEL-CALENDAR-002
// @名称 日历单日
//
// @作用
// 描述日历中的一个格子（可能是当月日，也可能是上月末/下月初的填充日）。
//
// @输入
// 无（数据结构定义）
//
// @输出
// 字段：
// key - React/Grid 列表唯一键
// dayNumber - 显示的日号
// inCurrentMonth - 是否当月
// isToday - 是否今天
// intensity - 热力强度 0~4
//
// @副作用
// 无
// ========================================================
export interface 日历单日 {
  key: string;
  日号: number;
  是否当月: boolean;
  是否今天: boolean;
  热力强度: number;
}

// ========================================================
// @块ID MODEL-CALENDAR-003
// @名称 月历数据
//
// @作用
// 一个月日历的完整渲染数据。
//
// @输入
// 无（数据结构定义）
//
// @输出
// 字段：
// title - 标题资源（带年份/月份参数）
// days - 日历单日列表（按行优先排列）
// weekCount - 实际行数（5 或 6），用于驱动 Grid rowsTemplate 动态调整
//
// @副作用
// 无
// ========================================================
export interface 月历数据 {
  标题: Resource;
  单日列表: 日历单日[];
  // 实际需要的行数（5 或 6），用于驱动 Grid rowsTemplate 动态调整
  周数: number;
}

function 月天数(年: number, 月: number): number {
  return new Date(年, 月 + 1, 0).getDate();
}

function 周一首日索引(JS星期: number): number {
  return (JS星期 + 6) % 7;
}

function 两位数(值: number): string {
  return 值 < 10 ? `0${值}` : 值.toString();
}

function 日期键(年: number, 月: number, 日: number): string {
  return `${年}-${两位数(月 + 1)}-${两位数(日)}`;
}

function 月最大值(年: number, 月: number,
  按日期复习次数: Map<string, number>): number {
  const 天数: number = 月天数(年, 月);
  let 最大值: number = 0;
  for (let 日: number = 1; 日 <= 天数; 日++) {
    const 值: number = 按日期复习次数.get(日期键(年, 月, 日)) ?? 0;
    最大值 = Math.max(最大值, 值);
  }
  return 最大值;
}

function 复习热力强度(次数: number, 最大值: number): number {
  if (次数 <= 0 || 最大值 <= 0) {
    return 0;
  }
  const 比例: number = 次数 / 最大值;
  if (比例 <= 0.25) {
    return 1;
  }
  if (比例 <= 0.5) {
    return 2;
  }
  if (比例 <= 0.75) {
    return 3;
  }
  return 4;
}

// ========================================================
// @块ID MODEL-CALENDAR-004
// @名称 构建月历
//
// @作用
// 根据当前时间和复习次数映射，构建当月的完整日历数据（含热力强度与行数）。
//
// @输入
// now - 当前时间，用于确定年/月/今日
// reviewCountsByDate - 按日期键（YYYY-MM-DD）的复习次数
//
// @输出
// 月历数据：标题资源、单日列表、实际周数
//
// @业务规则
// 实际行数 = max(5, min(6, ceil((leading + currentMonthDays) / 7)))；
// 非当月日填充上月末/下月初日号；非当月日不计入热力强度；
// 今日仅在当月日内高亮。
//
// @副作用
// 无
// ========================================================
export function 构建月历(当前时间: Date, 按日期复习次数: Map<string, number>): 月历数据 {
  const 年: number = 当前时间.getFullYear();
  const 月: number = 当前时间.getMonth();
  const 今日: number = 当前时间.getDate();
  const 当月天数: number = 月天数(年, 月);
  const 上月天数: number = 月天数(年, 月 - 1);
  const 前置天数: number = 周一首日索引(new Date(年, 月, 1).getDay());
  const 最大值: number = 月最大值(年, 月, 按日期复习次数);
  const 单日列表: 日历单日[] = [];

  // 实际行数 = ceil((leading + currentMonthDays) / 7)；至少 5 行避免某些 4 行月份日历过矮。
  // 例如 2026-02-01 周日 → leading=0 + 28 天 = 28 → 4 行；视觉上卡片过空，仍按 5 行渲染。
  const 总格数: number = 前置天数 + 当月天数;
  const 周数: number = Math.max(5, Math.min(月历最大周数,
    Math.ceil(总格数 / 日历列数)));
  const 格数: number = 周数 * 日历列数;

  for (let 索引: number = 0; 索引 < 格数; 索引++) {
    const 相对日: number = 索引 - 前置天数 + 1;
    let 日号: number = 相对日;
    let 是否当月: boolean = true;
    if (相对日 <= 0) {
      日号 = 上月天数 + 相对日;
      是否当月 = false;
    } else if (相对日 > 当月天数) {
      日号 = 相对日 - 当月天数;
      是否当月 = false;
    }
    const 次数: number = 是否当月 ?
      按日期复习次数.get(日期键(年, 月, 日号)) ?? 0 : 0;
    单日列表.push({
      key: `${年}-${月}-${索引}`,
      日号: 日号,
      是否当月: 是否当月,
      是否今天: 是否当月 && 日号 === 今日,
      热力强度: 复习热力强度(次数, 最大值)
    });
  }

  return {
    标题: $r('app.string.calendar_month_title', 年, 月 + 1),
    单日列表: 单日列表,
    周数: 周数
  };
}
