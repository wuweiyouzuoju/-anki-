// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_sync';
const HKEY键: string = 'sync_hkey';
const 端点键: string = 'sync_endpoint';
const 用户名键: string = 'sync_username';
const 上下文键: string = 'abilityContext';

export interface 同步凭证信息 {
  hkey: string;
  username: string;
  endpoint: string;
}

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

function 打开存储(): preferences.Preferences | null {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return null;
  }
  try {
    return preferences.getPreferencesSync(上下文, { name: 存储名 });
  } catch (错误) {
    return null;
  }
}

function 静默落盘(存储: preferences.Preferences): void {
  存储.flush().then((): void => {
  }).catch((): void => {
  });
}

function 读取字符串(存储: preferences.Preferences, 键: string): string {
  const 值: preferences.ValueType = 存储.getSync(键, '');
  return typeof 值 === 'string' ? 值 : '';
}

export function 保存同步凭证(凭证: 同步凭证信息): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.putSync(HKEY键, 凭证.hkey);
    存储.putSync(端点键, 凭证.endpoint);
    存储.putSync(用户名键, 凭证.username);
    静默落盘(存储);
  } catch (错误) {
  }
}

export function 加载同步凭证(): 同步凭证信息 | null {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return null;
  }
  try {
    const hkey: string = 读取字符串(存储, HKEY键);
    if (hkey.length === 0) {
      return null;
    }
    const 信息: 同步凭证信息 = {
      hkey: hkey,
      username: 读取字符串(存储, 用户名键),
      endpoint: 读取字符串(存储, 端点键)
    };
    return 信息;
  } catch (错误) {
    return null;
  }
}

export function 保存同步端点(端点: string): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.putSync(端点键, 端点);
    静默落盘(存储);
  } catch (错误) {
  }
}

export function 清除同步凭证(): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.deleteSync(HKEY键);
    存储.deleteSync(端点键);
    存储.deleteSync(用户名键);
    静默落盘(存储);
  } catch (错误) {
  }
}
