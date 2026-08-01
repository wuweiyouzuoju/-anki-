// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const 音色人物键前缀: string = 'tts_voice_person_';
const 上下文键: string = 'abilityContext';
const 语音版本号键: string = 'tts_voice_version';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

function 音色人物键(语言: string): string {
  return `${音色人物键前缀}${语言}`;
}

export function 获取语音版本号(): number {
  const v: number | undefined = AppStorage.get<number>(语音版本号键);
  return v === undefined ? 0 : v;
}

function 自增语音版本号(): void {
  AppStorage.setOrCreate<number>(语音版本号键, 获取语音版本号() + 1);
}

export async function 加载语音人物(语言: string): Promise<number> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return 0;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(音色人物键(语言), 0);
    return typeof 值 === 'number' ? 值 : 0;
  } catch (错误) {
    return 0;
  }
}

export async function 保存语音人物(语言: string, 音色人物: number): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(音色人物键(语言), 音色人物);
    await 存储.flush();
    自增语音版本号();
  } catch (错误) {
  }
}
