// SPDX-License-Identifier: AGPL-3.0-or-later

import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const 域: number = 0x0001;
const 标签: string = 'SoundPlayer';
const 状态超时毫秒: number = 3000;

function 记录信息(消息: string, ...参数: (string | number)[]): void {
  hilog.info(域, 标签, 消息, ...参数);
}

function 记录警告(消息: string, ...参数: (string | number)[]): void {
  hilog.warn(域, 标签, 消息, ...参数);
}

function 记录错误(消息: string, ...参数: (string | number)[]): void {
  hilog.error(域, 标签, 消息, ...参数);
}

function 错误文本(e: object | undefined): string {
  if (e === undefined || e === null) {
    return 'undefined';
  }
  const 任意错误 = e as Record<string, Object>;
  const 错误码: number | undefined = 任意错误.code as number | undefined;
  const 错误消息: string | undefined = 任意错误.message as string | undefined;
  if (错误码 !== undefined && 错误消息 !== undefined) {
    return `code=${错误码} msg=${错误消息}`;
  }
  if (错误消息 !== undefined) {
    return `msg=${错误消息}`;
  }
  return `${e}`;
}

export class 声音播放器 {
  private 播放器实例: media.AVPlayer | null = null;
  private 队列: string[] = [];
  private 当前索引: number = 0;
  private 文件描述符: number = -1;
  private 代次: number = 0;
  private 状态定时器ID: number = -1;

  async 播放队列(路径列表: string[]): Promise<void> {
    this.代次++;
    this.队列 = 路径列表;
    记录信息('playQueue: gen=%{public}d count=%{public}d', this.代次, 路径列表.length);
    for (let i: number = 0; i < 路径列表.length; i++) {
      记录信息('  queue[%{public}d]=%{public}s', i, 路径列表[i]);
    }
    await this.停止播放器();
    if (路径列表.length > 0) {
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
    await this.停止播放器();
    await this.从指定位置开始(0, this.代次);
  }

  async 停止(): Promise<void> {
    this.代次++;
    记录信息('stop: gen=%{public}d', this.代次);
    this.队列 = [];
    await this.停止播放器();
  }

  async 释放(): Promise<void> {
    记录信息('release: enter');
    await this.停止();
    this.清除状态定时器();
    if (this.播放器实例 !== null) {
      try {
        await this.播放器实例.release();
        记录信息('release: player.release() ok');
      } catch (错误) {
        记录警告('release: player.release() threw %{public}s', 错误文本(错误 as object | undefined));
      }
      this.播放器实例 = null;
    }
  }

  private async 停止播放器(): Promise<void> {
    this.清除状态定时器();
    if (this.播放器实例 !== null) {
      try {
        await this.播放器实例.reset();
        记录信息('stopPlayer: reset() ok');
      } catch (错误) {
        记录警告('stopPlayer: reset() threw %{public}s', 错误文本(错误 as object | undefined));
      }
    }
    this.关闭文件描述符();
  }

  private async 确保播放器(): Promise<media.AVPlayer> {
    if (this.播放器实例 === null) {
      记录信息('ensurePlayer: creating new AVPlayer');
      this.播放器实例 = await media.createAVPlayer();
      this.挂载监听器(this.播放器实例);
      记录信息('ensurePlayer: created, state=%{public}s', this.播放器实例.state);
    }
    return this.播放器实例;
  }

  private 挂载监听器(播放器: media.AVPlayer): void {
    播放器.on('stateChange', (状态: media.AVPlayerState): void => {
      this.状态变更处理(状态);
    });
    播放器.on('error', (错误: Object): void => {
      记录错误('AVPlayer error event: %{public}s', 错误文本(错误 as object | undefined));
    });
    try {
      播放器.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
      记录信息('attachListeners: audioInterruptMode=SHARE_MODE set');
    } catch (错误) {
      记录警告('attachListeners: audioInterruptMode set failed %{public}s', 错误文本(错误 as object | undefined));
    }
    播放器.on('audioInterrupt', (信息: audio.InterruptEvent): void => {
      记录信息('onAudioInterrupt: eventType=%{public}d forceType=%{public}d hintType=%{public}d',
        信息.eventType, 信息.forceType, 信息.hintType);
    });
  }

  private async 从指定位置开始(索引: number, 代次: number): Promise<void> {
    if (代次 !== this.代次) {
      记录信息('startAt[%{public}d]: gen stale (got %{public}d, current %{public}d), abort', 索引, 代次, this.代次);
      return;
    }
    if (索引 >= this.队列.length) {
      记录信息('startAt[%{public}d]: end of queue', 索引);
      return;
    }
    this.当前索引 = 索引;
    const 播放器: media.AVPlayer = await this.确保播放器();
    if (代次 !== this.代次) {
      记录信息('startAt[%{public}d]: gen stale after ensurePlayer, abort', 索引);
      return;
    }
    const 路径: string = this.队列[索引];
    记录信息('startAt[%{public}d]: path=%{public}s state=%{public}s', 索引, 路径, 播放器.state);

    let 文件存在: boolean = false;
    let 文件大小: number = 0;
    try {
      const 文件信息: fs.Stat = fs.statSync(路径);
      文件存在 = true;
      文件大小 = 文件信息.size;
      记录信息('startAt[%{public}d]: file exists, size=%{public}d bytes', 索引, 文件大小);
    } catch (错误) {
      记录错误('startAt[%{public}d]: fs.statSync FAILED %{public}s', 索引, 错误文本(错误 as object | undefined));
    }
    if (!文件存在) {
      记录错误('startAt[%{public}d]: SKIP - file does not exist', 索引);
      await this.从指定位置开始(索引 + 1, 代次);
      return;
    }
    if (文件大小 <= 0) {
      记录错误('startAt[%{public}d]: SKIP - file is empty', 索引);
      await this.从指定位置开始(索引 + 1, 代次);
      return;
    }

    try {
      await 播放器.reset();
      记录信息('startAt[%{public}d]: reset() ok, state=%{public}s', 索引, 播放器.state);
    } catch (错误) {
      记录警告('startAt[%{public}d]: reset() threw %{public}s, state=%{public}s', 索引,
        错误文本(错误 as object | undefined), 播放器.state);
    }
    if (代次 !== this.代次) {
      记录信息('startAt[%{public}d]: gen stale after reset, abort', 索引);
      return;
    }
    try {
      const 文件: fs.File = fs.openSync(路径, fs.OpenMode.READ_ONLY);
      this.文件描述符 = 文件.fd;
      播放器.fdSrc = { fd: 文件.fd, offset: 0, length: 文件大小 };
      记录信息('startAt[%{public}d]: fdSrc set, fd=%{public}d, state=%{public}s', 索引, 文件.fd, 播放器.state);
      this.安排状态超时(索引, 代次);
      try {
        await 播放器.prepare();
        记录信息('startAt[%{public}d]: prepare() ok, state=%{public}s', 索引, 播放器.state);
      } catch (prepare错误) {
        记录错误('startAt[%{public}d]: prepare() FAILED %{public}s, state=%{public}s', 索引,
          错误文本(prepare错误 as object | undefined), 播放器.state);
      }
      if (代次 !== this.代次) {
        记录信息('startAt[%{public}d]: gen stale after prepare, abort', 索引);
        return;
      }
      try {
        await 播放器.play();
        记录信息('startAt[%{public}d]: play() ok, state=%{public}s', 索引, 播放器.state);
      } catch (play错误) {
        记录错误('startAt[%{public}d]: play() FAILED %{public}s, state=%{public}s', 索引,
          错误文本(play错误 as object | undefined), 播放器.state);
      }
    } catch (错误) {
      记录错误('startAt[%{public}d]: prepare or openSync FAILED %{public}s', 索引, 错误文本(错误 as object | undefined));
      this.关闭文件描述符();
      this.清除状态定时器();
      await this.从指定位置开始(索引 + 1, 代次);
    }
  }

  private 安排状态超时(索引: number, 代次: number): void {
    this.清除状态定时器();
    this.状态定时器ID = setTimeout((): void => {
      if (代次 !== this.代次) {
        记录信息('scheduleStateTimeout[%{public}d]: gen stale, skip', 索引);
        return;
      }
      const 状态: string = this.播放器实例 !== null ? this.播放器实例.state : 'null';
      记录警告('scheduleStateTimeout[%{public}d]: 3s timeout, state=%{public}s, advance to next', 索引, 状态);
      this.关闭文件描述符();
      this.从指定位置开始(索引 + 1, 代次).catch((e: Object): void => {
        记录错误('scheduleStateTimeout: startAt(next) rejected %{public}s', 错误文本(e as object | undefined));
      });
    }, 状态超时毫秒);
  }

  private 清除状态定时器(): void {
    if (this.状态定时器ID !== -1) {
      clearTimeout(this.状态定时器ID);
      this.状态定时器ID = -1;
    }
  }

  private 状态变更处理(状态: media.AVPlayerState): void {
    const 代次: number = this.代次;
    记录信息('stateChange: state=%{public}s gen=%{public}d index=%{public}d', 状态, 代次, this.当前索引);
    if (状态 === 'playing') {
      this.清除状态定时器();
    } else if (状态 === 'initialized' && this.播放器实例 !== null) {
      this.播放器实例.prepare().then((): void => {
        记录信息('stateChange(initialized): prepare() resolved');
      }).catch((e: Object): void => {
        记录错误('stateChange(initialized): prepare() rejected %{public}s', 错误文本(e as object | undefined));
      });
    } else if (状态 === 'prepared' && this.播放器实例 !== null) {
      this.播放器实例.play().then((): void => {
        记录信息('stateChange(prepared): play() resolved');
      }).catch((e: Object): void => {
        记录错误('stateChange(prepared): play() rejected %{public}s', 错误文本(e as object | undefined));
      });
    } else if (状态 === 'completed' || 状态 === 'error') {
      记录信息('stateChange: %{public}s → advance to next track', 状态);
      this.清除状态定时器();
      this.关闭文件描述符();
      this.从指定位置开始(this.当前索引 + 1, 代次).catch((e: Object): void => {
        记录错误('stateChange: startAt(next) rejected %{public}s', 错误文本(e as object | undefined));
      });
    }
  }

  private 关闭文件描述符(): void {
    if (this.文件描述符 >= 0) {
      try {
        fs.closeSync(this.文件描述符);
        记录信息('closeFd: closed fd=%{public}d', this.文件描述符);
      } catch (错误) {
        记录警告('closeFd: closeSync(fd=%{public}d) threw %{public}s', this.文件描述符, 错误文本(错误 as object | undefined));
      }
      this.文件描述符 = -1;
    }
  }
}
