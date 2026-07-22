// SoundPlayer：原生 AVPlayer 队列播放器（M7 音频方案）。
// 学习页音频改走原生播放：Web <audio> 自动播放受手势策略拦截，真机无声。
// 串行语义：playQueue/replay 先停后播；completed 自动接续下一首；gen 代次防旧回调污染。
//
// 状态机：fdSrc → initialized → prepare → prepared → play → playing → completed → 下一首
// 主路径：startAt 主动调 prepare/play；兜底：stateChange 回调里按状态推进；超时：3s 未进入 playing 跳下一首。
//
// 音频焦点：audioInterruptMode=SHARE_MODE 不抢占其他应用；on('audioInterrupt') 仅记录日志不主动停播。
//
// 诊断：全链路 hilog 输出（tag=SoundPlayer），平板上 `hdc shell hilog | grep SoundPlayer`
// 即可看到每一步状态/文件/错误细节，便于定位真机无声根因。

import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'SoundPlayer';
const STATE_TIMEOUT_MS: number = 3000;

function logInfo(msg: string, ...args: (string | number)[]): void {
  hilog.info(DOMAIN, TAG, msg, ...args);
}

function logWarn(msg: string, ...args: (string | number)[]): void {
  hilog.warn(DOMAIN, TAG, msg, ...args);
}

function logError(msg: string, ...args: (string | number)[]): void {
  hilog.error(DOMAIN, TAG, msg, ...args);
}

function errText(e: object | undefined): string {
  if (e === undefined || e === null) {
    return 'undefined';
  }
  const anyErr = e as Record<string, Object>;
  const code: number | undefined = anyErr.code as number | undefined;
  const message: string | undefined = anyErr.message as string | undefined;
  if (code !== undefined && message !== undefined) {
    return `code=${code} msg=${message}`;
  }
  if (message !== undefined) {
    return `msg=${message}`;
  }
  return `${e}`;
}

export class SoundPlayer {
  private player: media.AVPlayer | null = null;
  private queue: string[] = [];
  private index: number = 0;
  private fd: number = -1;
  private gen: number = 0;
  private stateTimerId: number = -1;

  /** 顺序播放一组音频（沙箱绝对路径）；空列表等价 stop */
  async playQueue(paths: string[]): Promise<void> {
    this.gen++;
    this.queue = paths;
    logInfo('playQueue: gen=%{public}d count=%{public}d', this.gen, paths.length);
    for (let i: number = 0; i < paths.length; i++) {
      logInfo('  queue[%{public}d]=%{public}s', i, paths[i]);
    }
    await this.stopPlayer();
    if (paths.length > 0) {
      await this.startAt(0, this.gen);
    }
  }

  /** 从头重播当前队列（学习页重播按钮） */
  async replay(): Promise<void> {
    if (this.queue.length === 0) {
      logWarn('replay: queue empty, nothing to replay');
      return;
    }
    this.gen++;
    logInfo('replay: gen=%{public}d', this.gen);
    await this.stopPlayer();
    await this.startAt(0, this.gen);
  }

  /** 停止并清空队列 */
  async stop(): Promise<void> {
    this.gen++;
    logInfo('stop: gen=%{public}d', this.gen);
    this.queue = [];
    await this.stopPlayer();
  }

  /** 页面销毁时释放播放器 */
  async release(): Promise<void> {
    logInfo('release: enter');
    await this.stop();
    this.clearStateTimer();
    if (this.player !== null) {
      try {
        await this.player.release();
        logInfo('release: player.release() ok');
      } catch (error) {
        logWarn('release: player.release() threw %{public}s', errText(error as object | undefined));
      }
      this.player = null;
    }
  }

  private async stopPlayer(): Promise<void> {
    this.clearStateTimer();
    if (this.player !== null) {
      try {
        await this.player.reset();
        logInfo('stopPlayer: reset() ok');
      } catch (error) {
        logWarn('stopPlayer: reset() threw %{public}s', errText(error as object | undefined));
      }
    }
    this.closeFd();
  }

  private async ensurePlayer(): Promise<media.AVPlayer> {
    if (this.player === null) {
      logInfo('ensurePlayer: creating new AVPlayer');
      this.player = await media.createAVPlayer();
      this.attachListeners(this.player);
      logInfo('ensurePlayer: created, state=%{public}s', this.player.state);
    }
    return this.player;
  }

  /**
   * 挂载状态机/错误/音频焦点三类监听器。
   * - audioInterruptMode=SHARE_MODE：不抢占其他应用音频焦点，避免被系统强制暂停后无声
   *   （参考腾讯云 https://cloud.tencent.com/developer/article/2474687 与官方文档）
   * - on('audioInterrupt')：仅记录日志，SHARE_MODE 下系统不强制打断，让 AVPlayer 自处理
   */
  private attachListeners(player: media.AVPlayer): void {
    player.on('stateChange', (state: media.AVPlayerState): void => {
      this.onStateChange(state);
    });
    player.on('error', (error: Object): void => {
      logError('AVPlayer error event: %{public}s', errText(error as object | undefined));
    });
    try {
      player.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
      logInfo('attachListeners: audioInterruptMode=SHARE_MODE set');
    } catch (error) {
      logWarn('attachListeners: audioInterruptMode set failed %{public}s', errText(error as object | undefined));
    }
    player.on('audioInterrupt', (info: audio.InterruptEvent): void => {
      logInfo('onAudioInterrupt: eventType=%{public}d forceType=%{public}d hintType=%{public}d',
        info.eventType, info.forceType, info.hintType);
    });
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
    const player: media.AVPlayer = await this.ensurePlayer();
    if (gen !== this.gen) {
      logInfo('startAt[%{public}d]: gen stale after ensurePlayer, abort', index);
      return;
    }
    const path: string = this.queue[index];
    logInfo('startAt[%{public}d]: path=%{public}s state=%{public}s', index, path, player.state);

    // 检查文件是否存在
    let fileExists: boolean = false;
    let fileSize: number = 0;
    try {
      const stat: fs.Stat = fs.statSync(path);
      fileExists = true;
      fileSize = stat.size;
      logInfo('startAt[%{public}d]: file exists, size=%{public}d bytes', index, fileSize);
    } catch (error) {
      logError('startAt[%{public}d]: fs.statSync FAILED %{public}s', index, errText(error as object | undefined));
    }
    if (!fileExists) {
      logError('startAt[%{public}d]: SKIP - file does not exist', index);
      await this.startAt(index + 1, gen);
      return;
    }
    if (fileSize <= 0) {
      logError('startAt[%{public}d]: SKIP - file is empty', index);
      await this.startAt(index + 1, gen);
      return;
    }

    try {
      // completed/error 后必须回 idle 才能换源
      await player.reset();
      logInfo('startAt[%{public}d]: reset() ok, state=%{public}s', index, player.state);
    } catch (error) {
      logWarn('startAt[%{public}d]: reset() threw %{public}s, state=%{public}s', index,
        errText(error as object | undefined), player.state);
    }
    if (gen !== this.gen) {
      logInfo('startAt[%{public}d]: gen stale after reset, abort', index);
      return;
    }
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      this.fd = file.fd;
      player.fdSrc = { fd: file.fd, offset: 0, length: fileSize };
      logInfo('startAt[%{public}d]: fdSrc set, fd=%{public}d, state=%{public}s', index, file.fd, player.state);
      // 启动状态超时定时器：3s 内未进入 playing 则跳下一首，避免 prepare/play hang 住
      this.scheduleStateTimeout(index, gen);
      // 主动 prepare 推进到 prepared：部分系统版本 fdSrc 赋值后不触发 initialized 事件，会导致卡在 idle 无声
      try {
        await player.prepare();
        logInfo('startAt[%{public}d]: prepare() ok, state=%{public}s', index, player.state);
      } catch (prepareError) {
        logError('startAt[%{public}d]: prepare() FAILED %{public}s, state=%{public}s', index,
          errText(prepareError as object | undefined), player.state);
        // 不放弃：stateChange('initialized') 兜底会再调一次 prepare()
      }
      if (gen !== this.gen) {
        logInfo('startAt[%{public}d]: gen stale after prepare, abort', index);
        return;
      }
      // prepare 完成后显式触发 play，不依赖 stateChange('prepared') 回调（部分版本回调时机不稳）
      try {
        await player.play();
        logInfo('startAt[%{public}d]: play() ok, state=%{public}s', index, player.state);
      } catch (playError) {
        logError('startAt[%{public}d]: play() FAILED %{public}s, state=%{public}s', index,
          errText(playError as object | undefined), player.state);
        // 不放弃：stateChange('prepared') 兜底会再调一次 play()
      }
    } catch (error) {
      logError('startAt[%{public}d]: prepare or openSync FAILED %{public}s', index, errText(error as object | undefined));
      this.closeFd();
      this.clearStateTimer();
      await this.startAt(index + 1, gen);
    }
  }

  /**
   * 状态超时定时器：3s 内未进入 playing 状态则跳下一首。
   * 避免 prepare/play hang 住导致整条队列卡死（社区案例：reset 不回 idle、url 更新不同步）。
   */
  private scheduleStateTimeout(index: number, gen: number): void {
    this.clearStateTimer();
    this.stateTimerId = setTimeout((): void => {
      if (gen !== this.gen) {
        logInfo('scheduleStateTimeout[%{public}d]: gen stale, skip', index);
        return;
      }
      const state: string = this.player !== null ? this.player.state : 'null';
      logWarn('scheduleStateTimeout[%{public}d]: 3s timeout, state=%{public}s, advance to next', index, state);
      this.closeFd();
      this.startAt(index + 1, gen).catch((e: Object): void => {
        logError('scheduleStateTimeout: startAt(next) rejected %{public}s', errText(e as object | undefined));
      });
    }, STATE_TIMEOUT_MS);
  }

  private clearStateTimer(): void {
    if (this.stateTimerId !== -1) {
      clearTimeout(this.stateTimerId);
      this.stateTimerId = -1;
    }
  }

  private onStateChange(state: media.AVPlayerState): void {
    const gen: number = this.gen;
    logInfo('stateChange: state=%{public}s gen=%{public}d index=%{public}d', state, gen, this.index);
    if (state === 'playing') {
      // 进入播放态，清除超时定时器
      this.clearStateTimer();
    } else if (state === 'initialized' && this.player !== null) {
      // 兜底：fdSrc 赋值后触发 initialized，若 startAt 中 prepare 失败这里再尝试
      this.player.prepare().then((): void => {
        logInfo('stateChange(initialized): prepare() resolved');
      }).catch((e: Object): void => {
        logError('stateChange(initialized): prepare() rejected %{public}s', errText(e as object | undefined));
      });
    } else if (state === 'prepared' && this.player !== null) {
      // 兜底：若 startAt 中 play() 已失败，这里再尝试一次
      this.player.play().then((): void => {
        logInfo('stateChange(prepared): play() resolved');
      }).catch((e: Object): void => {
        logError('stateChange(prepared): play() rejected %{public}s', errText(e as object | undefined));
      });
    } else if (state === 'completed' || state === 'error') {
      logInfo('stateChange: %{public}s → advance to next track', state);
      this.clearStateTimer();
      this.closeFd();
      this.startAt(this.index + 1, gen).catch((e: Object): void => {
        logError('stateChange: startAt(next) rejected %{public}s', errText(e as object | undefined));
      });
    }
  }

  private closeFd(): void {
    if (this.fd >= 0) {
      try {
        fs.closeSync(this.fd);
        logInfo('closeFd: closed fd=%{public}d', this.fd);
      } catch (error) {
        logWarn('closeFd: closeSync(fd=%{public}d) threw %{public}s', this.fd, errText(error as object | undefined));
      }
      this.fd = -1;
    }
  }
}
