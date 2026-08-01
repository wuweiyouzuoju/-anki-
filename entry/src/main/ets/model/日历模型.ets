// SPDX-License-Identifier: AGPL-3.0-or-later

const 月历最大周数: number = 6;
const 日历列数: number = 7;

export interface 日历单日 {
  key: string;
  日号: number;
  是否当月: boolean;
  是否今天: boolean;
  热力强度: number;
}

export interface 月历数据 {
  标题: Resource;
  单日列表: 日历单日[];
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

export function 构建月历(当前时间: Date, 按日期复习次数: Map<string, number>): 月历数据 {
  const 年: number = 当前时间.getFullYear();
  const 月: number = 当前时间.getMonth();
  const 今日: number = 当前时间.getDate();
  const 当月天数: number = 月天数(年, 月);
  const 上月天数: number = 月天数(年, 月 - 1);
  const 前置天数: number = 周一首日索引(new Date(年, 月, 1).getDay());
  const 最大值: number = 月最大值(年, 月, 按日期复习次数);
  const 单日列表: 日历单日[] = [];

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
