// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { 默认主题模式, 规范化主题模式, 主题模式 } from './主题设置';

const 存储名: string = 'jidecards_settings';
const 主题模式键: string = 'theme_mode';
const 上下文键: string = 'abilityContext';

function 取能力上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载主题模式(): Promise<主题模式> {
  const 上下文: common.UIAbilityContext | null = 取能力上下文();
  if (上下文 === null) {
    return 默认主题模式;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(主题模式键, 默认主题模式);
    return typeof 值 === 'string' ? 规范化主题模式(值) : 默认主题模式;
  } catch (错误) {
    return 默认主题模式;
  }
}

export async function 保存主题模式(模式: 主题模式): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取能力上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(主题模式键, 模式);
    await 存储.flush();
  } catch (错误) {
  }
}
