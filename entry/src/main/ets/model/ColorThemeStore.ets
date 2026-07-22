// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DEFAULT_COLOR_THEME, normalizeColorTheme, ColorTheme } from './ColorTheme';

const STORE_NAME: string = 'jidecards_settings';
const COLOR_THEME_KEY: string = 'color_theme';
const CONTEXT_KEY: string = 'abilityContext';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

export async function loadColorTheme(): Promise<ColorTheme> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return DEFAULT_COLOR_THEME;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const value: preferences.ValueType = await store.get(COLOR_THEME_KEY, DEFAULT_COLOR_THEME);
    return typeof value === 'string' ? normalizeColorTheme(value) : DEFAULT_COLOR_THEME;
  } catch (error) {
    return DEFAULT_COLOR_THEME;
  }
}

export async function saveColorTheme(theme: ColorTheme): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(COLOR_THEME_KEY, theme);
    await store.flush();
  } catch (error) {
    // 偏好不可用时保留当前内存状态，不中断学习入口。
  }
}
