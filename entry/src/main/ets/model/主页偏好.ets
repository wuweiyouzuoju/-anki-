// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const 显示今日进度卡键: string = 'home_show_today_summary';
const 摘要展开状态键: string = 'home_summary_expanded';
const 上下文键: string = 'abilityContext';

export const 主页今日进度卡AppStorage键: string = 'homeShowTodaySummary';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载显示今日进度卡(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return true;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(显示今日进度卡键, true);
    return 值 !== false;
  } catch (错误) {
    return true;
  }
}

export async function 保存显示今日进度卡(开启: boolean): Promise<void> {
  AppStorage.setOrCreate<boolean>(主页今日进度卡AppStorage键, 开启);
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(显示今日进度卡键, 开启);
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 加载摘要展开状态(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return false;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(摘要展开状态键, false);
    return 值 === true;
  } catch (错误) {
    return false;
  }
}

export async function 保存摘要展开状态(展开: boolean): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(摘要展开状态键, 展开);
    await 存储.flush();
  } catch (错误) {
  }
}
