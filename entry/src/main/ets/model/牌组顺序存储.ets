// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_deck_meta';
const 顺序键前缀: string = 'deck_order_';
const 根键后缀: string = 'root';
const 上下文键: string = 'abilityContext';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

function 顺序键(父ID: string): string {
  return 父ID === '' ? `${顺序键前缀}${根键后缀}` : `${顺序键前缀}${父ID}`;
}

export async function 加载牌组顺序(父ID: string): Promise<string[] | null> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return null;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 存在: boolean = await 存储.has(顺序键(父ID));
    if (!存在) {
      return null;
    }
    const 值: preferences.ValueType = await 存储.get(顺序键(父ID), '');
    if (typeof 值 !== 'string' || 值 === '') {
      return null;
    }
    const 解析结果: object = JSON.parse(值);
    if (!Array.isArray(解析结果)) {
      return null;
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
    return null;
  }
}

export async function 加载全部牌组顺序(父ID列表: string[]): Promise<Map<string, string[]>> {
  const 结果: Map<string, string[]> = new Map<string, string[]>();
  if (父ID列表.length === 0) {
    return 结果;
  }
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return 结果;
  }
  const 已处理: Set<string> = new Set<string>();
  for (let i: number = 0; i < 父ID列表.length; i++) {
    const 父ID: string = 父ID列表[i];
    if (已处理.has(父ID)) {
      continue;
    }
    已处理.add(父ID);
    const 顺序: string[] | null = await 加载牌组顺序(父ID);
    if (顺序 !== null) {
      结果.set(父ID, 顺序);
    }
  }
  return 结果;
}

export async function 保存牌组顺序(父ID: string, 子ID列表: string[]): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(顺序键(父ID), JSON.stringify(子ID列表));
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 清除牌组顺序(父ID: string): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 存在: boolean = await 存储.has(顺序键(父ID));
    if (存在) {
      await 存储.delete(顺序键(父ID));
      await 存储.flush();
    }
  } catch (错误) {
  }
}
