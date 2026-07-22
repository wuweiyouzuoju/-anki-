// TtsPlayer：基于 HarmonyOS CoreSpeechKit 的 TTS 朗读播放器（M7 音频方案）。
// 负责 Anki [anki:tts lang=xxx]text[/anki:tts] 标签的本地朗读，与 SoundPlayer 分轨并行。
//
// 串行语义：playQueue/replay 先停后播；onComplete 自动接续下一首；gen 代次防旧回调污染。
// 诊断：全链路 hilog 输出（tag=TtsPlayer），平板上 `hdc shell hilog | grep TtsPlayer`
// 即可看到每一步状态/文字/语言/错误细节。

import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import type { TtsItem } from '../proto/messages/CardRenderingMessages';
import { loadVoicePerson, getVoiceVersion } from '../model/TtsVoiceStore';

const DOMAIN: number = 0x0001;
const TAG: string = 'TtsPlayer';

function logInfo(msg: string, ...args: (string | number)[]): void {
  hilog.info(DOMAIN, TAG, msg, ...args);
}

function logWarn(msg: string, ...args: (string | number)[]): void {
  hilog.warn(DOMAIN, TAG, msg, ...args);
}

function logError(msg: string, ...args: (string | number)[]): void {
  hilog.error(DOMAIN, TAG, msg, ...args);
}

function errText(e: BusinessError | undefined): string {
  if (e === undefined || e === null) {
    return 'undefined';
  }
  const code: number | undefined = e.code;
  const message: string | undefined = e.message;
  if (code !== undefined && message !== undefined) {
    return `code=${code} msg=${message}`;
  }
  if (message !== undefined) {
    return `msg=${message}`;
  }
  return `${e}`;
}

/** Anki 的 lang（如 en_US、zh_CN）转 HarmonyOS CoreSpeechKit 的 language（en-US、zh-CN） */
function toHosLanguage(ankiLang: string): string {
  if (ankiLang === '') {
    return 'en-US';
  }
  // en_US → en-US，zh_CN → zh-CN
  const parts: string[] = ankiLang.split('_');
  if (parts.length === 2) {
    return `${parts[0]}-${parts[1]}`;
  }
  return ankiLang;
}

/**
 * 按语言选音色 person（createEngine 兜底用）。
 *
 * 官方 person 枚举完整列表（华为生态市场"语音播报组件"文档 + 真机 listVoices 实测，OpenHarmony-6.1.1.120）：
 * | 名称              | 数值 | 说明                |
 * |-------------------|------|---------------------|
 * | CN_FEMALE_DEFAULT | 0    | 聆小珊女声（默认）  |
 * | CN_FEMALE         | 13   | 聆小珊女声          |
 * | CN_MALE           | 21   | 凌飞哲男声（GA 可下载）|
 * | US_FEMALE         | 8    | 劳拉女声（无法播放中文文本）|
 *
 * 重要：person=0 不是"兜底值，让系统自动选"，而是 CN_FEMALE_DEFAULT 聆小珊女声默认音色，
 * 与 person=13（CN_FEMALE）功能等价。系统只内置这 4 个 person 枚举。
 *
 * 注意：劳拉女声（US_FEMALE=8）无法播放中文文本——若 zh-CN 文本路由到劳拉会失败，
 * 因此 zh-CN 永远不能返回 person=8。
 *
 * 鸿蒙 CoreSpeechKit 实际只内置了少量 person 枚举（聆小珊/劳拉/凌飞哲等），
 * 多数小语种（ja/ko/fr/de/es 等）没有独立的 person 值。强行编造 person 值会触发
 * 错误码 1002300003 "person not support!"，让 createEngine 直接失败。
 * 因此非中英语种保持 person=0（CN_FEMALE_DEFAULT 聆小珊）是当前最稳妥做法。
 *
 * 优先级：若用户在设置页选定了某 person（见 TtsVoiceStore），createEngine 时用用户选定值；
 * 未选定时再用本函数的兜底值。本函数与 TtsVoiceHelper.personForLanguage 保持语义一致。
 */
function personForLanguage(hosLanguage: string): number {
  if (hosLanguage.startsWith('en')) {
    return 8;
  }
  if (hosLanguage.startsWith('zh')) {
    return 0;
  }
  return 0;
}

/**
 * 鸿蒙 CoreSpeechKit 音色状态：INSTALLED 表示已下载到设备可用，GA 表示可下载但未安装。
 * - 多数设备出厂只预装 zh-CN 音色；en-US 等需用户在系统设置下载。
 * - 用 listVoices 探测目标语言是否有 INSTALLED 音色；没有则降级到 zh-CN（zh-CN 引擎也能读英文）。
 * - listVoices 失败时不阻塞：直接用请求语言试一次，让 createEngine 自己报错再由调用方处理。
 */
function isInstalledVoice(voice: textToSpeech.VoiceInfo, language: string): boolean {
  // VoiceInfo.language 在 SDK 中已声明（since 4.1.0(11)），status 为可选字段（since 5.1.1(19)）。
  // listVoices 返回的 language 用下划线（en_US），CreateEngineParams.language 用连字符（en-US）。
  const voiceLanguage: string = voice.language;
  const voiceStatus: string | undefined = voice.status;
  if (voiceStatus === undefined) {
    return false;
  }
  const normalizedVoice: string = voiceLanguage.replace('_', '-');
  return normalizedVoice === language && voiceStatus === 'INSTALLED';
}

export class TtsPlayer {
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private engineLanguage: string = '';
  // 引擎缓存 key 必须包含 person，否则用户在设置页切换同语种音色后（如 zh-CN 聆小珊→凌飞哲）
  // engineLanguage 没变，缓存命中直接返回旧引擎，新 person 永远不生效（2026-07-21 修）。
  private enginePerson: number = -1;
  // 全局 voice 版本号快照：与 TtsVoiceStore.getVoiceVersion() 对比，变了说明用户在 VoiceGroup 改过音色，
  // 即使 language+person 都没变也要重建引擎（保险，覆盖 invalidateEngineCache 路径之外的边界场景）。
  private engineVoiceVersion: number = -1;
  private queue: TtsItem[] = [];
  private index: number = 0;
  private gen: number = 0;

  /** 顺序朗读一组 TTS items；空列表等价 stop */
  async playQueue(items: TtsItem[]): Promise<void> {
    this.gen++;
    this.queue = items;
    logInfo('playQueue: gen=%{public}d count=%{public}d', this.gen, items.length);
    for (let i: number = 0; i < items.length; i++) {
      logInfo('  queue[%{public}d]=%{public}s lang=%{public}s', i, items[i].text, items[i].language);
    }
    await this.stopInternal();
    if (items.length > 0) {
      await this.startAt(0, this.gen);
    }
  }

  /** 从头重播当前队列 */
  async replay(): Promise<void> {
    if (this.queue.length === 0) {
      logWarn('replay: queue empty, nothing to replay');
      return;
    }
    this.gen++;
    logInfo('replay: gen=%{public}d', this.gen);
    await this.stopInternal();
    await this.startAt(0, this.gen);
  }

  /** 停止并清空队列 */
  async stop(): Promise<void> {
    this.gen++;
    logInfo('stop: gen=%{public}d', this.gen);
    this.queue = [];
    await this.stopInternal();
  }

  /** 页面销毁时释放引擎 */
  async release(): Promise<void> {
    logInfo('release: enter');
    await this.stop();
    if (this.engine !== null) {
      try {
        await this.engine.shutdown();
        logInfo('release: engine.shutdown() ok');
      } catch (error) {
        logWarn('release: engine.shutdown() threw %{public}s', errText(error as BusinessError | undefined));
      }
      this.engine = null;
      this.engineLanguage = '';
      this.enginePerson = -1;
      this.engineVoiceVersion = -1;
    }
  }

  /**
   * 让引擎缓存失效（不立即销毁，下次 ensureEngine 时按当前 storedPerson 重建）。
   * VoiceGroup onSelectClick 后调用，确保用户切换音色后下一张卡用新 person 朗读。
   */
  invalidateEngineCache(): void {
    logInfo('invalidateEngineCache: mark stale (was lang=%{public}s person=%{public}d)',
      this.engineLanguage, this.enginePerson);
    this.enginePerson = -1;
    this.engineVoiceVersion = -1;
  }

  private async stopInternal(): Promise<void> {
    if (this.engine !== null) {
      try {
        await this.engine.stop();
        logInfo('stopInternal: engine.stop() ok');
      } catch (error) {
        logWarn('stopInternal: engine.stop() threw %{public}s', errText(error as BusinessError | undefined));
      }
    }
  }

  /**
   * 探测系统已安装的音色，决定 createEngine 时实际使用的语言。
   * - 已 INSTALLED：用请求语言
   * - 未 INSTALLED：降级到 'zh-CN'（zh-CN 是鸿蒙设备出厂必装的兜底音色）
   * - listVoices 失败：不阻塞，用请求语言直接试（让 createEngine 自己报错由调用方处理）
   */
  private async pickUsableLanguage(requestedLanguage: string): Promise<string> {
    try {
      const query: textToSpeech.VoiceQuery = { requestId: `probe-${Date.now()}`, online: 1 };
      const voices: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(query);
      logInfo('pickUsableLanguage: listVoices count=%{public}d for requested=%{public}s',
        voices.length, requestedLanguage);
      for (let i: number = 0; i < voices.length; i++) {
        const v: textToSpeech.VoiceInfo = voices[i];
        const installed: boolean = isInstalledVoice(v, requestedLanguage);
        logInfo('  voice[%{public}d] installed=%{public}s %{public}s',
          i, installed ? 'YES' : 'NO', JSON.stringify(v));
        if (installed) {
          return requestedLanguage;
        }
      }
      // 请求语言无 INSTALLED 音色 → 检查 zh-CN 是否 INSTALLED
      for (let i: number = 0; i < voices.length; i++) {
        if (isInstalledVoice(voices[i], 'zh-CN')) {
          logWarn('pickUsableLanguage: requested=%{public}s not installed, fallback to zh-CN',
            requestedLanguage);
          return 'zh-CN';
        }
      }
      // zh-CN 也没装（极少见）：仍降级 zh-CN，让 createEngine 走默认路径
      logWarn('pickUsableLanguage: no INSTALLED voice found, fallback zh-CN anyway');
      return 'zh-CN';
    } catch (error) {
      logWarn('pickUsableLanguage: listVoices FAILED %{public}s, use requested lang',
        errText(error as BusinessError | undefined));
      return requestedLanguage;
    }
  }

  private async ensureEngine(language: string): Promise<textToSpeech.TextToSpeechEngine> {
    // 鸿蒙 CoreSpeechKit 多数设备只预装 zh-CN 音色；en-US 等需用户在系统设置下载后才能 createEngine。
    // 这里先按 listVoices 探测音色状态，未 INSTALLED 的语言直接降级到 zh-CN（zh-CN 引擎也能读英文，发音不标准但出声）。
    const fallbackLanguage: string = await this.pickUsableLanguage(language);
    // 优先用用户在设置页选定的 person（聆小珊 13 / 凌飞哲 21 等）；未选定时再用 personForLanguage 兜底。
    // 注意：若用户选定的 person 不在 fallbackLanguage 对应的音色列表中（比如选定 en-US 的 person=8 但降级到 zh-CN），
    // createEngine 会报错 1002300003 person not support。这里按 fallbackLanguage 读取选定的 person；
    // 若该 language 没有选定（返回 0），再用 personForLanguage 兜底，避免传入无效 person。
    const storedPerson: number = await loadVoicePerson(fallbackLanguage);
    const person: number = storedPerson !== 0 ? storedPerson : personForLanguage(fallbackLanguage);
    const currentVoiceVersion: number = getVoiceVersion();
    // 缓存命中条件：engine 存在 + language 一致 + person 一致 + voiceVersion 没变。
    // person 与 voiceVersion 都必须参与缓存 key，否则 VoiceGroup 切换同语种音色后引擎不会重建（2026-07-21 修）。
    if (this.engine !== null && this.engineLanguage === fallbackLanguage
      && this.enginePerson === person && this.engineVoiceVersion === currentVoiceVersion) {
      logInfo('ensureEngine: cache hit, language=%{public}s person=%{public}d voiceVersion=%{public}d',
        fallbackLanguage, person, currentVoiceVersion);
      return this.engine;
    }
    // 语言、person 或 voiceVersion 变了，重建引擎
    if (this.engine !== null) {
      try {
        await this.engine.shutdown();
        logInfo('ensureEngine: old engine.shutdown() ok (lang was %{public}s person was %{public}d voiceVersion was %{public}d)',
          this.engineLanguage, this.enginePerson, this.engineVoiceVersion);
      } catch (error) {
        logWarn('ensureEngine: old engine.shutdown() threw %{public}s', errText(error as BusinessError | undefined));
      }
      this.engine = null;
      this.engineLanguage = '';
      this.enginePerson = -1;
      this.engineVoiceVersion = -1;
    }
    logInfo('ensureEngine: creating engine, requested=%{public}s using=%{public}s person=%{public}d (stored=%{public}d) voiceVersion=%{public}d',
      language, fallbackLanguage, person, storedPerson, currentVoiceVersion);
    const createParams: textToSpeech.CreateEngineParams = {
      language: fallbackLanguage,
      person,
      online: 1,
      extraParams: {}
    };
    this.engine = await textToSpeech.createEngine(createParams);
    this.engineLanguage = fallbackLanguage;
    this.enginePerson = person;
    this.engineVoiceVersion = currentVoiceVersion;
    this.engine.setListener({
      onStart: (requestId: string, response: textToSpeech.StartResponse): void => {
        logInfo('onStart: requestId=%{public}d', requestId);
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
        logInfo('onComplete: requestId=%{public}d → advance to next', requestId);
        this.advance();
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse): void => {
        logInfo('onStop: requestId=%{public}d', requestId);
      },
      onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse): void => {
        // 流式音频回调（本端直接由引擎内部播放，无需处理）
      },
      onError: (requestId: string, errorCode: number, errorMessage: string): void => {
        logError('onError: requestId=%{public}d code=%{public}d msg=%{public}s → advance', requestId, errorCode, errorMessage);
        this.advance();
      }
    });
    logInfo('ensureEngine: created, language=%{public}s', language);
    return this.engine;
  }

  private async startAt(index: number, gen: number): Promise<void> {
    if (gen !== this.gen) {
      logInfo('startAt[%{public}d]: gen stale (got %{public}d, current %{public}d), abort', index, gen, this.gen);
      return;
    }
    if (index >= this.queue.length) {
      logInfo('startAt[%{public}d]: end of queue', index);
      return;
    }
    this.index = index;
    const item: TtsItem = this.queue[index];
    const hosLanguage: string = toHosLanguage(item.language);
    logInfo('startAt[%{public}d]: text="%{public}s" lang=%{public}s → %{public}s',
      index, item.text, item.language, hosLanguage);

    let engine: textToSpeech.TextToSpeechEngine;
    try {
      engine = await this.ensureEngine(hosLanguage);
    } catch (error) {
      logError('startAt[%{public}d]: ensureEngine FAILED %{public}s', index, errText(error as BusinessError | undefined));
      // 引擎创建失败（如系统不支持此语言）：跳到下一项
      await this.startAt(index + 1, gen);
      return;
    }
    if (gen !== this.gen) {
      logInfo('startAt[%{public}d]: gen stale after ensureEngine, abort', index);
      return;
    }
    // requestId 在同一实例内只能用一次，每次 speak 生成新 ID
    const requestId: string = `tts-${gen}-${index}-${Date.now()}`;
    const speakParams: textToSpeech.SpeakParams = {
      requestId,
      extraParams: {}
    };
    try {
      engine.speak(item.text, speakParams);
      logInfo('startAt[%{public}d]: engine.speak("%{public}s") called, requestId=%{public}s',
        index, item.text, requestId);
    } catch (error) {
      logError('startAt[%{public}d]: engine.speak() threw %{public}s → advance', index,
        errText(error as BusinessError | undefined));
      await this.startAt(index + 1, gen);
    }
  }

  private advance(): void {
    const gen: number = this.gen;
    this.startAt(this.index + 1, gen).catch((e: Object): void => {
      logError('advance: startAt(next) rejected %{public}s', errText(e as BusinessError | undefined));
    });
  }
}
