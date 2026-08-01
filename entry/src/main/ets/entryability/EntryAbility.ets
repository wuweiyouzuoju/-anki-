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
import { 应用系统栏样式 } from '../utils/主题控制器';
import { 应用颜色主题 } from '../utils/颜色主题管理器';
import { 颜色主题, 默认颜色主题, 规范化颜色主题 } from '../model/颜色主题';

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
      应用系统栏样式(this.context, isDark);
    }
    const storedTheme: string | undefined = AppStorage.get<string>('colorTheme');
    const theme: 颜色主题 = storedTheme === undefined
      ? 默认颜色主题
      : 规范化颜色主题(storedTheme);
    应用颜色主题(theme, isDark);
  }

  private retryLoadContent(windowStage: window.WindowStage, remainingAttempts: number): void {
    if (remainingAttempts <= 0) {
      hilog.fatal(DOMAIN, 'jidecards', 'Main page failed to load after retry; giving up');
      return;
    }
    setTimeout(() => {
      windowStage.loadContent('pages/首页', (error: BusinessError) => {
        if (error.code) {
          hilog.error(DOMAIN, 'jidecards', 'Retry failed to load main page: %{public}d', error.code);
          this.retryLoadContent(windowStage, remainingAttempts - 1);
          return;
        }
        应用系统栏样式(this.context, this.effectiveDarkMode());
      });
    }, 1000);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/首页', (error: BusinessError) => {
      if (error.code) {
        hilog.error(DOMAIN, 'jidecards', 'Unable to load main page: %{public}d', error.code);
        this.retryLoadContent(windowStage, 1);
        return;
      }
      应用系统栏样式(this.context, this.effectiveDarkMode());
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
