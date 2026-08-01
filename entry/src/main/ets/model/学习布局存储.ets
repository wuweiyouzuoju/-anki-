// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_study_layout';
const 布局模式键: string = 'study_layout_mode';
const 主工具栏X键: string = 'study_main_toolbar_x';
const 主工具栏Y键: string = 'study_main_toolbar_y';
const 辅工具栏X键: string = 'study_aux_toolbar_x';
const 辅工具栏Y键: string = 'study_aux_toolbar_y';
const 上下文键: string = 'abilityContext';

export type 学习布局模式 = 'bottom' | 'float';

export type 学习工具栏标识 = 'main' | 'aux';

export interface 工具栏位置 {
  x: number;
  y: number;
}

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载学习布局模式(): Promise<学习布局模式> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return 'bottom';
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(布局模式键, 'bottom');
    if (typeof 值 === 'string' && (值 === 'bottom' || 值 === 'float')) {
      return 值;
    }
    return 'bottom';
  } catch (错误) {
    return 'bottom';
  }
}

export async function 保存学习布局模式(模式: 学习布局模式): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(布局模式键, 模式);
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 加载工具栏位置(工具栏ID: 学习工具栏标识): Promise<工具栏位置 | null> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return null;
  }
  const X键: string = 工具栏ID === 'main' ? 主工具栏X键 : 辅工具栏X键;
  const Y键: string = 工具栏ID === 'main' ? 主工具栏Y键 : 辅工具栏Y键;
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const X存在: boolean = await 存储.has(X键);
    if (!X存在) {
      return null;
    }
    const X值: preferences.ValueType = await 存储.get(X键, 0);
    const Y值: preferences.ValueType = await 存储.get(Y键, 0);
    if (typeof X值 !== 'number' || typeof Y值 !== 'number') {
      return null;
    }
    const 位置: 工具栏位置 = { x: X值, y: Y值 };
    return 位置;
  } catch (错误) {
    return null;
  }
}

export async function 保存工具栏位置(工具栏ID: 学习工具栏标识, x: number, y: number): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  const X键: string = 工具栏ID === 'main' ? 主工具栏X键 : 辅工具栏X键;
  const Y键: string = 工具栏ID === 'main' ? 主工具栏Y键 : 辅工具栏Y键;
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(X键, x);
    await 存储.put(Y键, y);
    await 存储.flush();
  } catch (错误) {
  }
}
