// SPDX-License-Identifier: AGPL-3.0-or-later

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { 解析是否深色, 主题模式 } from '../model/主题设置';

const 浅色系统栏色: string = '#F5F7FA';
const 深色系统栏色: string = '#10151D';

function 请求的色彩模式(模式: 主题模式): ConfigurationConstant.ColorMode {
  if (模式 === 'dark') {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  if (模式 === 'light') {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}

export async function 应用系统栏样式(
  上下文: common.UIAbilityContext,
  是否深色: boolean
): Promise<void> {
  try {
    const 主窗口: window.Window = await window.getLastWindow(上下文);
    const 栏色: string = 是否深色 ? 深色系统栏色 : 浅色系统栏色;
    await 主窗口.setWindowSystemBarProperties({
      statusBarColor: 栏色,
      navigationBarColor: 栏色,
      isStatusBarLightIcon: 是否深色,
      isNavigationBarLightIcon: 是否深色
    });
  } catch (错误) {
  }
}

export async function 应用主题(
  上下文: common.UIAbilityContext,
  模式: 主题模式,
  系统深色: boolean
): Promise<void> {
  try {
    上下文.getApplicationContext().setColorMode(请求的色彩模式(模式));
  } catch (错误) {
  }
  await 应用系统栏样式(上下文, 解析是否深色(模式, 系统深色));
}
