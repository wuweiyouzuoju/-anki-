// SPDX-License-Identifier: AGPL-3.0-or-later

import { ColorTheme, COLOR_KEYS, resolveColorThemePalette } from '../model/ColorTheme';

/**
 * 颜色主题管理器：把当前 ColorTheme + isDark 解析为 13 个具体 hex 字符串，
 * 写入 AppStorage 中 COLOR_KEYS 对应的 13 个键。
 *
 * 各组件用 @StorageProp 绑定这些键后，主题或深浅色变化时自动重新渲染。
 *
 * 调用时机：
 * - 应用启动（Index.aboutToAppear）：加载持久化的 colorTheme 并 applyColorTheme
 * - 用户在设置页切换颜色主题：changeColorTheme → saveColorTheme + applyColorTheme
 * - 系统深浅色变化（EntryAbility.onConfigurationUpdate）：applyColorTheme(theme, newIsDark)
 *
 * 初次调用前 AppStorage 中无这些键；setOrCreate 会创建，组件 @StorageProp 默认值兜底。
 */
export function applyColorTheme(theme: ColorTheme, isDark: boolean): void {
  const palette = resolveColorThemePalette(theme, isDark);
  // 主色系（8 个）
  AppStorage.setOrCreate<string>(COLOR_KEYS.actionPrimary, palette.actionPrimary);
  AppStorage.setOrCreate<string>(COLOR_KEYS.actionPrimaryHover, palette.actionPrimaryHover);
  AppStorage.setOrCreate<string>(COLOR_KEYS.actionPrimaryActive, palette.actionPrimaryActive);
  AppStorage.setOrCreate<string>(COLOR_KEYS.primaryContainer, palette.primaryContainer);
  AppStorage.setOrCreate<string>(COLOR_KEYS.primaryContainerHover, palette.primaryContainerHover);
  AppStorage.setOrCreate<string>(COLOR_KEYS.primaryBorder, palette.primaryBorder);
  AppStorage.setOrCreate<string>(COLOR_KEYS.primaryIcon, palette.primaryIcon);
  AppStorage.setOrCreate<string>(COLOR_KEYS.primaryText, palette.primaryText);
  // 选中背景（= primaryContainer，保留旧键名兼容既有组件）
  AppStorage.setOrCreate<string>(COLOR_KEYS.surfaceSelected, palette.surfaceSelected);
  // 计数色
  AppStorage.setOrCreate<string>(COLOR_KEYS.countNew, palette.countNew);
  AppStorage.setOrCreate<string>(COLOR_KEYS.countLearning, palette.countLearning);
  AppStorage.setOrCreate<string>(COLOR_KEYS.countReview, palette.countReview);
  // 热力图 4 档
  AppStorage.setOrCreate<string>(COLOR_KEYS.heat1, palette.heat1);
  AppStorage.setOrCreate<string>(COLOR_KEYS.heat2, palette.heat2);
  AppStorage.setOrCreate<string>(COLOR_KEYS.heat3, palette.heat3);
  AppStorage.setOrCreate<string>(COLOR_KEYS.heat4, palette.heat4);
  // 页面背景极淡主题色
  AppStorage.setOrCreate<string>(COLOR_KEYS.surfacePageTint, palette.surfacePageTint);
}
