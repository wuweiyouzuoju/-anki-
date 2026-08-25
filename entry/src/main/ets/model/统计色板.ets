// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @名称 统计色板
//
// @意图
// 复刻 Anki 26.05 统计图表使用的 d3-scale-chromatic 色带（Blues/Greens/RdYlGn）
// 与各图表系列色。锚点取自 colorbrewer，插值用锚点间分段线性 RGB 逼近
// （与 d3 interpolateRgbBasis 的 B-spline 视觉差异极小）。
//
// @Invariants
// - 纯函数无副作用，不 import 任何 HarmonyOS Kit（node test runner 可直接加载）
// - t 入参会被钳制到 [0,1]，越界不抛错
//
// @ExtensionPoints
// - 新增色带：加锚点数组 + 对应导出函数
//
// @来源
// Anki ts/routes/graphs/*（26.05）引用的 d3 interpolateBlues/Greens/RdYlGn
// ========================================================

/** #RRGGBB → [r, g, b]（0-255） */
function 解析颜色(十六进制: string): number[] {
  const r: number = parseInt(十六进制.substring(1, 3), 16);
  const g: number = parseInt(十六进制.substring(3, 5), 16);
  const b: number = parseInt(十六进制.substring(5, 7), 16);
  return [r, g, b];
}

/** [r, g, b] → #rrggbb（小写） */
function 合成颜色(通道: number[]): string {
  const r: number = Math.round(Math.min(255, Math.max(0, 通道[0])));
  const g: number = Math.round(Math.min(255, Math.max(0, 通道[1])));
  const b: number = Math.round(Math.min(255, Math.max(0, 通道[2])));
  const 值: number = (1 << 24) + (r << 16) + (g << 8) + b;
  return `#${值.toString(16).substring(1)}`;
}

function 钳制(值: number): number {
  if (值 < 0) return 0;
  if (值 > 1) return 1;
  return 值;
}

/** 锚点间分段线性插值（t∈[0,1]，锚点均匀分布） */
function 插值(锚点: string[], t: number): string {
  const 系数: number = 钳制(t);
  const 段数: number = 锚点.length - 1;
  if (段数 <= 0) return 锚点[0];
  const 位置: number = 系数 * 段数;
  const 索引: number = Math.min(段数 - 1, Math.floor(位置));
  const 局部: number = 位置 - 索引;
  const 起点: number[] = 解析颜色(锚点[索引]);
  const 终点: number[] = 解析颜色(锚点[索引 + 1]);
  const r: number = 起点[0] + (终点[0] - 起点[0]) * 局部;
  const g: number = 起点[1] + (终点[1] - 起点[1]) * 局部;
  const b: number = 起点[2] + (终点[2] - 起点[2]) * 局部;
  return 合成颜色([r, g, b]);
}

/** Blues 9 级锚点（预测以外的大部分蓝色渐变图表） */
const Blues锚点: string[] = [
  '#f7fbff', '#deebf7', '#c6dbef', '#9ecae1', '#6baed6',
  '#4292c6', '#2171b5', '#08519c', '#08306b'
];

/** Greens 9 级锚点（预测图） */
const Greens锚点: string[] = [
  '#f7fcf5', '#e5f5e0', '#c7e9c0', '#a1d99b', '#74c476',
  '#41ab5d', '#238b45', '#006d2c', '#00441b'
];

/** RdYlGn 11 级锚点（难度/易度/可提取性/回答按钮） */
const 红黄绿锚点: string[] = [
  '#a50026', '#d73027', '#f46d43', '#fdae61', '#fee08b',
  '#ffffbf', '#d9ef8b', '#a6d96a', '#66bd63', '#1a9850', '#006837'
];

/** Oranges 9 级锚点（复习图 Learn 系列） */
const 橙色锚点: string[] = [
  '#fff5eb', '#fee6ce', '#fdd0a2', '#fdae6b', '#fd8d3c',
  '#f16913', '#d94801', '#a63603', '#7f2704'
];

/** Reds 9 级锚点（复习图 Relearn 系列） */
const 红色锚点: string[] = [
  '#fff5f0', '#fee0d2', '#fcbba1', '#fc9272', '#fb6a4a',
  '#ef3b2c', '#cb181d', '#a50f15', '#67000d'
];

/** Purples 9 级锚点（复习图 Filtered 系列） */
const 紫色锚点: string[] = [
  '#fcfbfd', '#efedf5', '#dadaeb', '#bcbddc', '#9e9ac8',
  '#807dba', '#6a51a3', '#54278f', '#3f007d'
];

/** Blues 色带（Anki 小时分布 / 间隔 / 稳定度 / 新增 / 日历热力图） */
export function 取蓝色(系数: number): string {
  return 插值(Blues锚点, 系数);
}

/** Greens 色带（Anki 预测图） */
export function 取绿色(系数: number): string {
  return 插值(Greens锚点, 系数);
}

/** RdYlGn 色带（Anki 难度 / 易度 / 可提取性 / 回答按钮） */
export function 取红黄绿(系数: number): string {
  return 插值(红黄绿锚点, 系数);
}

// ── CardCounts（卡片数量）系列色：Anki schemeBlues/Oranges/Reds/Greens[5] 第 2/3 档 ──
export const 色卡片_新卡: string = '#6baed6';
export const 色卡片_学习中: string = '#fd8d3c';
export const 色卡片_重学中: string = '#fb6a4a';
export const 色卡片_年轻: string = '#74c476';
export const 色卡片_成熟: string = '#31a354';
export const 色卡片_已暂停: string = '#FFDC41';
export const 色卡片_已埋藏: string = '#808080';

// ── TrueRetention（真实保留率）系列色 ──
export const 色保留率_年轻: string = '#64c476';
export const 色保留率_成熟: string = '#31a354';

// ── 日历热力图空日色（深色/浅色模式） ──
export const 色日历_空日_深色: string = '#333333';
export const 色日历_空日_浅色: string = '#dddddd';

/**
 * 小时分布柱色：Blues(0.1 + 0.7 × 归一化计数)。
 * 与 Anki HourGraph 一致：无复习很浅蓝（t=0.1），峰值深蓝（t=0.8）。
 */
export function 取小时柱色(归一化计数: number): string {
  return 取蓝色(0.1 + 0.7 * 钳制(归一化计数));
}

/**
 * 预测柱色：Greens(0.7 - 0.4 × 归一化天数)。
 * 与 Anki FutureDue 一致：最近深绿（t=0.7），最远浅绿（t=0.3）。
 */
export function 取预测柱色(归一化天数: number): string {
  return 取绿色(0.7 - 0.4 * 钳制(归一化天数));
}

/**
 * 新增柱色：Blues(0.7 - 0.4 × 归一化天数)。
 * 与 Anki AddedGraph 一致：最近深蓝（t=0.7），最旧浅蓝（t=0.3）。
 */
export function 取新增柱色(归一化天数: number): string {
  return 取蓝色(0.7 - 0.4 * 钳制(归一化天数));
}

/**
 * 间隔/稳定度柱色：Blues(0.3 + 0.4 × 归一化值)。
 * 与 Anki IntervalsGraph/StabilityGraph 一致：小值浅蓝（t=0.3），大值深蓝（t=0.7）。
 */
export function 取间隔柱色(归一化值: number): string {
  return 取蓝色(0.3 + 0.4 * 钳制(归一化值));
}

/**
 * 难度/可提取性柱色：RdYlGn 按值域方向取色。
 * 与 Anki DifficultyGraph 一致：值高 → 红（难度大），值低 → 绿。
 * 归一化值已按调用方语义换算（难度：1=最难；可提取性：0=红，1=绿）。
 */
export function 取难度柱色(归一化难度: number): string {
  return 取红黄绿(1 - 钳制(归一化难度));
}

/** 可提取性柱色：低 → 红，高 → 绿（Anki RetrievabilityGraph domain [0,100]） */
export function 取可提取性柱色(归一化值: number): string {
  return 取红黄绿(钳制(归一化值));
}

/** 回答按钮色：按钮 1-4 → RdYlGn 0/1/3, 2/3, 1（重来红 / 困难黄 / 良好浅绿 / 简单深绿） */
export function 取按钮色(按钮序号: number): string {
  switch (按钮序号) {
    case 1: return 取红黄绿(0);
    case 2: return 取红黄绿(1 / 3);
    case 3: return 取红黄绿(2 / 3);
    case 4: return 取红黄绿(1);
    default: return 取红黄绿(0.5);
  }
}

/**
 * 复习图系列色（Anki ReviewsGraph）：按系列 + 柱位置（0=最旧，1=最新）取色带插值。
 * 系列：0=Mature(Greens 0.4→0.7)、1=Young(Greens 0.3→0.5)、2=Relearn(Reds 0.3→0.5)、
 * 3=Learn(Oranges 0.3→0.5)、4=Filtered(Purples 0.3→0.5)。
 */
export function 取复习系列色(系列: number, 位置: number): string {
  const t: number = 钳制(位置);
  switch (系列) {
    case 0: return 插值(Greens锚点, 0.4 + 0.3 * t);
    case 1: return 插值(Greens锚点, 0.3 + 0.2 * t);
    case 2: return 插值(红色锚点, 0.3 + 0.2 * t);
    case 3: return 插值(橙色锚点, 0.3 + 0.2 * t);
    case 4: return 插值(紫色锚点, 0.3 + 0.2 * t);
    default: return 插值(Blues锚点, 0.5);
  }
}
