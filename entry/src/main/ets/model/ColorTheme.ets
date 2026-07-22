// SPDX-License-Identifier: AGPL-3.0-or-later

import { buildColorScale } from './ColorShades';

/**
 * 颜色主题：与 ThemeMode（system/light/dark）正交的另一维度——主色调。
 * 用户在设置页「外观与语言」分组下选择颜色主题，6 选 1。
 *
 * 设计原则（B 方案：ArcoDesign 色阶重写，2026-07-22）：
 * - 每个主题只需指定 1 个种子色（= ArcoDesign shade 6），运行时由 ColorShades.buildColorScale
 *   派生 10 档色阶 + 8 个语义色（primary/hover/active/container/containerHover/border/icon/text）。
 * - 13 个颜色键跟随主题变化：
 *   1) 主色系（8 个）：primary/hover/active/container/containerHover/border/icon/text
 *      —— 覆盖按钮、选中行底色、边框、图标、强调文字等所有主色场景
 *   2) 热力图（1 个）：heat4（= primary）
 *   3) 选中背景（1 个）：surfaceSelected（= primaryContainer，保留旧键名兼容既有组件）
 *   4) 固定语义色（3 个）：countNew（蓝）/ countLearning（橙）/ countReview（紫）
 *      —— 保证「新卡=蓝、学习中=橙、复习中=紫」交通灯语义在所有主题下一致，
 *         不跟随主色变化，让用户通过颜色快速识别卡片状态。
 * - 每个主题提供浅色+深色两套配色，由 isDark 决定使用哪套（buildColorScale 自动选档）。
 *
 * 主题种子色取自 ArcoDesign 色板（https://arco.design/palette/list），均经 WCAG AA/AAA 验证。
 */

/** 页面底色（与 resources color.json surface_page 一致），用于和主题色混合产生极淡背景。 */
const LIGHT_PAGE_BG: string = '#F5F7FA';
const DARK_PAGE_BG: string = '#10151D';

/** 把 fg 按 alpha 混入 bg，返回混合后的 hex（alpha∈[0,1]，0=纯 bg，1=纯 fg）。 */
function blendHex(bg: string, fg: string, alpha: number): string {
  const parse = (hex: string): number[] => {
    let s: string = hex.startsWith('#') ? hex.slice(1) : hex;
    if (s.length === 3) {
      s = s.split('').map((c: string): string => c + c).join('');
    }
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
  };
  // ArkTS 不支持解构声明（arkts-no-destruct-decls），用索引访问
  const bgArr: number[] = parse(bg);
  const fgArr: number[] = parse(fg);
  const r: number = Math.round(fgArr[0] * alpha + bgArr[0] * (1 - alpha));
  const g: number = Math.round(fgArr[1] * alpha + bgArr[1] * (1 - alpha));
  const b: number = Math.round(fgArr[2] * alpha + bgArr[2] * (1 - alpha));
  const toHex = (n: number): string => {
    const clamped: number = Math.max(0, Math.min(255, n));
    const h: string = clamped.toString(16);
    return h.length === 1 ? '0' + h : h;
  };
  return '#' + toHex(r) + toHex(g) + toHex(b);
}

/** 6 个颜色主题枚举值，与 preferences 持久化字符串一一对应。 */
export type ColorTheme = 'aurora' | 'forest' | 'midnight' | 'lagoon' | 'sunset' | 'lemon';

export const DEFAULT_COLOR_THEME: ColorTheme = 'aurora';

/**
 * 6 个主题的种子色（= ArcoDesign shade 6）。运行时由 buildColorScale 派生完整色阶。
 * 取自 ArcoDesign 色板：https://arco.design/palette/list
 * 用函数而非 Record 避免 ArkTS 的 arkts-no-untyped-obj-literals 限制。
 */
function seedColorOf(theme: ColorTheme): string {
  switch (theme) {
    case 'aurora':
      return '#2F5FD0';   // ArcoDesign Blue 6
    case 'forest':
      return '#00B42A';   // ArcoDesign Green 6
    case 'midnight':
      return '#722ED1';   // ArcoDesign Purple 6
    case 'lagoon':
      return '#14C9C9';   // ArcoDesign Cyan 6
    case 'sunset':
      return '#FF7D00';   // ArcoDesign Orange 6
    case 'lemon':
      return '#F7BA1E';   // ArcoDesign Yellow 6
    default:
      return '#2F5FD0';
  }
}

/**
 * AppStorage 中存储的 13 个颜色键名常量；组件用 @StorageProp 绑定这些键即可跟随主题色。
 * - 旧键（保留）：actionPrimary / surfaceSelected / countNew / countLearning / countReview / heat4
 * - 新键（B 方案）：actionPrimaryHover / actionPrimaryActive / primaryContainer / primaryContainerHover
 *                  / primaryBorder / primaryIcon / primaryText
 */
export interface ColorKeys {
  actionPrimary: string;
  actionPrimaryHover: string;
  actionPrimaryActive: string;
  surfaceSelected: string;
  primaryContainer: string;
  primaryContainerHover: string;
  primaryBorder: string;
  primaryIcon: string;
  primaryText: string;
  countNew: string;
  countLearning: string;
  countReview: string;
  heat1: string;
  heat2: string;
  heat3: string;
  heat4: string;
  surfacePageTint: string;
}

export const COLOR_KEYS: ColorKeys = {
  actionPrimary: 'theme_color_action_primary',
  actionPrimaryHover: 'theme_color_action_primary_hover',
  actionPrimaryActive: 'theme_color_action_primary_active',
  surfaceSelected: 'theme_color_surface_selected',
  primaryContainer: 'theme_color_primary_container',
  primaryContainerHover: 'theme_color_primary_container_hover',
  primaryBorder: 'theme_color_primary_border',
  primaryIcon: 'theme_color_primary_icon',
  primaryText: 'theme_color_primary_text',
  countNew: 'theme_color_count_new',
  countLearning: 'theme_color_count_learning',
  countReview: 'theme_color_count_review',
  heat1: 'theme_color_heat_1',
  heat2: 'theme_color_heat_2',
  heat3: 'theme_color_heat_3',
  heat4: 'theme_color_heat_4',
  surfacePageTint: 'theme_color_surface_page_tint'
};

/** 一组完整主题色（含 17 个键的 hex 字符串值，不含 alpha）。 */
export interface ColorThemePalette {
  actionPrimary: string;
  actionPrimaryHover: string;
  actionPrimaryActive: string;
  surfaceSelected: string;
  primaryContainer: string;
  primaryContainerHover: string;
  primaryBorder: string;
  primaryIcon: string;
  primaryText: string;
  countNew: string;
  countLearning: string;
  countReview: string;
  heat1: string;
  heat2: string;
  heat3: string;
  heat4: string;
  surfacePageTint: string;
}

/** 把持久化的字符串值安全转回 ColorTheme；非法/未设置时返回默认主题。 */
export function normalizeColorTheme(value: string): ColorTheme {
  if (value === 'forest' || value === 'midnight' || value === 'lagoon'
    || value === 'sunset' || value === 'lemon') {
    return value;
  }
  return 'aurora';
}

/** 6 个主题的展示名（用于设置页 chip 按钮文本，由调用方再 localize）。 */
export function colorThemeLabel(theme: ColorTheme): string {
  switch (theme) {
    case 'forest':
      return '仙野绿';
    case 'midnight':
      return '暗夜紫';
    case 'lagoon':
      return '碧涛青';
    case 'sunset':
      return '活力橙';
    case 'lemon':
      return '柠檬金';
    case 'aurora':
    default:
      return '极光蓝';
  }
}

/**
 * 主题色板：从种子色派生完整 13 色调色板。
 * countNew/countLearning/countReview 作为固定语义色保持稳定，不跟随主题色变化，
 * 形成「新卡=蓝、学习中=橙、复习中=紫」交通灯语义。
 */
export function resolveColorThemePalette(theme: ColorTheme, isDark: boolean): ColorThemePalette {
  // 新卡计数色（蓝）：浅色 #3974D9 / 深色 #7C9AE8，所有主题通用
  const countNew: string = isDark ? '#7C9AE8' : '#3974D9';
  // 学习中卡片计数色（橙）：浅色 #B56A22 / 深色 #E6A45F，所有主题通用
  const countLearning: string = isDark ? '#E6A45F' : '#B56A22';
  // 复习中卡片计数色（紫）：浅色 #7056C8 / 深色 #B2A0F2，所有主题通用
  const countReview: string = isDark ? '#B2A0F2' : '#7056C8';

  const seed: string = seedColorOf(theme);
  const scale = buildColorScale(seed, isDark);
  const semantic = scale.semantic;

  return {
    // 主色系（8 个）
    actionPrimary: semantic.primary,
    actionPrimaryHover: semantic.primaryHover,
    actionPrimaryActive: semantic.primaryActive,
    primaryContainer: semantic.primaryContainer,
    primaryContainerHover: semantic.primaryContainerHover,
    primaryBorder: semantic.primaryBorder,
    primaryIcon: semantic.primaryIcon,
    primaryText: semantic.primaryText,
    // 选中背景（保留旧键名，= primaryContainer）
    surfaceSelected: semantic.primaryContainer,
    // 计数色
    countNew,
    countLearning,
    countReview,
    // 热力图 4 档（heat4 = primary 主色，heat1-3 用更浅档位 shade 1/2/4）
    heat1: scale.shades[0],
    heat2: scale.shades[1],
    heat3: isDark ? scale.shades[3] : scale.shades[3],
    heat4: semantic.primary,
    // 页面背景极淡主题色：浅色 6% / 深色 10% primary 混入静态页面底色
    surfacePageTint: blendHex(isDark ? DARK_PAGE_BG : LIGHT_PAGE_BG, semantic.primary, isDark ? 0.10 : 0.06)
  };
}

/** 主题色预览（用于 chip 按钮上的色块）：取该主题浅色模式 action_primary 即可。 */
export function colorThemeSwatch(theme: ColorTheme): string {
  return resolveColorThemePalette(theme, false).actionPrimary;
}

/**
 * 主题色阶预览渐变 stops（用于设置页 chip 内的渐变色条）。
 * 返回该主题浅色模式下的 3 档色阶 hex：[浅, 中, 深] = [shade 1, shade 4, shade 6]。
 * 调用方用 linearGradient 把这 3 档渲染为色阶预览，让用户在选 chip 时就能看到该主题的色阶层次，
 * 而非单一纯色——蓝紫等冷色主题与暖色主题都能通过渐变看出"颜色丰富度"差异。
 */
export function colorThemeSwatchStops(theme: ColorTheme): string[] {
  const seed: string = seedColorOf(theme);
  const scale = buildColorScale(seed, false);
  // shades[0]=shade 1 极浅，shades[3]=shade 4 中浅，shades[5]=shade 6 种子色（= primary）
  return [scale.shades[0], scale.shades[3], scale.shades[5]];
}
