import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'jidecards_settings';
const VOICE_PERSON_KEY_PREFIX: string = 'tts_voice_person_';
const CONTEXT_KEY: string = 'abilityContext';
// AppStorage key：voiceVersion 是单调递增的版本号，每次 saveVoicePerson 后 +1。
// TtsPlayer.ensureEngine 通过对比版本号判断缓存是否失效，实现跨组件的"音色变更→引擎重建"通知
// （VoiceGroup 无法直接持有 StudyPage 的 ttsPlayer 实例，用 AppStorage 解耦）。
const VOICE_VERSION_KEY: string = 'tts_voice_version';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

function voicePersonKey(language: string): string {
  return `${VOICE_PERSON_KEY_PREFIX}${language}`;
}

/**
 * 读取 voice 版本号。TtsPlayer.ensureEngine 用此判断是否需要重建引擎。
 * 默认 0；每次 saveVoicePerson 后通过 bumpVoiceVersion +1。
 */
export function getVoiceVersion(): number {
  const v: number | undefined = AppStorage.get<number>(VOICE_VERSION_KEY);
  return v === undefined ? 0 : v;
}

/** 版本号 +1，触发 TtsPlayer 下次 ensureEngine 强制重建引擎。 */
function bumpVoiceVersion(): void {
  AppStorage.setOrCreate<number>(VOICE_VERSION_KEY, getVoiceVersion() + 1);
}

/**
 * 读取某 language 用户选中的 person（createEngine 用）。
 * - 默认返回 0（兜底值，让系统按 language 自动选音色）。
 * - 用户在设置页选定具体音色后，返回该音色的 person 值（如 zh-CN 选凌飞哲返回 21）。
 * - 偏好不可用时返回 0，不中断朗读。
 *
 * 注意：返回的 person 未必仍处于 INSTALLED 状态（用户可能卸载了音色）。
 * 调用方（TtsPlayer）需自行处理 createEngine 失败回退到 0 兜底的情况。
 */
export async function loadVoicePerson(language: string): Promise<number> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return 0;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const value: preferences.ValueType = await store.get(voicePersonKey(language), 0);
    return typeof value === 'number' ? value : 0;
  } catch (error) {
    return 0;
  }
}

/**
 * 保存某 language 用户选中的 person。
 * - 传入 0 表示清除选择，让系统自动选音色。
 * - 传入具体 person（如 13/21）表示选定该音色。
 */
export async function saveVoicePerson(language: string, person: number): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(voicePersonKey(language), person);
    await store.flush();
    // 通知 TtsPlayer 缓存失效：下次 ensureEngine 强制重建，新 person 立即生效。
    bumpVoiceVersion();
  } catch (error) {
    // 偏好不可用时保留当前内存状态，不中断学习入口。
  }
}
