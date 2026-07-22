// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DEFAULT_THEME_MODE, normalizeThemeMode, ThemeMode } from './ThemeSettings';

const STORE_NAME: string = 'jidecards_settings';
const THEME_KEY: string = 'theme_mode';
const CONTEXT_KEY: string = 'abilityContext';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

export async function loadThemeMode(): Promise<ThemeMode> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return DEFAULT_THEME_MODE;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const value: preferences.ValueType = await store.get(THEME_KEY, DEFAULT_THEME_MODE);
    return typeof value === 'string' ? normalizeThemeMode(value) : DEFAULT_THEME_MODE;
  } catch (error) {
    return DEFAULT_THEME_MODE;
  }
}

export async function saveThemeMode(mode: ThemeMode): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(THEME_KEY, mode);
    await store.flush();
  } catch (error) {
    // 偏好不可用时保留当前内存状态，不中断学习入口。
  }
}
