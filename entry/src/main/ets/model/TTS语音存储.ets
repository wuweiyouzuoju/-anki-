// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-TTS-VOICE-001
// @名称 TTS 语音人物偏好持久化
//
// @作用
// 持久化用户在 TTS 设置页选定的「语音人物」(createEngine 的 person 参数)，
// 按语言（如 zh-CN / en-US）独立保存。
// 另维护一个 AppStorage 版本号 tts_voice_version，每次保存后 +1，
// 用于跨组件通知 TtsPlayer 重建引擎（实现「音色变更→引擎重建」解耦）。
//
// @输入
// 无（读取版本/读取音色）；language + person（保存）
//
// @输出
// 获取语音版本号(): number
// 加载语音人物(language): Promise<number>
// 保存语音人物(language, person): Promise<void>
//
// @业务规则
// - loadVoicePerson 默认返回 0（让系统按 language 自动选音色）；
//   用户在设置页选定具体音色后返回该音色的 person 值（如 zh-CN 选凌飞哲返回 21）。
// - 偏好不可用时返回 0，不中断朗读。
// - saveVoicePerson 传入 0 表示清除选择，让系统自动选音色；
//   传入具体 person（如 13/21）表示选定该音色。
//
// @副作用
// 读写 preferences 的 jidecards_settings store；
// 写入 AppStorage 的 tts_voice_version 键。
//
// @注意
// preferences / AppStorage 中的字符串键（'jidecards_settings' /
// 'tts_voice_person_' 前缀 / 'tts_voice_version' / 'abilityContext'）
// 属持久化协议字段，保留英文，不可中文化。
// ========================================================

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const 音色人物键前缀: string = 'tts_voice_person_';
const 上下文键: string = 'abilityContext';
// AppStorage key：voiceVersion 是单调递增的版本号，每次 saveVoicePerson 后 +1。
// TtsPlayer.ensureEngine 通过对比版本号判断缓存是否失效，实现跨组件的"音色变更→引擎重建"通知
// （VoiceGroup 无法直接持有 StudyPage 的 ttsPlayer 实例，用 AppStorage 解耦）。
const 语音版本号键: string = 'tts_voice_version';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

function 音色人物键(语言: string): string {
  return `${音色人物键前缀}${语言}`;
}

// ========================================================
// @块ID MODEL-TTS-VOICE-002
// @名称 获取语音版本号
//
// @作用
// 读取 voice 版本号。TtsPlayer.ensureEngine 用此判断是否需要重建引擎。
//
// @输入
// 无
//
// @输出
// number：当前版本号；默认 0；每次 保存语音人物 后通过 自增语音版本号 +1。
//
// @副作用
// 只读 AppStorage，不写入。
// ========================================================
export function 获取语音版本号(): number {
  const v: number | undefined = AppStorage.get<number>(语音版本号键);
  return v === undefined ? 0 : v;
}

/** 版本号 +1，触发 TtsPlayer 下次 ensureEngine 强制重建引擎。 */
function 自增语音版本号(): void {
  AppStorage.setOrCreate<number>(语音版本号键, 获取语音版本号() + 1);
}

// ========================================================
// @块ID MODEL-TTS-VOICE-003
// @名称 加载语音人物
//
// @作用
// 读取某 language 用户选中的 person（createEngine 用）。
//
// @输入
// language: string - 语言代码（如 'zh-CN'）
//
// @输出
// Promise<number>：person 值；默认 0；偏好不可用时返回 0，不中断朗读。
//
// @业务规则
// 注意：返回的 person 未必仍处于 INSTALLED 状态（用户可能卸载了音色）。
// 调用方（TtsPlayer）需自行处理 createEngine 失败回退到 0 兜底的情况。
//
// @副作用
// 只读 preferences，不写入。
// ========================================================
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

// ========================================================
// @块ID MODEL-TTS-VOICE-004
// @名称 保存语音人物
//
// @作用
// 保存某 language 用户选中的 person。
//
// @输入
// language: string - 语言代码
// person: number - 音色人物值（0=清除选择；具体值如 13/21=选定该音色）
//
// @输出
// Promise<void>
//
// @副作用
// 写入 preferences 的 tts_voice_person_<language> 并 flush 落盘；
// 自增 AppStorage 的 tts_voice_version，通知 TtsPlayer 缓存失效。
// ========================================================
export async function 保存语音人物(语言: string, 音色人物: number): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(音色人物键(语言), 音色人物);
    await 存储.flush();
    // 通知 TtsPlayer 缓存失效：下次 ensureEngine 强制重建，新 person 立即生效。
    自增语音版本号();
  } catch (错误) {
    // 偏好不可用时保留当前内存状态，不中断学习入口。
  }
}
