// SPDX-License-Identifier: AGPL-3.0-or-later

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

function 规范化语言(语言: string): string {
  return 语言.replace('_', '-');
}

function 音色是否已安装_内部(音色: textToSpeech.VoiceInfo, 语言: string): boolean {
  const 音色语言: string = 音色.language;
  const 音色状态: string | undefined = 音色.status;
  if (音色状态 === undefined) {
    return false;
  }
  return 规范化语言(音色语言) === 语言 && 音色状态 === 'INSTALLED';
}

export function 按语言取音色人物(鸿蒙语言: string): number {
  if (鸿蒙语言.startsWith('en')) {
    return 8;
  }
  if (鸿蒙语言.startsWith('zh')) {
    return 0;
  }
  return 0;
}

function 按语言取样式(鸿蒙语言: string): string {
  return 'interaction-broadcast';
}

export interface 音色行 {
  语言: string;
  人物: number;
  性别: string;
  描述: string;
  已安装: boolean;
}

export interface 下载结果 {
  状态: 'complete' | 'cancel';
  音色信息?: textToSpeech.VoiceInfo;
}

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

export function 下载指定音色(语言: string, 人物: number): Promise<下载结果> {
  const 请求ID: string = `dl-${语言}-${人物}-${Date.now()}`;
  const 样式: string = 按语言取样式(语言);
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
        }
      });
    } catch (调用错误) {
      记录错误('downloadVoiceForVoice: downloadVoice threw %{public}s',
        错误文本(调用错误 as BusinessError | undefined));
      reject(调用错误 instanceof Error ? 调用错误 : new Error(错误文本(调用错误 as BusinessError | undefined)));
    }
  });
}

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
