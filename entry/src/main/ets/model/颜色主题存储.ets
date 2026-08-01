// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { 默认颜色主题, 规范化颜色主题, 颜色主题 } from './颜色主题';

const 存储名: string = 'jidecards_settings';
const 颜色主题键: string = 'color_theme';
const 上下文键: string = 'abilityContext';

function 取能力上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载颜色主题(): Promise<颜色主题> {
  const 上下文: common.UIAbilityContext | null = 取能力上下文();
  if (上下文 === null) {
    return 默认颜色主题;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(颜色主题键, 默认颜色主题);
    return typeof 值 === 'string' ? 规范化颜色主题(值) : 默认颜色主题;
  } catch (错误) {
    return 默认颜色主题;
  }
}

export async function 保存颜色主题(主题: 颜色主题): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取能力上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(颜色主题键, 主题);
    await 存储.flush();
  } catch (错误) {
  }
}
