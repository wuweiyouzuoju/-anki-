// SPDX-License-Identifier: AGPL-3.0-or-later

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { resolveIsDark, ThemeMode } from '../model/ThemeSettings';

const LIGHT_SYSTEM_BAR: string = '#F5F7FA';
const DARK_SYSTEM_BAR: string = '#10151D';

function requestedColorMode(mode: ThemeMode): ConfigurationConstant.ColorMode {
  if (mode === 'dark') {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  if (mode === 'light') {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}

export async function applySystemBars(
  context: common.UIAbilityContext,
  isDark: boolean
): Promise<void> {
  try {
    const mainWindow: window.Window = await window.getLastWindow(context);
    const barColor: string = isDark ? DARK_SYSTEM_BAR : LIGHT_SYSTEM_BAR;
    await mainWindow.setWindowSystemBarProperties({
      statusBarColor: barColor,
      navigationBarColor: barColor,
      isStatusBarLightIcon: isDark,
      isNavigationBarLightIcon: isDark
    });
  } catch (error) {
    // 窗口尚未就绪或已销毁时，不让主题同步中断页面。
  }
}

export async function applyTheme(
  context: common.UIAbilityContext,
  mode: ThemeMode,
  systemDark: boolean
): Promise<void> {
  try {
    context.getApplicationContext().setColorMode(requestedColorMode(mode));
  } catch (error) {
    // 资源模式切换失败时仍尝试同步系统栏。
  }
  await applySystemBars(context, resolveIsDark(mode, systemDark));
}
