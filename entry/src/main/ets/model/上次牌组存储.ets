// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_deck_meta';
const 上次牌组键: string = 'last_selected_deck';
const 上下文键: string = 'abilityContext';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载上次牌组ID(): Promise<string> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return '';
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 存在: boolean = await 存储.has(上次牌组键);
    if (!存在) {
      return '';
    }
    const 值: preferences.ValueType = await 存储.get(上次牌组键, '');
    if (typeof 值 !== 'string') {
      return '';
    }
    return 值;
  } catch (错误) {
    return '';
  }
}

export async function 保存上次牌组ID(牌组ID: string): Promise<void> {
  if (牌组ID === '') {
    return;
  }
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(上次牌组键, 牌组ID);
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 清除上次牌组ID(): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.delete(上次牌组键);
    await 存储.flush();
  } catch (错误) {
  }
}
