// SPDX-License-Identifier: AGPL-3.0-or-later

import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import type { TtsItem } from '../proto/messages/CardRenderingMessages';
import { 加载语音人物, 获取语音版本号 } from '../model/TTS语音存储';

const 域: number = 0x0001;
const 标签: string = 'TtsPlayer';

function 记录信息(消息: string, ...参数: (string | number)[]): void {
  hilog.info(域, 标签, 消息, ...参数);
}

function 记录警告(消息: string, ...参数: (string | number)[]): void {
  hilog.warn(域, 标签, 消息, ...参数);
}

function 记录错误(消息: string, ...参数: (string | number)[]): void {
  hilog.error(域, 标签, 消息, ...参数);
}

function 错误文本(异常: BusinessError | undefined): string {
  if (异常 === undefined || 异常 === null) {
    return 'undefined';
  }
  const 错误码: number | undefined = 异常.code;
  const 错误信息: string | undefined = 异常.message;
  if (错误码 !== undefined && 错误信息 !== undefined) {
    return `code=${错误码} msg=${错误信息}`;
  }
  if (错误信息 !== undefined) {
    return `msg=${错误信息}`;
  }
  return `${异常}`;
}

function 转为鸿蒙语言代码(anki语种: string): string {
  if (anki语种 === '') {
    return 'en-US';
  }
  const 分段: string[] = anki语种.split('_');
  if (分段.length === 2) {
    return `${分段[0]}-${分段[1]}`;
  }
  return anki语种;
}

function 按语言取音色人物(鸿蒙语种: string): number {
  if (鸿蒙语种.startsWith('en')) {
    return 8;
  }
  if (鸿蒙语种.startsWith('zh')) {
    return 0;
  }
  return 0;
}

function 音色是否已安装(音色: textToSpeech.VoiceInfo, 语种: string): boolean {
  const 音色语种: string = 音色.language;
  const 音色状态: string | undefined = 音色.status;
  if (音色状态 === undefined) {
    return false;
  }
  const 归一化音色: string = 音色语种.replace('_', '-');
  return 归一化音色 === 语种 && 音色状态 === 'INSTALLED';
}

export class TTS播放器 {
  private 引擎: textToSpeech.TextToSpeechEngine | null = null;
  private 引擎语言: string = '';
  private 引擎人物: number = -1;
  private 引擎语音版本号: number = -1;
  private 队列: TtsItem[] = [];
  private 索引: number = 0;
  private 代次: number = 0;

  async 播放队列(条目列表: TtsItem[]): Promise<void> {
    this.代次++;
    this.队列 = 条目列表;
    记录信息('playQueue: gen=%{public}d count=%{public}d', this.代次, 条目列表.length);
    for (let i: number = 0; i < 条目列表.length; i++) {
      记录信息('  queue[%{public}d]=%{public}s lang=%{public}s', i, 条目列表[i].text, 条目列表[i].language);
    }
    await this.内部停止();
    if (条目列表.length > 0) {
      await this.从指定位置开始(0, this.代次);
    }
  }

  async 重播(): Promise<void> {
    if (this.队列.length === 0) {
      记录警告('replay: queue empty, nothing to replay');
      return;
    }
    this.代次++;
    记录信息('replay: gen=%{public}d', this.代次);
    await this.内部停止();
    await this.从指定位置开始(0, this.代次);
  }

  async 停止(): Promise<void> {
    this.代次++;
    记录信息('stop: gen=%{public}d', this.代次);
    this.队列 = [];
    await this.内部停止();
  }

  async 释放(): Promise<void> {
    记录信息('release: enter');
    await this.停止();
    if (this.引擎 !== null) {
      try {
        await this.引擎.shutdown();
        记录信息('release: engine.shutdown() ok');
      } catch (错误) {
        记录警告('release: engine.shutdown() threw %{public}s', 错误文本(错误 as BusinessError | undefined));
      }
      this.引擎 = null;
      this.引擎语言 = '';
      this.引擎人物 = -1;
      this.引擎语音版本号 = -1;
    }
  }

  使引擎缓存失效(): void {
    记录信息('invalidateEngineCache: mark stale (was lang=%{public}s person=%{public}d)',
      this.引擎语言, this.引擎人物);
    this.引擎人物 = -1;
    this.引擎语音版本号 = -1;
  }

  private async 内部停止(): Promise<void> {
    if (this.引擎 !== null) {
      try {
        await this.引擎.stop();
        记录信息('stopInternal: engine.stop() ok');
      } catch (错误) {
        记录警告('stopInternal: engine.stop() threw %{public}s', 错误文本(错误 as BusinessError | undefined));
      }
    }
  }

  private async 选取可用语言(请求语种: string): Promise<string> {
    try {
      const 查询: textToSpeech.VoiceQuery = { requestId: `probe-${Date.now()}`, online: 1 };
      const 音色列表: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(查询);
      记录信息('pickUsableLanguage: listVoices count=%{public}d for requested=%{public}s',
        音色列表.length, 请求语种);
      for (let i: number = 0; i < 音色列表.length; i++) {
        const 当前音色: textToSpeech.VoiceInfo = 音色列表[i];
        const 已安装: boolean = 音色是否已安装(当前音色, 请求语种);
        记录信息('  voice[%{public}d] installed=%{public}s %{public}s',
          i, 已安装 ? 'YES' : 'NO', JSON.stringify(当前音色));
        if (已安装) {
          return 请求语种;
        }
      }
      for (let i: number = 0; i < 音色列表.length; i++) {
        if (音色是否已安装(音色列表[i], 'zh-CN')) {
          记录警告('pickUsableLanguage: requested=%{public}s not installed, fallback to zh-CN',
            请求语种);
          return 'zh-CN';
        }
      }
      记录警告('pickUsableLanguage: no INSTALLED voice found, fallback zh-CN anyway');
      return 'zh-CN';
    } catch (错误) {
      记录警告('pickUsableLanguage: listVoices FAILED %{public}s, use requested lang',
        错误文本(错误 as BusinessError | undefined));
      return 请求语种;
    }
  }

  private async 确保引擎(语种: string): Promise<textToSpeech.TextToSpeechEngine> {
    const 兜底语种: string = await this.选取可用语言(语种);
    const 已存储音色人物: number = await 加载语音人物(兜底语种);
    const 音色人物: number = 已存储音色人物 !== 0 ? 已存储音色人物 : 按语言取音色人物(兜底语种);
    const 当前语音版本号: number = 获取语音版本号();
    if (this.引擎 !== null && this.引擎语言 === 兜底语种
      && this.引擎人物 === 音色人物 && this.引擎语音版本号 === 当前语音版本号) {
      记录信息('ensureEngine: cache hit, language=%{public}s person=%{public}d voiceVersion=%{public}d',
        兜底语种, 音色人物, 当前语音版本号);
      return this.引擎;
    }
    if (this.引擎 !== null) {
      try {
        await this.引擎.shutdown();
        记录信息('ensureEngine: old engine.shutdown() ok (lang was %{public}s person was %{public}d voiceVersion was %{public}d)',
          this.引擎语言, this.引擎人物, this.引擎语音版本号);
      } catch (错误) {
        记录警告('ensureEngine: old engine.shutdown() threw %{public}s', 错误文本(错误 as BusinessError | undefined));
      }
      this.引擎 = null;
      this.引擎语言 = '';
      this.引擎人物 = -1;
      this.引擎语音版本号 = -1;
    }
    记录信息('ensureEngine: creating engine, requested=%{public}s using=%{public}s person=%{public}d (stored=%{public}d) voiceVersion=%{public}d',
      语种, 兜底语种, 音色人物, 已存储音色人物, 当前语音版本号);
    const 创建参数: textToSpeech.CreateEngineParams = {
      language: 兜底语种,
      person: 音色人物,
      online: 1,
      extraParams: {}
    };
    this.引擎 = await textToSpeech.createEngine(创建参数);
    this.引擎语言 = 兜底语种;
    this.引擎人物 = 音色人物;
    this.引擎语音版本号 = 当前语音版本号;
    this.引擎.setListener({
      onStart: (请求ID: string, 响应: textToSpeech.StartResponse): void => {
        记录信息('onStart: requestId=%{public}d', 请求ID);
      },
      onComplete: (请求ID: string, 响应: textToSpeech.CompleteResponse): void => {
        记录信息('onComplete: requestId=%{public}d → advance to next', 请求ID);
        this.前进到下一项();
      },
      onStop: (请求ID: string, 响应: textToSpeech.StopResponse): void => {
        记录信息('onStop: requestId=%{public}d', 请求ID);
      },
      onData: (请求ID: string, 音频: ArrayBuffer, 响应: textToSpeech.SynthesisResponse): void => {
      },
      onError: (请求ID: string, 错误码: number, 错误信息: string): void => {
        记录错误('onError: requestId=%{public}d code=%{public}d msg=%{public}s → advance', 请求ID, 错误码, 错误信息);
        this.前进到下一项();
      }
    });
    记录信息('ensureEngine: created, language=%{public}s', 语种);
    return this.引擎;
  }

  private async 从指定位置开始(位置: number, 代次: number): Promise<void> {
    if (代次 !== this.代次) {
      记录信息('startAt[%{public}d]: gen stale (got %{public}d, current %{public}d), abort', 位置, 代次, this.代次);
      return;
    }
    if (位置 >= this.队列.length) {
      记录信息('startAt[%{public}d]: end of queue', 位置);
      return;
    }
    this.索引 = 位置;
    const 当前条目: TtsItem = this.队列[位置];
    const 鸿蒙语种: string = 转为鸿蒙语言代码(当前条目.language);
    记录信息('startAt[%{public}d]: text="%{public}s" lang=%{public}s → %{public}s',
      位置, 当前条目.text, 当前条目.language, 鸿蒙语种);

    let 当前引擎: textToSpeech.TextToSpeechEngine;
    try {
      当前引擎 = await this.确保引擎(鸿蒙语种);
    } catch (错误) {
      记录错误('startAt[%{public}d]: ensureEngine FAILED %{public}s', 位置, 错误文本(错误 as BusinessError | undefined));
      await this.从指定位置开始(位置 + 1, 代次);
      return;
    }
    if (代次 !== this.代次) {
      记录信息('startAt[%{public}d]: gen stale after ensureEngine, abort', 位置);
      return;
    }
    const 请求ID: string = `tts-${代次}-${位置}-${Date.now()}`;
    const 朗读参数: textToSpeech.SpeakParams = {
      requestId: 请求ID,
      extraParams: {}
    };
    try {
      当前引擎.speak(当前条目.text, 朗读参数);
      记录信息('startAt[%{public}d]: engine.speak("%{public}s") called, requestId=%{public}s',
        位置, 当前条目.text, 请求ID);
    } catch (错误) {
      记录错误('startAt[%{public}d]: engine.speak() threw %{public}s → advance', 位置,
        错误文本(错误 as BusinessError | undefined));
      await this.从指定位置开始(位置 + 1, 代次);
    }
  }

  private 前进到下一项(): void {
    const 当后代次: number = this.代次;
    this.从指定位置开始(this.索引 + 1, 当后代次).catch((异常: Object): void => {
      记录错误('advance: startAt(next) rejected %{public}s', 错误文本(异常 as BusinessError | undefined));
    });
  }
}
