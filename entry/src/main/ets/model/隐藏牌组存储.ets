// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_deck_meta';
const 已隐藏牌组键: string = 'hidden_decks';
const 上下文键: string = 'abilityContext';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载已隐藏牌组ID列表(): Promise<string[]> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return [];
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 存在: boolean = await 存储.has(已隐藏牌组键);
    if (!存在) {
      return [];
    }
    const 值: preferences.ValueType = await 存储.get(已隐藏牌组键, '');
    if (typeof 值 !== 'string' || 值 === '') {
      return [];
    }
    const 解析结果: object = JSON.parse(值);
    if (!Array.isArray(解析结果)) {
      return [];
    }
    const 结果: string[] = [];
    for (let i: number = 0; i < 解析结果.length; i++) {
      const 项: string = 解析结果[i] as string;
      if (typeof 项 === 'string' && 项 !== '') {
        结果.push(项);
      }
    }
    return 结果;
  } catch (错误) {
    return [];
  }
}

export async function 隐藏牌组(牌组ID: string): Promise<void> {
  if (牌组ID === '') {
    return;
  }
  const 当前: string[] = await 加载已隐藏牌组ID列表();
  if (当前.indexOf(牌组ID) >= 0) {
    return;
  }
  当前.push(牌组ID);
  await 写入已隐藏牌组列表(当前);
}

export async function 取消隐藏牌组(牌组ID: string): Promise<void> {
  const 当前: string[] = await 加载已隐藏牌组ID列表();
  const 下一列表: string[] = 当前.filter((id: string): boolean => id !== 牌组ID);
  if (下一列表.length === 当前.length) {
    return;
  }
  await 写入已隐藏牌组列表(下一列表);
}

export async function 取消隐藏全部牌组(): Promise<void> {
  await 写入已隐藏牌组列表([]);
}

async function 写入已隐藏牌组列表(牌组ID列表: string[]): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(已隐藏牌组键, JSON.stringify(牌组ID列表));
    await 存储.flush();
  } catch (错误) {
  }
}
