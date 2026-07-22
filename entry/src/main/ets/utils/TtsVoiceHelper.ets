// SPDX-License-Identifier: AGPL-3.0-or-later

// TtsVoiceHelper：TTS 音色查询与下载的小工具（多语种通用版）。
// 复用 TtsPlayer 中已验证的 isInstalledVoice 判定，提供：
//   - listAllVoices()：调 textToSpeech.listVoices 拉取本机所有可用音色，按 language 聚合
//   - isVoiceInstalled(language)：探测某语种是否有 INSTALLED 音色
//   - downloadVoiceForVoice(language)：调 textToSpeech.downloadVoice 拉起系统下载
//   - personForLanguage(language)：鸿蒙 CoreSpeechKit person 值映射
// 独立于 TtsPlayer 实例，避免与朗读引擎互相影响。
//
// 诊断：tag=TtsVoice，hilog 输出关键节点；平板上 hdc shell hilog | grep TtsVoice 即可看到。

import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError, Callback, ErrorCallback } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'TtsVoice';

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

/** VoiceInfo.language 用下划线（en_US），CreateEngineParams.language 用连字符（en-US），归一化对比。 */
function normalizeLanguage(lang: string): string {
  return lang.replace('_', '-');
}

/** VoiceInfo.language 归一化后与目标 language 比较。 */
function isInstalledVoice(voice: textToSpeech.VoiceInfo, language: string): boolean {
  const voiceLanguage: string = voice.language;
  const voiceStatus: string | undefined = voice.status;
  if (voiceStatus === undefined) {
    return false;
  }
  return normalizeLanguage(voiceLanguage) === language && voiceStatus === 'INSTALLED';
}

/**
 * 鸿蒙 CoreSpeechKit person 值映射（createEngine 兜底用）。
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
 * 多数小语种（ja/ko/fr/de/es 等）没有独立的 person 值。强行编造 person 值会触发
 * 错误码 1002300003 "person not support!"，让 createEngine 直接失败。
 * 因此非中英语种保持 person=0（CN_FEMALE_DEFAULT 聆小珊）是当前最稳妥做法。
 *
 * 本函数返回 createEngine 用的兜底 person。
 * downloadVoice 下载音色时应传具体 person（8/13/21），由 VoiceGroup 从 listVoices 结果选取，
 * 不应使用本函数的兜底值（传 0 下载会报错）。
 */
export function personForLanguage(hosLanguage: string): number {
  if (hosLanguage.startsWith('en')) {
    return 8;
  }
  if (hosLanguage.startsWith('zh')) {
    return 0;
  }
  return 0;
}

/**
 * 鸿蒙 CoreSpeechKit style 字段映射。
 * 'interaction-broadcast' 与文档 downloadVoice 示例一致，多数语种支持。
 * 失败时上层会回调 error，由 UI 提示用户去系统设置手动下载。
 */
function styleForLanguage(hosLanguage: string): string {
  return 'interaction-broadcast';
}

/** 单个音色的详细信息：listAllVoices 返回的行结构（每个 voice 一行，不再按 language 聚合）。 */
export interface VoiceRow {
  /** 归一化后的语言代码，如 'en-US' / 'zh-CN' / 'ja-JP'。 */
  language: string;
  /** 鸿蒙 CoreSpeechKit person 值（8=劳拉 / 13=聆小珊 / 21=凌飞哲 等）。 */
  person: number;
  /** 音色性别（'Female' / 'Male'），来自 VoiceInfo.gender。 */
  gender: string;
  /** 音色描述（如 "中文 聆小珊女声"），来自 VoiceInfo.description。 */
  description: string;
  /** 该音色是否处于 INSTALLED 状态（已安装可用）；GA 表示可下载未安装。 */
  installed: boolean;
}

/** 下载结果：complete 时带 voiceInfo；cancel 时无 payload；error 走 reject 不在此类型中。 */
export interface DownloadResult {
  status: 'complete' | 'cancel';
  voiceInfo?: textToSpeech.VoiceInfo;
}

/**
 * 拉取本机所有可用音色，每个 voice 单独成行（不再按 language 聚合）。
 * - 成功：返回按 language + person 排列的 VoiceRow 列表
 * - 失败：返回空数组让上层显示「读取失败」提示
 *
 * VoiceInfo.description/gender/person 字段直接来自鸿蒙 CoreSpeechKit，
 * 真机实测（OpenHarmony-6.1.1.120）：
 * - person=8 en-US "English US Voice" Female（劳拉）
 * - person=13 zh-CN "中文 聆小珊女声" Female
 * - person=21 zh-CN "中文 凌飞哲男声" Male（GA 可下载）
 */
export async function listAllVoices(): Promise<VoiceRow[]> {
  try {
    const query: textToSpeech.VoiceQuery = { requestId: `list-${Date.now()}`, online: 1 };
    const voices: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(query);
    logInfo('listAllVoices: listVoices count=%{public}d', voices.length);

    const result: VoiceRow[] = [];
    for (let i: number = 0; i < voices.length; i++) {
      const v: textToSpeech.VoiceInfo = voices[i];
      const lang: string = normalizeLanguage(v.language);
      result.push({
        language: lang,
        person: v.person === undefined ? 0 : v.person,
        gender: v.gender === undefined ? '' : v.gender,
        description: v.description === undefined ? '' : v.description,
        installed: isInstalledVoice(v, lang)
      });
    }

    // 按 language 字母序 + person 升序排列，同一语种的音色聚在一起
    result.sort((a: VoiceRow, b: VoiceRow): number => {
      const langCmp: number = a.language.localeCompare(b.language);
      return langCmp !== 0 ? langCmp : a.person - b.person;
    });
    logInfo('listAllVoices: returned %{public}d voices', result.length);
    return result;
  } catch (error) {
    logWarn('listAllVoices: listVoices FAILED %{public}s', errText(error as BusinessError | undefined));
    return [];
  }
}

/** 探测某语种是否已安装音色；listVoices 失败按未安装处理让上层提示用户下载。 */
export async function isVoiceInstalled(language: string): Promise<boolean> {
  try {
    const query: textToSpeech.VoiceQuery = { requestId: `check-${Date.now()}`, online: 1 };
    const voices: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(query);
    logInfo('isVoiceInstalled: listVoices count=%{public}d for %{public}s', voices.length, language);
    for (let i: number = 0; i < voices.length; i++) {
      if (isInstalledVoice(voices[i], language)) {
        logInfo('isVoiceInstalled: %{public}s YES', language);
        return true;
      }
    }
    logInfo('isVoiceInstalled: %{public}s NO', language);
    return false;
  } catch (error) {
    logWarn('isVoiceInstalled: listVoices FAILED %{public}s', errText(error as BusinessError | undefined));
    return false;
  }
}

/**
 * 拉起系统下载指定音色。
 * - Phone/Tablet/2in1 设备：调起系统下载弹窗，用户在弹窗里完成下载。
 * - 完整挂载 start/progress/complete/cancel/error 五个回调（参考官方文档示例）。
 * - complete/cancel/error 任一触发即 settle Promise；complete 时 off 掉所有监听器防内存泄漏。
 * - 用户取消不算错误，调用方按 status='cancel' 区分提示。
 * @param language 鸿蒙格式 'en-US' / 'zh-CN' / 'ja-JP' 等
 * @param person 具体音色 person 值（8=劳拉 / 13=聆小珊 / 21=凌飞哲 等），由 VoiceRow.person 传入；
 *               传 0 会让系统报错（person=0 是 createEngine 兜底值，不是具体音色）
 */
export function downloadVoiceForVoice(language: string, person: number): Promise<DownloadResult> {
  const requestId: string = `dl-${language}-${person}-${Date.now()}`;
  const style: string = styleForLanguage(language);
  // style 必须传有效值（空字符串会触发 1002300009 invalid param）；
  // 'interaction-broadcast' 与 listVoices 返回的音色 style 一致。
  const downloadParams: textToSpeech.VoiceDownload = {
    requestId,
    language,
    person,
    style
  };
  logInfo('downloadVoiceForVoice: %{public}s person=%{public}d requestId=%{public}s',
    language, person, requestId);
  return new Promise<DownloadResult>((resolve: (r: DownloadResult) => void, reject: (e: Error) => void): void => {
    try {
      textToSpeech.downloadVoice(downloadParams, (err: BusinessError, response: textToSpeech.DownloadResponse): void => {
        if (err !== null && err !== undefined) {
          logError('downloadVoiceForVoice: callback err %{public}s', errText(err));
          reject(new Error(errText(err)));
          return;
        }
        if (response === null || response === undefined) {
          logError('downloadVoiceForVoice: callback response undefined');
          reject(new Error('response undefined'));
          return;
        }
        logInfo('downloadVoiceForVoice: callback ok requestId=%{public}s', response.requestId);

        // 五个回调闭包；settled 标志防止 complete/cancel/error 重复 settle
        let settled: boolean = false;

        const startCallback: Callback<string> = (id: string): void => {
          logInfo('downloadVoiceForVoice: on start id=%{public}s', id);
        };
        const progressCallback: Callback<string> = (schedule: string): void => {
          logInfo('downloadVoiceForVoice: on progress schedule=%{public}s', schedule);
        };
        const completeCallback: Callback<textToSpeech.VoiceInfo> = (voiceInfo: textToSpeech.VoiceInfo): void => {
          if (settled) {
            logWarn('downloadVoiceForVoice: on complete after settled, skip');
            return;
          }
          settled = true;
          logInfo('downloadVoiceForVoice: on complete voiceInfo=%{public}s', JSON.stringify(voiceInfo));
          offAllListeners(response, startCallback, progressCallback, completeCallback, cancelCallback, errorCallback);
          resolve({ status: 'complete', voiceInfo });
        };
        const cancelCallback: Callback<string> = (cancelInfo: string): void => {
          if (settled) {
            logWarn('downloadVoiceForVoice: on cancel after settled, skip');
            return;
          }
          settled = true;
          logWarn('downloadVoiceForVoice: on cancel cancelInfo=%{public}s', cancelInfo);
          offAllListeners(response, startCallback, progressCallback, completeCallback, cancelCallback, errorCallback);
          resolve({ status: 'cancel' });
        };
        const errorCallback: ErrorCallback<BusinessError> = (e: BusinessError): void => {
          if (settled) {
            logWarn('downloadVoiceForVoice: on error after settled, skip');
            return;
          }
          settled = true;
          logError('downloadVoiceForVoice: on error %{public}s', errText(e));
          offAllListeners(response, startCallback, progressCallback, completeCallback, cancelCallback, errorCallback);
          reject(new Error(errText(e)));
        };

        try {
          response.on('start', startCallback);
          response.on('progress', progressCallback);
          response.on('complete', completeCallback);
          response.on('cancel', cancelCallback);
          response.on('error', errorCallback);
        } catch (listenErr) {
          logWarn('downloadVoiceForVoice: on() threw %{public}s',
            errText(listenErr as BusinessError | undefined));
          // 监听挂载失败不阻塞 resolve：start 阶段失败时系统会回调 err，这里不提前 settle
        }
      });
    } catch (callErr) {
      logError('downloadVoiceForVoice: downloadVoice threw %{public}s',
        errText(callErr as BusinessError | undefined));
      reject(callErr instanceof Error ? callErr : new Error(errText(callErr as BusinessError | undefined)));
    }
  });
}

/** 统一卸载 5 个监听器，避免内存泄漏。单个 off 失败不影响其他 off。 */
function offAllListeners(
  response: textToSpeech.DownloadResponse,
  start: Callback<string>,
  progress: Callback<string>,
  complete: Callback<textToSpeech.VoiceInfo>,
  cancel: Callback<string>,
  error: ErrorCallback<BusinessError>
): void {
  const offList: Array<() => void> = [
    (): void => response.off('start', start),
    (): void => response.off('progress', progress),
    (): void => response.off('complete', complete),
    (): void => response.off('cancel', cancel),
    (): void => response.off('error', error)
  ];
  for (let i: number = 0; i < offList.length; i++) {
    try {
      offList[i]();
    } catch (e) {
      logWarn('offAllListeners: off[%{public}d] threw %{public}s', i, errText(e as BusinessError | undefined));
    }
  }
}
