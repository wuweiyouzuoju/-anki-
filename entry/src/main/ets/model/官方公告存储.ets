// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { 官方公告ID有效, 追加已确认官方公告ID } from './官方公告模型';

const 存储名: string = 'jidecards_settings';
const 已确认公告键: string = 'official_announcement_acknowledged_ids_v1';
const 上下文键: string = 'abilityContext';

function 取能力上下文(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined = AppStorage.get<common.UIAbilityContext>(上下文键);
  return context === undefined ? null : context;
}

function 解析已确认ID列表(text: string): string[] {
  try {
    const parsed: string[] = JSON.parse(text) as string[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((item: string): boolean => typeof item === 'string' && 官方公告ID有效(item));
  } catch (error) {
    return [];
  }
}

export async function 读取已确认官方公告ID列表(): Promise<string[]> {
  const context: common.UIAbilityContext | null = 取能力上下文();
  if (context === null) return [];
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, 存储名);
    const value: preferences.ValueType = await store.get(已确认公告键, '[]');
    return typeof value === 'string' ? 解析已确认ID列表(value) : [];
  } catch (error) {
    return [];
  }
}

export async function 是否已确认官方公告(id: string): Promise<boolean> {
  const ids: string[] = await 读取已确认官方公告ID列表();
  return ids.indexOf(id) >= 0;
}

export async function 标记已确认官方公告(id: string): Promise<boolean> {
  if (!官方公告ID有效(id)) return false;
  const context: common.UIAbilityContext | null = 取能力上下文();
  if (context === null) return false;
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, 存储名);
    const currentValue: preferences.ValueType = await store.get(已确认公告键, '[]');
    const current: string[] = typeof currentValue === 'string' ? 解析已确认ID列表(currentValue) : [];
    await store.put(已确认公告键, JSON.stringify(追加已确认官方公告ID(current, id)));
    await store.flush();
    return true;
  } catch (error) {
    return false;
  }
}
