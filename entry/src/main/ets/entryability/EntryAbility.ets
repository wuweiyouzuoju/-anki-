// SPDX-License-Identifier: AGPL-3.0-or-later

import {
  AbilityConstant,
  common,
  Configuration,
  ConfigurationConstant,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { applySystemBars } from '../utils/ThemeController';
import { applyColorTheme } from '../utils/ColorThemeManager';
import { ColorTheme, DEFAULT_COLOR_THEME, normalizeColorTheme } from '../model/ColorTheme';

const DOMAIN: number = 0x4342;

export default class EntryAbility extends UIAbility {
  private publishSystemDarkMode(isDark: boolean): void {
    AppStorage.setOrCreate<boolean>('systemDarkMode', isDark);
  }

  private refreshSystemDarkMode(): void {
    try {
      const configuration: resourceManager.Configuration =
        this.context.resourceManager.getConfigurationSync();
      this.publishSystemDarkMode(
        configuration.colorMode === resourceManager.ColorMode.DARK
      );
    } catch (error) {
      this.publishSystemDarkMode(false);
    }
  }

  private effectiveDarkMode(): boolean {
    const systemDark: boolean = AppStorage.get<boolean>('systemDarkMode') ?? false;
    const themeMode: string = AppStorage.get<string>('themeMode') ?? 'system';
    if (themeMode === 'dark') {
      return true;
    }
    if (themeMode === 'light') {
      return false;
    }
    return systemDark;
  }

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<common.UIAbilityContext>('abilityContext', this.context);
    this.refreshSystemDarkMode();
    hilog.info(DOMAIN, 'jidecards', 'Application created');
  }

  onConfigurationUpdate(configuration: Configuration): void {
    const isDark: boolean =
      configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.publishSystemDarkMode(isDark);
    const activeThemeMode: string | undefined = AppStorage.get<string>('themeMode');
    if (activeThemeMode === undefined || activeThemeMode === 'system') {
      applySystemBars(this.context, isDark);
    }
    // 系统深浅色变化时颜色主题的浅色/深色套也要同步刷新。
    // AppStorage 中 colorTheme 由 Index.restoreColorTheme 在启动时写入；
    // 若 Index 尚未挂载（极端时序），用默认主题兜底。
    const storedTheme: string | undefined = AppStorage.get<string>('colorTheme');
    const theme: ColorTheme = storedTheme === undefined
      ? DEFAULT_COLOR_THEME
      : normalizeColorTheme(storedTheme);
    applyColorTheme(theme, isDark);
  }

  private retryLoadContent(windowStage: window.WindowStage, remainingAttempts: number): void {
    if (remainingAttempts <= 0) {
      hilog.fatal(DOMAIN, 'jidecards', 'Main page failed to load after retry; giving up');
      return;
    }
    setTimeout(() => {
      windowStage.loadContent('pages/Index', (error: BusinessError) => {
        if (error.code) {
          hilog.error(DOMAIN, 'jidecards', 'Retry failed to load main page: %{public}d', error.code);
          this.retryLoadContent(windowStage, remainingAttempts - 1);
          return;
        }
        applySystemBars(this.context, this.effectiveDarkMode());
      });
    }, 1000);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error: BusinessError) => {
      if (error.code) {
        hilog.error(DOMAIN, 'jidecards', 'Unable to load main page: %{public}d', error.code);
        this.retryLoadContent(windowStage, 1);
        return;
      }
      applySystemBars(this.context, this.effectiveDarkMode());
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'jidecards', 'Window stage destroyed');
  }

  onForeground(): void {
    this.refreshSystemDarkMode();
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'jidecards', 'Application moved to background');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'jidecards', 'Application destroyed');
  }
}
