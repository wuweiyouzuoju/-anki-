// SPDX-License-Identifier: AGPL-3.0-or-later

// 月历最多 6 行（42 格），但实际只需 ceil((leadingDays + currentMonthDays) / 7) 行：
// 28 天 + 0 leading = 4 行；30 天 + 1 leading = 5 行；31 天 + 5 leading = 6 行。
// 固定 6 行会让某些月份多一行空格且加剧卡片高度溢出，故按实际行数渲染。
const CALENDAR_MAX_WEEKS: number = 6;
const CALENDAR_COLUMNS: number = 7;

export interface CalendarDay {
  key: string;
  dayNumber: number;
  inCurrentMonth: boolean;
  isToday: boolean;
  intensity: number;
}

export interface MonthCalendar {
  title: Resource;
  days: CalendarDay[];
  // 实际需要的行数（5 或 6），用于驱动 Grid rowsTemplate 动态调整
  weekCount: number;
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

function mondayFirstIndex(jsDay: number): number {
  return (jsDay + 6) % 7;
}

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : value.toString();
}

function dateKey(year: number, month: number, day: number): string {
  return `${year}-${twoDigits(month + 1)}-${twoDigits(day)}`;
}

function monthMaximum(year: number, month: number,
  reviewCountsByDate: Map<string, number>): number {
  const count: number = daysInMonth(year, month);
  let maximum: number = 0;
  for (let day: number = 1; day <= count; day++) {
    const value: number = reviewCountsByDate.get(dateKey(year, month, day)) ?? 0;
    maximum = Math.max(maximum, value);
  }
  return maximum;
}

function reviewIntensity(count: number, maximum: number): number {
  if (count <= 0 || maximum <= 0) {
    return 0;
  }
  const ratio: number = count / maximum;
  if (ratio <= 0.25) {
    return 1;
  }
  if (ratio <= 0.5) {
    return 2;
  }
  if (ratio <= 0.75) {
    return 3;
  }
  return 4;
}

export function buildMonthCalendar(now: Date, reviewCountsByDate: Map<string, number>): MonthCalendar {
  const year: number = now.getFullYear();
  const month: number = now.getMonth();
  const today: number = now.getDate();
  const currentMonthDays: number = daysInMonth(year, month);
  const previousMonthDays: number = daysInMonth(year, month - 1);
  const leadingDays: number = mondayFirstIndex(new Date(year, month, 1).getDay());
  const maximum: number = monthMaximum(year, month, reviewCountsByDate);
  const days: CalendarDay[] = [];

  // 实际行数 = ceil((leading + currentMonthDays) / 7)；至少 5 行避免某些 4 行月份日历过矮。
  // 例如 2026-02-01 周日 → leading=0 + 28 天 = 28 → 4 行；视觉上卡片过空，仍按 5 行渲染。
  const totalCells: number = leadingDays + currentMonthDays;
  const weekCount: number = Math.max(5, Math.min(CALENDAR_MAX_WEEKS,
    Math.ceil(totalCells / CALENDAR_COLUMNS)));
  const cellCount: number = weekCount * CALENDAR_COLUMNS;

  for (let index: number = 0; index < cellCount; index++) {
    const relativeDay: number = index - leadingDays + 1;
    let dayNumber: number = relativeDay;
    let inCurrentMonth: boolean = true;
    if (relativeDay <= 0) {
      dayNumber = previousMonthDays + relativeDay;
      inCurrentMonth = false;
    } else if (relativeDay > currentMonthDays) {
      dayNumber = relativeDay - currentMonthDays;
      inCurrentMonth = false;
    }
    const count: number = inCurrentMonth ?
      reviewCountsByDate.get(dateKey(year, month, dayNumber)) ?? 0 : 0;
    days.push({
      key: `${year}-${month}-${index}`,
      dayNumber: dayNumber,
      inCurrentMonth: inCurrentMonth,
      isToday: inCurrentMonth && dayNumber === today,
      intensity: reviewIntensity(count, maximum)
    });
  }

  return {
    title: $r('app.string.calendar_month_title', year, month + 1),
    days: days,
    weekCount: weekCount
  };
}
