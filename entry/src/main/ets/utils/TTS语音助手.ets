// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UTIL-TTS-VOICE-HELPER-001
// @名称 TTS语音助手边界
//
// @作用
// TTS 音色查询与下载的小工具（多语种通用版）。
// 复用 TtsPlayer 中已验证的 音色是否已安装_内部 判定，提供：
//   - 列出全部音色()：调 textToSpeech.listVoices 拉取本机所有可用音色，按 语言 聚合
//   - 音色是否已安装(语言)：探测某语种是否有 INSTALLED 音色
//   - 下载指定音色(语言, 人物)：调 textToSpeech.downloadVoice 拉起系统下载
//   - 按语言取音色人物(语言)：鸿蒙 CoreSpeechKit person 值映射
// 独立于 TtsPlayer 实例，避免与朗读引擎互相影响。
//
// 诊断：tag=TtsVoice，hilog 输出关键节点；平板上 hdc shell hilog | grep TtsVoice 即可看到。
//
// @输入
// 鸿蒙格式语言代码（en-US / zh-CN / ja-JP 等）
//
// @输出
// 音色行列表 / 是否已安装 / 下载结果 Promise
//
// @业务规则
// INSTALLED 状态判定需归一化语言代码（下划线 vs 连字符）。
// 下载音色须传具体 person 值，不能传 0。
//
// @副作用
// 调用鸿蒙 CoreSpeechKit API（listVoices / downloadVoice）；
// 下载期间注册/卸载 5 个监听器；hilog 日志输出。
// ========================================================

import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError, Callback, ErrorCallback } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const 域: number = 0x0001;
const 标签: string = 'TtsVoice';

function 记录信息(消息: string, ...参数: (string | number)[]): void {
  hilog.info(域, 标签, 消息, ...参数);
}

function 记录警告(消息: string, ...参数: (string | number)[]): void {
  hilog.warn(域, 标签, 消息, ...参数);
}

function 记录错误(消息: string, ...参数: (string | number)[]): void {
  hilog.error(域, 标签, 消息, ...参数);
}

function 错误文本(e: BusinessError | undefined): string {
  if (e === undefined || e === null) {
    return 'undefined';
  }
  const 错误码: number | undefined = e.code;
  const 错误消息: string | undefined = e.message;
  if (错误码 !== undefined && 错误消息 !== undefined) {
    return `code=${错误码} msg=${错误消息}`;
  }
  if (错误消息 !== undefined) {
    return `msg=${错误消息}`;
  }
  return `${e}`;
}

/**
 * VoiceInfo.language 用下划线（en_US），CreateEngineParams.language 用连字符（en-US），归一化对比。
 */
function 规范化语言(语言: string): string {
  return 语言.replace('_', '-');
}

/** VoiceInfo.language 归一化后与目标 language 比较。 */
function 音色是否已安装_内部(音色: textToSpeech.VoiceInfo, 语言: string): boolean {
  const 音色语言: string = 音色.language;
  const 音色状态: string | undefined = 音色.status;
  if (音色状态 === undefined) {
    return false;
  }
  return 规范化语言(音色语言) === 语言 && 音色状态 === 'INSTALLED';
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-002
 * @名称 按语言取音色人物
 *
 * @作用
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
 * downloadVoice 下载音色时应传具体 person（8/13/21），由 音色行 从 listVoices 结果选取，
 * 不应使用本函数的兜底值（传 0 下载会报错）。
 *
 * @输入
 * hosLanguage: 鸿蒙格式语言代码
 *
 * @输出
 * person 数值（0 或 8）
 *
 * @副作用
 * 无
 * ========================================================
 */
export function 按语言取音色人物(鸿蒙语言: string): number {
  if (鸿蒙语言.startsWith('en')) {
    return 8;
  }
  if (鸿蒙语言.startsWith('zh')) {
    return 0;
  }
  return 0;
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-003
 * @名称 按语言取样式
 *
 * @作用
 * 鸿蒙 CoreSpeechKit style 字段映射。
 * 'interaction-broadcast' 与文档 downloadVoice 示例一致，多数语种支持。
 * 失败时上层会回调 error，由 UI 提示用户去系统设置手动下载。
 *
 * @输入
 * hosLanguage: 鸿蒙格式语言代码
 *
 * @输出
 * style 字符串
 *
 * @副作用
 * 无
 * ========================================================
 */
function 按语言取样式(鸿蒙语言: string): string {
  return 'interaction-broadcast';
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-004
 * @名称 音色行
 *
 * @作用
 * 单个音色的详细信息：列出全部音色 返回的行结构（每个 voice 一行，不再按 language 聚合）。
 *
 * @输入
 * 无（类型定义）
 *
 * @输出
 * 无（类型定义）
 *
 * @副作用
 * 无
 * ========================================================
 */
export interface 音色行 {
  /** 归一化后的语言代码，如 'en-US' / 'zh-CN' / 'ja-JP'。 */
  语言: string;
  /** 鸿蒙 CoreSpeechKit person 值（8=劳拉 / 13=聆小珊 / 21=凌飞哲 等）。 */
  人物: number;
  /** 音色性别（'Female' / 'Male'），来自 VoiceInfo.gender。 */
  性别: string;
  /** 音色描述（如 "中文 聆小珊女声"），来自 VoiceInfo.description。 */
  描述: string;
  /** 该音色是否处于 INSTALLED 状态（已安装可用）；GA 表示可下载未安装。 */
  已安装: boolean;
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-005
 * @名称 下载结果
 *
 * @作用
 * 下载结果：complete 时带 音色信息；cancel 时无 payload；error 走 reject 不在此类型中。
 *
 * @输入
 * 无（类型定义）
 *
 * @输出
 * 无（类型定义）
 *
 * @副作用
 * 无
 * ========================================================
 */
export interface 下载结果 {
  状态: 'complete' | 'cancel';
  音色信息?: textToSpeech.VoiceInfo;
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-006
 * @名称 列出全部音色
 *
 * @作用
 * 拉取本机所有可用音色，每个 voice 单独成行（不再按 language 聚合）。
 * - 成功：返回按 语言 + 人物 排列的 音色行 列表
 * - 失败：返回空数组让上层显示「读取失败」提示
 *
 * VoiceInfo.description/gender/person 字段直接来自鸿蒙 CoreSpeechKit，
 * 真机实测（OpenHarmony-6.1.1.120）：
 * - person=8 en-US "English US Voice" Female（劳拉）
 * - person=13 zh-CN "中文 聆小珊女声" Female
 * - person=21 zh-CN "中文 凌飞哲男声" Male（GA 可下载）
 *
 * @输入
 * 无
 *
 * @输出
 * Promise<音色行[]>：失败时返回空数组
 *
 * @副作用
 * 调用 textToSpeech.listVoices（异步网络/系统调用）。
 * ========================================================
 */
export async function 列出全部音色(): Promise<音色行[]> {
  try {
    const 查询: textToSpeech.VoiceQuery = { requestId: `list-${Date.now()}`, online: 1 };
    const 音色列表: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(查询);
    记录信息('listAllVoices: listVoices count=%{public}d', 音色列表.length);

    const 结果: 音色行[] = [];
    for (let i: number = 0; i < 音色列表.length; i++) {
      const 当前音色: textToSpeech.VoiceInfo = 音色列表[i];
      const 语言: string = 规范化语言(当前音色.language);
      结果.push({
        语言: 语言,
        人物: 当前音色.person === undefined ? 0 : 当前音色.person,
        性别: 当前音色.gender === undefined ? '' : 当前音色.gender,
        描述: 当前音色.description === undefined ? '' : 当前音色.description,
        已安装: 音色是否已安装_内部(当前音色, 语言)
      });
    }

    // 按 语言 字母序 + 人物 升序排列，同一语种的音色聚在一起
    结果.sort((a: 音色行, b: 音色行): number => {
      const 语言比较: number = a.语言.localeCompare(b.语言);
      return 语言比较 !== 0 ? 语言比较 : a.人物 - b.人物;
    });
    记录信息('listAllVoices: returned %{public}d voices', 结果.length);
    return 结果;
  } catch (错误) {
    记录警告('listAllVoices: listVoices FAILED %{public}s', 错误文本(错误 as BusinessError | undefined));
    return [];
  }
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-007
 * @名称 音色是否已安装
 *
 * @作用
 * 探测某语种是否已安装音色；listVoices 失败按未安装处理让上层提示用户下载。
 *
 * @输入
 * language: 鸿蒙格式语言代码（en-US / zh-CN 等）
 *
 * @输出
 * Promise<boolean>：true 表示存在 INSTALLED 音色
 *
 * @副作用
 * 调用 textToSpeech.listVoices。
 * ========================================================
 */
export async function 音色是否已安装(语言: string): Promise<boolean> {
  try {
    const 查询: textToSpeech.VoiceQuery = { requestId: `check-${Date.now()}`, online: 1 };
    const 音色列表: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(查询);
    记录信息('isVoiceInstalled: listVoices count=%{public}d for %{public}s', 音色列表.length, 语言);
    for (let i: number = 0; i < 音色列表.length; i++) {
      if (音色是否已安装_内部(音色列表[i], 语言)) {
        记录信息('isVoiceInstalled: %{public}s YES', 语言);
        return true;
      }
    }
    记录信息('isVoiceInstalled: %{public}s NO', 语言);
    return false;
  } catch (错误) {
    记录警告('isVoiceInstalled: listVoices FAILED %{public}s', 错误文本(错误 as BusinessError | undefined));
    return false;
  }
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-008
 * @名称 下载指定音色
 *
 * @作用
 * 拉起系统下载指定音色。
 * - Phone/Tablet/2in1 设备：调起系统下载弹窗，用户在弹窗里完成下载。
 * - 完整挂载 start/progress/complete/cancel/error 五个回调（参考官方文档示例）。
 * - complete/cancel/error 任一触发即 settle Promise；complete 时 off 掉所有监听器防内存泄漏。
 * - 用户取消不算错误，调用方按 状态='cancel' 区分提示。
 *
 * @输入
 * language: 鸿蒙格式 'en-US' / 'zh-CN' / 'ja-JP' 等
 * person: 具体音色 person 值（8=劳拉 / 13=聆小珊 / 21=凌飞哲 等），由 音色行.人物 传入；
 *         传 0 会让系统报错（person=0 是 createEngine 兜底值，不是具体音色）
 *
 * @输出
 * Promise<下载结果>：complete / cancel 任一触发后 resolve；error 走 reject
 *
 * @副作用
 * 调用 textToSpeech.downloadVoice；注册 5 个监听器；下载完成后调用 off 卸载。
 * ========================================================
 */
export function 下载指定音色(语言: string, 人物: number): Promise<下载结果> {
  const 请求ID: string = `dl-${语言}-${人物}-${Date.now()}`;
  const 样式: string = 按语言取样式(语言);
  // style 必须传有效值（空字符串会触发 1002300009 invalid param）；
  // 'interaction-broadcast' 与 listVoices 返回的音色 style 一致。
  const 下载参数: textToSpeech.VoiceDownload = {
    requestId: 请求ID,
    language: 语言,
    person: 人物,
    style: 样式
  };
  记录信息('downloadVoiceForVoice: %{public}s person=%{public}d requestId=%{public}s',
    语言, 人物, 请求ID);
  return new Promise<下载结果>((resolve: (r: 下载结果) => void, reject: (e: Error) => void): void => {
    try {
      textToSpeech.downloadVoice(下载参数, (错误: BusinessError, 响应: textToSpeech.DownloadResponse): void => {
        if (错误 !== null && 错误 !== undefined) {
          记录错误('downloadVoiceForVoice: callback err %{public}s', 错误文本(错误));
          reject(new Error(错误文本(错误)));
          return;
        }
        if (响应 === null || 响应 === undefined) {
          记录错误('downloadVoiceForVoice: callback response undefined');
          reject(new Error('response undefined'));
          return;
        }
        记录信息('downloadVoiceForVoice: callback ok requestId=%{public}s', 响应.requestId);

        // 五个回调闭包；已结算 标志防止 complete/cancel/error 重复 settle
        let 已结算: boolean = false;

        const 开始回调: Callback<string> = (id: string): void => {
          记录信息('downloadVoiceForVoice: on start id=%{public}s', id);
        };
        const 进度回调: Callback<string> = (进度: string): void => {
          记录信息('downloadVoiceForVoice: on progress schedule=%{public}s', 进度);
        };
        const 完成回调: Callback<textToSpeech.VoiceInfo> = (音色信息: textToSpeech.VoiceInfo): void => {
          if (已结算) {
            记录警告('downloadVoiceForVoice: on complete after settled, skip');
            return;
          }
          已结算 = true;
          记录信息('downloadVoiceForVoice: on complete voiceInfo=%{public}s', JSON.stringify(音色信息));
          关闭所有监听器(响应, 开始回调, 进度回调, 完成回调, 取消回调, 错误回调);
          resolve({ 状态: 'complete', 音色信息: 音色信息 });
        };
        const 取消回调: Callback<string> = (取消信息: string): void => {
          if (已结算) {
            记录警告('downloadVoiceForVoice: on cancel after settled, skip');
            return;
          }
          已结算 = true;
          记录警告('downloadVoiceForVoice: on cancel cancelInfo=%{public}s', 取消信息);
          关闭所有监听器(响应, 开始回调, 进度回调, 完成回调, 取消回调, 错误回调);
          resolve({ 状态: 'cancel' });
        };
        const 错误回调: ErrorCallback<BusinessError> = (e: BusinessError): void => {
          if (已结算) {
            记录警告('downloadVoiceForVoice: on error after settled, skip');
            return;
          }
          已结算 = true;
          记录错误('downloadVoiceForVoice: on error %{public}s', 错误文本(e));
          关闭所有监听器(响应, 开始回调, 进度回调, 完成回调, 取消回调, 错误回调);
          reject(new Error(错误文本(e)));
        };

        try {
          响应.on('start', 开始回调);
          响应.on('progress', 进度回调);
          响应.on('complete', 完成回调);
          响应.on('cancel', 取消回调);
          响应.on('error', 错误回调);
        } catch (监听错误) {
          记录警告('downloadVoiceForVoice: on() threw %{public}s',
            错误文本(监听错误 as BusinessError | undefined));
          // 监听挂载失败不阻塞 resolve：start 阶段失败时系统会回调 err，这里不提前 settle
        }
      });
    } catch (调用错误) {
      记录错误('downloadVoiceForVoice: downloadVoice threw %{public}s',
        错误文本(调用错误 as BusinessError | undefined));
      reject(调用错误 instanceof Error ? 调用错误 : new Error(错误文本(调用错误 as BusinessError | undefined)));
    }
  });
}

/**
 * ========================================================
 * @块ID UTIL-TTS-VOICE-HELPER-009
 * @名称 关闭所有监听器
 *
 * @作用
 * 统一卸载 5 个监听器，避免内存泄漏。单个 off 失败不影响其他 off。
 *
 * @输入
 * response: 下载响应对象
 * start / progress / complete / cancel / error: 各回调引用
 *
 * @输出
 * 无
 *
 * @副作用
 * 调用 response.off() 5 次。
 * ========================================================
 */
function 关闭所有监听器(
  响应: textToSpeech.DownloadResponse,
  开始: Callback<string>,
  进度: Callback<string>,
  完成: Callback<textToSpeech.VoiceInfo>,
  取消: Callback<string>,
  错误: ErrorCallback<BusinessError>
): void {
  const 卸载列表: Array<() => void> = [
    (): void => 响应.off('start', 开始),
    (): void => 响应.off('progress', 进度),
    (): void => 响应.off('complete', 完成),
    (): void => 响应.off('cancel', 取消),
    (): void => 响应.off('error', 错误)
  ];
  for (let i: number = 0; i < 卸载列表.length; i++) {
    try {
      卸载列表[i]();
    } catch (e) {
      记录警告('offAllListeners: off[%{public}d] threw %{public}s', i, 错误文本(e as BusinessError | undefined));
    }
  }
}
