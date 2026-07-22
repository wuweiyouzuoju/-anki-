// SPDX-License-Identifier: AGPL-3.0-or-later

import { COLOR_KEYS } from '../model/ColorTheme';

/**
 * 设置面板共享色板：把原 SettingsPanel 中 11 个 isDark 三元颜色判断合并为一张表。
 * 子组件只需 @Prop isDark + 调 settingsPalette(isDark) 即可拿到全部颜色，避免各自重写。
 *
 * primary 字段从 AppStorage 读取（@see COLOR_KEYS.actionPrimary），跟随用户选择的颜色主题：
 * primary 用于 chip 选中态背景——只有当前选中的 chip 被主题色实心包裹。
 * chipBg 用中性浅灰（不跟随主题色），让未选中 chip 在所有主题下视觉一致：
 * 避免选绿时其他 chip 变浅绿、选蓝紫时其他 chip 因饱和度被减到 0 变白色看不出包裹的问题。
 */
export interface SettingsPalette {
  bg: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  textMuted: string;
  divider: string;
  chipBg: string;
  primary: string;
  error: string;
  mask: string;
}

/** 默认主色（极光蓝）作为 AppStorage 未就绪时的兜底。 */
function fallbackPrimary(isDark: boolean): string {
  return isDark ? '#5C84E6' : '#2F5FD0';
}

/** chip 中性背景：浅灰/深灰，不跟随主题色。未选中 chip 在所有主题下视觉一致。 */
function neutralChipBg(isDark: boolean): string {
  return isDark ? '#334155' : '#F1F5F9';
}

/** 从 AppStorage 读当前主题色 actionPrimary；未就绪时回退到极光蓝。 */
function resolvePrimary(isDark: boolean): string {
  const stored: string | undefined = AppStorage.get<string>(COLOR_KEYS.actionPrimary);
  return stored !== undefined && stored !== '' ? stored : fallbackPrimary(isDark);
}

/** chip 中性背景（不读 AppStorage）：未选中 chip 不跟随主题色，只有选中 chip 用 primary 包裹。 */
function resolveChipBg(isDark: boolean): string {
  return neutralChipBg(isDark);
}

/** 按 isDark 一次性生成色板；调用方缓存到本地 const 即可。 */
export function settingsPalette(isDark: boolean): SettingsPalette {
  return isDark ? {
    bg: '#1E293B',
    textPrimary: '#F1F5F9',
    textSecondary: '#CBD5E1',
    textTertiary: '#94A3B8',
    textMuted: '#64748B',
    divider: '#334155',
    chipBg: resolveChipBg(isDark),
    primary: resolvePrimary(isDark),
    error: '#F87171',
    mask: 'rgba(0,0,0,0.40)'
  } : {
    bg: '#FFFFFF',
    textPrimary: '#182230',
    textSecondary: '#475569',
    textTertiary: '#64748B',
    textMuted: '#94A3B8',
    divider: '#F1F5F9',
    chipBg: resolveChipBg(isDark),
    primary: resolvePrimary(isDark),
    error: '#DC2626',
    mask: 'rgba(0,0,0,0.15)'
  };
}

/** chip 文本色：选中白字，未选中跟随次级文本色。 */
export function chipTextColor(palette: SettingsPalette, selected: boolean): string {
  return selected ? '#FFFFFF' : palette.textSecondary;
}
