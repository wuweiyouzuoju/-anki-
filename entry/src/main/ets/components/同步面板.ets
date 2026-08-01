// SPDX-License-Identifier: AGPL-3.0-or-later

import { 同步服务 } from '../backend/同步服务';
import { 后端错误 } from '../backend/错误类型';
import type {
  MediaSyncStatusResponse,
  SyncAuth,
  SyncCollectionResponse,
  SyncStatusResponse
} from '../proto/messages/SyncMessages';
import {
  清除同步凭证,
  保存同步端点
} from '../model/同步凭证存储';
import {
  应用新端点,
  分类同步错误,
  判定集合同步走向,
  判定同步动作,
  提取新端点
} from '../model/同步流程';
import type { 集合同步结果走向, 同步状态动作 } from '../model/同步流程';
import { 设置面板色板_取, 设置面板色板 } from '../utils/设置面板配色';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { hilog } from '@kit.PerformanceAnalysisKit';

const 同步日志域: number = 0x4342;
const 同步日志标签: string = 'jidecards';

type 冲突类型 = 'fullSync' | 'fullDownload' | 'fullUpload';

@Component
export struct 同步面板 {
  @Prop 是否深色: boolean = false;
  @Prop 账号名: string = '';
  初始鉴权: SyncAuth | null = null;
  同步完成回调: () => void = (): void => {};
  关闭回调: () => void = (): void => {};

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';

  @State private 当前阶段: 'syncing' | 'conflict' | 'done' = 'syncing';
  @State private 状态文案: string = '';
  @State private 错误文案: string = '';
  @State private 媒体进度文案: string = '';
  @State private 当前冲突类型: 冲突类型 = 'fullSync';
  @State private 是否请求中止: boolean = false;

  private 鉴权: SyncAuth | null = null;
  private 轮询定时器: number = -1;
  private 媒体检查次数: number = 0;
  private 媒体曾进入活跃: boolean = false;
  private 待定服务器USN: number | null = null;
  private 是否在媒体阶段: boolean = false;
  private 集合已同步: boolean = false;
  private readonly 同步服务实例: 同步服务 = new 同步服务();

  aboutToAppear(): void {
    this.鉴权 = this.初始鉴权;
    this.启动同步();
  }

  aboutToDisappear(): void {
    this.清理轮询定时器();
  }

  private 取本地化文案(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 取色板(): 设置面板色板 {
    return 设置面板色板_取(this.是否深色);
  }

  private 清理轮询定时器(): void {
    if (this.轮询定时器 >= 0) {
      clearInterval(this.轮询定时器);
      this.轮询定时器 = -1;
    }
  }

  private 是否允许关闭(): boolean {
    return this.当前阶段 === 'done' && !this.是否请求中止;
  }

  private 完成中止(): void {
    const 集合是否已同步: boolean = this.集合已同步;
    this.是否请求中止 = false;
    this.集合已同步 = false;
    this.是否在媒体阶段 = false;
    this.清理轮询定时器();
    this.媒体进度文案 = '';
    this.状态文案 = this.取本地化文案($r('app.string.sync_aborted'));
    this.当前阶段 = 'done';
    if (集合是否已同步) {
      hilog.info(同步日志域, 同步日志标签, 'sync: aborted after collection synced, refreshing deck list');
      this.同步完成回调();
    }
  }

  private 处理同步错误(error: Error): void {
    if (this.是否请求中止) {
      this.完成中止();
      return;
    }
    const 集合是否已同步: boolean = this.集合已同步;
    this.集合已同步 = false;
    this.是否在媒体阶段 = false;
    this.清理轮询定时器();
    this.媒体进度文案 = '';
    const 后端错误类别: number | undefined = error instanceof 后端错误 ? error.kind : undefined;
    const 错误类别 = 分类同步错误(error, 后端错误类别);
    hilog.error(同步日志域, 同步日志标签, 'sync error: kind=%{public}s backendKind=%{public}d msg=%{public}s',
      错误类别, 后端错误类别 ?? -1, error.message);
    if (错误类别 === 'auth') {
      清除同步凭证();
      this.鉴权 = null;
      this.错误文案 = this.取本地化文案($r('app.string.sync_error_session_expired'));
    } else if (错误类别 === 'network') {
      this.错误文案 = `${this.取本地化文案($r('app.string.sync_error_network'))} [kind=${后端错误类别 ?? -1}]：${error.message}`;
    } else {
      this.错误文案 = `${this.取本地化文案($r('app.string.sync_error_generic'))} [kind=${后端错误类别 ?? -1}]：${error.message}`;
    }
    this.当前阶段 = 'done';
    if (集合是否已同步) {
      hilog.info(同步日志域, 同步日志标签, 'sync: error after collection synced, refreshing deck list');
      this.同步完成回调();
    }
  }

  private async 启动同步(): Promise<void> {
    const 当前鉴权: SyncAuth | null = this.鉴权;
    if (当前鉴权 === null) {
      this.错误文案 = this.取本地化文案($r('app.string.sync_error_session_expired'));
      this.当前阶段 = 'done';
      return;
    }
    this.错误文案 = '';
    this.状态文案 = '';
    this.媒体进度文案 = '';
    this.是否请求中止 = false;
    this.集合已同步 = false;
    this.当前阶段 = 'syncing';
    try {
      let 鉴权: SyncAuth = 当前鉴权;
      hilog.info(同步日志域, 同步日志标签, 'sync: calling syncStatus');
      const 状态响应: SyncStatusResponse = await this.同步服务实例.同步状态检查(鉴权);
      if (this.是否请求中止) {
        this.完成中止();
        return;
      }
      const 状态端点: string = 提取新端点(状态响应);
      if (状态端点 !== '') {
        鉴权 = 应用新端点(鉴权, 状态端点);
        this.鉴权 = 鉴权;
        保存同步端点(状态端点);
      }
      const 动作: 同步状态动作 = 判定同步动作(状态响应);
      hilog.info(同步日志域, 同步日志标签, 'sync: syncStatus done required=%{public}d action=%{public}s newEndpoint=%{public}s',
        状态响应.required, 动作, 状态端点);
      if (动作 === 'none') {
        this.状态文案 = this.取本地化文案($r('app.string.sync_up_to_date'));
        this.当前阶段 = 'done';
        this.同步完成回调();
        return;
      }

      hilog.info(同步日志域, 同步日志标签, 'sync: calling syncCollection syncMedia=true');
      const 集合响应: SyncCollectionResponse = await this.同步服务实例.同步集合(鉴权, true);
      if (this.是否请求中止) {
        this.完成中止();
        return;
      }
      const 集合端点: string = 提取新端点(集合响应);
      if (集合端点 !== '') {
        鉴权 = 应用新端点(鉴权, 集合端点);
        this.鉴权 = 鉴权;
        保存同步端点(集合端点);
      }
      const 走向: 集合同步结果走向 = 判定集合同步走向(集合响应);
      hilog.info(同步日志域, 同步日志标签,
        'sync: syncCollection done required=%{public}d outcome=%{public}s serverMediaUsn=%{public}d hostNumber=%{public}d serverMsg=%{public}s',
        集合响应.required, 走向, 集合响应.serverMediaUsn, 集合响应.hostNumber, 集合响应.serverMessage);
      if (走向 === 'done') {
        this.集合已同步 = true;
        this.启动媒体阶段(鉴权);
        return;
      }

      this.待定服务器USN = 集合响应.serverMediaUsn;
      this.当前冲突类型 = 走向;
      this.当前阶段 = 'conflict';
      hilog.info(同步日志域, 同步日志标签, 'sync: entering conflict phase kind=%{public}s', 走向);
    } catch (error) {
      this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
    }
  }

  private 冲突确认(是否上传: boolean): void {
    const 鉴权: SyncAuth | null = this.鉴权;
    if (鉴权 === null) {
      this.当前阶段 = 'done';
      return;
    }
    this.错误文案 = '';
    this.状态文案 = '';
    this.当前阶段 = 'syncing';
    hilog.info(同步日志域, 同步日志标签,
      'sync: calling fullUploadOrDownload upload=%{public}s serverUsn=%{public}s',
      是否上传 ? 'true' : 'false', this.待定服务器USN === null ? 'null' : `${this.待定服务器USN}`);
    this.同步服务实例.全量上传或下载(鉴权, 是否上传, this.待定服务器USN)
      .then((): void => {
        hilog.info(同步日志域, 同步日志标签, 'sync: fullUploadOrDownload done, entering media phase');
        this.集合已同步 = true;
        this.启动媒体阶段(鉴权);
      })
      .catch((error: Error): void => {
        this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
      });
  }

  private 启动媒体阶段(鉴权: SyncAuth): void {
    if (this.是否请求中止) {
      this.完成中止();
      return;
    }
    this.是否在媒体阶段 = true;
    this.当前阶段 = 'syncing';
    const RPC开始时间: number = Date.now();
    hilog.info(同步日志域, 同步日志标签,
      'sync: calling syncMedia (background start) at %{public}d', RPC开始时间);
    this.同步服务实例.同步媒体(鉴权)
      .then((): void => {
        if (this.是否请求中止) {
          this.完成中止();
          return;
        }
        hilog.info(同步日志域, 同步日志标签,
          'sync: syncMedia RPC returned in %{public}dms, starting polling', Date.now() - RPC开始时间);
        this.开始媒体轮询();
      })
      .catch((error: Error): void => {
        hilog.error(同步日志域, 同步日志标签,
          'sync: syncMedia RPC FAILED in %{public}dms: %{public}s',
          Date.now() - RPC开始时间, error instanceof Error ? error.message : `${error}`);
        this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
      });
  }

  private 开始媒体轮询(): void {
    this.清理轮询定时器();
    this.媒体检查次数 = 0;
    this.媒体曾进入活跃 = false;
    const 轮询开始时间: number = Date.now();
    hilog.info(同步日志域, 同步日志标签, 'sync: mediaPoll START at %{public}d', 轮询开始时间);
    this.轮询定时器 = setInterval((): void => {
      this.同步服务实例.媒体同步状态()
        .then((状态: MediaSyncStatusResponse): void => {
          if (this.是否请求中止) {
            this.完成中止();
            return;
          }
          this.媒体检查次数++;
          if (状态.active) {
            this.媒体曾进入活跃 = true;
          }
          this.媒体进度文案 = `${this.取本地化文案($r('app.string.sync_syncing_media'))} ` +
            `${状态.progress.checked}  ${状态.progress.added}  ${状态.progress.removed}`;
          hilog.info(同步日志域, 同步日志标签,
            'sync: mediaPoll check#%{public}d elapsed=%{public}dms active=%{public}s everActive=%{public}s checked=%{public}s added=%{public}s removed=%{public}s',
            this.媒体检查次数, Date.now() - 轮询开始时间, 状态.active ? 'true' : 'false',
            this.媒体曾进入活跃 ? 'true' : 'false',
            状态.progress.checked, 状态.progress.added, 状态.progress.removed);
          if (!状态.active) {
            if (this.媒体曾进入活跃) {
              hilog.info(同步日志域, 同步日志标签,
                'sync: mediaPoll DONE (everActive=true, checkCount=%{public}d, elapsed=%{public}dms)',
                this.媒体检查次数, Date.now() - 轮询开始时间);
              this.是否在媒体阶段 = false;
              this.清理轮询定时器();
              this.媒体进度文案 = '';
              this.状态文案 = this.取本地化文案($r('app.string.sync_success'));
              this.当前阶段 = 'done';
              this.同步完成回调();
            } else if (this.媒体检查次数 >= 30) {
              hilog.error(同步日志域, 同步日志标签,
                'sync: mediaPoll FAILED_TO_START (30s elapsed, everActive=false, checkCount=%{public}d)',
                this.媒体检查次数);
              this.处理同步错误(new Error('media sync failed to start within 30s'));
            }
          }
        })
        .catch((error: Error): void => {
          this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
        });
    }, 1000);
  }

  @Builder
  private 头部行() {
    Row() {
      Text(this.取本地化文案($r('app.string.settings_sync_group')))
        .fontSize(应用尺寸.字号_面板标题)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      if (this.是否允许关闭()) {
        Text('×')
          .fontSize(24)
          .fontColor($r('app.color.text_secondary'))
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            this.关闭回调();
          })
      }
    }
    .width('100%')
  }

  @Builder
  private 同步中内容() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(18)
        .height(18)
        .color(this.取色板().主色)
      Text($r('app.string.sync_syncing'))
        .fontSize(应用尺寸.字号_正文)
        .fontColor(this.取色板().主文字)
    }
    .width('100%')
    .height(40)

    if (this.媒体进度文案 !== '') {
      Text(this.媒体进度文案)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor(this.取色板().次文字)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder
  private 冲突内容() {
    Text($r('app.string.sync_conflict_title'))
      .fontSize(应用尺寸.字号_正文_中)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.取色板().主文字)
      .width('100%')
    Text(this.当前冲突类型 === 'fullDownload' ? $r('app.string.sync_download_only_message')
      : this.当前冲突类型 === 'fullUpload' ? $r('app.string.sync_upload_only_message')
      : $r('app.string.sync_conflict_message'))
      .fontSize(应用尺寸.字号_正文_小)
      .fontColor(this.取色板().次文字)
      .width('100%')

    if (this.当前冲突类型 !== 'fullDownload') {
      Button($r('app.string.sync_conflict_upload'))
        .width('100%')
        .height(44)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor('#FFFFFF')
        .backgroundColor(this.取色板().主色按钮背景)
        .borderRadius(22)
        .onClick((): void => {
          this.冲突确认(true);
        })
    }
    if (this.当前冲突类型 !== 'fullUpload') {
      Button($r('app.string.sync_conflict_download'))
        .width('100%')
        .height(44)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor('#FFFFFF')
        .backgroundColor(this.取色板().主色按钮背景)
        .borderRadius(22)
        .onClick((): void => {
          this.冲突确认(false);
        })
    }
  }

  @Builder
  private 完成内容() {
    if (this.状态文案 !== '') {
      Text(this.状态文案)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor(this.取色板().主色)
        .width('100%')
    }
    if (this.错误文案 !== '') {
      Text(this.错误文案)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor(this.取色板().错误色)
        .width('100%')
        .maxLines(8)
    }
    Button($r('app.string.close'))
      .width('100%')
      .height(44)
      .fontSize(应用尺寸.字号_按钮)
      .fontColor('#FFFFFF')
      .backgroundColor(this.取色板().主色按钮背景)
      .borderRadius(22)
      .onClick((): void => {
        this.关闭回调();
      })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.取色板().遮罩)
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.是否深色 ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick((): void => {
          if (this.是否允许关闭()) {
            this.关闭回调();
          }
        })

      Column({ space: 应用尺寸.间距_12 }) {
        this.头部行()

        if (this.账号名 !== '') {
          Text(this.账号名)
            .fontSize(应用尺寸.字号_正文)
            .fontColor(this.取色板().次文字)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.当前阶段 === 'syncing') {
          this.同步中内容()
        } else if (this.当前阶段 === 'conflict') {
          this.冲突内容()
        } else {
          this.完成内容()
        }
      }
      .width('88%')
      .constraintSize({ maxWidth: 480 })
      .padding(20)
      .backgroundColor(this.取色板().背景)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }
}
