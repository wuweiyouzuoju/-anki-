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

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<common.UIAbilityContext>('abilityContext', this.context);
    this.refreshSystemDarkMode();
    // DeepLink 跳转：桌面卡片点击 → jidecards://stats → 写 AppStorage 信号让首页 aboutToAppear 跳统计页
    this.处理DeepLink(want);
    hilog.info(DOMAIN, 'jidecards', 'Application created');
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // App 已在后台时，桌面卡片点击 → jidecards://stats → 写 AppStorage 信号让首页监听回调跳统计页
    this.处理DeepLink(want);
  }

  // ========================================================
  // @名称 处理DeepLink
  // @作用 解析 want.uri，若是 jidecards://stats 写 AppStorage 信号 'navigateToStats'
  //       首页 @StorageLink 监听此键变化触发跳转统计页
  // ========================================================
  private 处理DeepLink(want: Want): void {
    const uri: string | undefined = want.uri;
    if (uri === undefined || uri === '') {
      return;
    }
    if (uri === 'jidecards://stats') {
      // 用时间戳作为信号值，确保即使连续两次相同 uri 也能触发 @StorageLink 变化
      AppStorage.setOrCreate<number>('navigateToStats', Date.now());
    }
  }

  onConfigurationUpdate(configuration: Configuration): void {
    const isDark: boolean =
      configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.publishSystemDarkMode(isDark);
    const activeThemeMode: string | undefined = AppStorage.get<string>('themeMode');
    if (activeThemeMode === undefined || activeThemeMode === 'system') {
      应用系统栏样式(this.context, isDark);
    }
    // 系统深浅色变化时颜色主题的浅色/深色套也要同步刷新。
    // AppStorage 中 colorTheme 由 首页.恢复颜色主题 在启动时写入；
    // 若 首页 尚未挂载（极端时序），用默认主题兜底。
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
