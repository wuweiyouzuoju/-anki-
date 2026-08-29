// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
// 固定代际键：后续普通版本升级不得再次触发本次强制引导。
const 引导完成键: string = 'cloud_deck_required_onboarding_completed_v1';
const 上下文键: string = 'abilityContext';

function 取能力上下文(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return context === undefined ? null : context;
}

/** 读取本机首次云端牌组引导是否已完成；读取失败时允许下次继续展示。 */
export async function 是否已完成云端牌组引导(): Promise<boolean> {
  const context: common.UIAbilityContext | null = 取能力上下文();
  if (context === null) {
    return false;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, 存储名);
    const value: preferences.ValueType = await store.get(引导完成键, false);
    return value === true;
  } catch (error) {
    return false;
  }
}

/** 标记首次云端牌组引导已完成；只有真正落盘后才允许进入软件。 */
export async function 标记已完成云端牌组引导(): Promise<boolean> {
  const context: common.UIAbilityContext | null = 取能力上下文();
  if (context === null) {
    return false;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, 存储名);
    await store.put(引导完成键, true);
    await store.flush();
    return true;
  } catch (error) {
    return false;
  }
}
