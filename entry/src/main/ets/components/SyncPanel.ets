// SPDX-License-Identifier: AGPL-3.0-or-later

import { SyncService } from '../backend/SyncService';
import { BackendError } from '../backend/errors';
import type {
  MediaSyncStatusResponse,
  SyncAuth,
  SyncCollectionResponse,
  SyncStatusResponse
} from '../proto/messages/SyncMessages';
import {
  clearSyncAuth,
  saveSyncEndpoint
} from '../model/SyncAuthStore';
import {
  applyNewEndpoint,
  classifySyncError,
  decideCollectionOutcome,
  decideSyncAction,
  extractNewEndpoint
} from '../model/SyncFlow';
import type { CollectionOutcome, SyncStatusAction } from '../model/SyncFlow';
import { settingsPalette, SettingsPalette } from '../utils/SettingsColors';
import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 同步流程诊断日志：DOMAIN 0x4342 与 EntryAbility 一致，tag 用 jidecards 便于过滤
const SYNC_LOG_DOMAIN: number = 0x4342;
const SYNC_LOG_TAG: string = 'jidecards';

/** 全量同步方向冲突类型（与 SyncFlow 的 CollectionOutcome 冲突分支一一对应）。 */
type ConflictKind = 'fullSync' | 'fullDownload' | 'fullUpload';

/**
 * AnkiWeb 云同步独立弹窗（B14 2026-07-22）。
 *
 * 从 SyncGroup 抽出来的同步流程：登录/注销留在 SyncGroup，点「立即同步」后由 Index
 * 挂载本弹窗。弹窗生命周期内完整跑 SyncStatus → SyncCollection → 媒体阶段，关闭守卫
 * 确保 syncing/conflict/abortRequested 期间不可关闭——避免定时器泄漏、错误被吞、冲突中断。
 *
 * 状态机：
 * - syncing：同步进行中（含 SyncStatus/SyncCollection/mediaSync pending 与媒体轮询中）
 * - conflict：服务端要求全量同步，等用户选方向（内联 UI，不再用 CustomDialog）
 * - done：同步完成 / 已是最新 / 已中止 / 错误，允许关闭
 *
 * auth 流转：initialAuth 由 Index 透传；内部若服务端下发新端点，写回 preferences
 * （saveSyncEndpoint）并更新内部 auth。下次 SyncGroup.aboutToAppear 会读到最新值。
 * auth 类错误时清凭证（clearSyncAuth），关闭弹窗后 SyncGroup 重新 aboutToAppear 会回 loggedOut。
 */
@Component
export struct SyncPanel {
  @Prop isDark: boolean = false;
  @Prop accountName: string = '';
  // initialAuth 由 Index 在挂载本组件时传入（来自 SyncGroup 上抛）
  initialAuth: SyncAuth | null = null;
  onSyncCompleted: () => void = (): void => {};
  onClose: () => void = (): void => {};

  // @StorageProp 触发颜色主题切换时重 build，让 settingsPalette(isDark).primary 即时变化
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';

  @State private phase: 'syncing' | 'conflict' | 'done' = 'syncing';
  @State private statusText: string = '';
  @State private errorText: string = '';
  @State private mediaProgress: string = '';
  @State private conflictKind: ConflictKind = 'fullSync';
  @State private abortRequested: boolean = false;

  // 内部（非 @State，不参与 UI 刷新）
  private auth: SyncAuth | null = null;
  private pollTimer: number = -1;
  private mediaCheckCount: number = 0;
  /** 媒体同步是否曾进入 active=true 状态（防误判：未启动时 active=false 不应立即判完成）。 */
  private mediaEverActive: boolean = false;
  private pendingServerUsn: number | null = null;
  private inMediaPhase: boolean = false;
  private readonly syncService: SyncService = new SyncService();

  aboutToAppear(): void {
    this.auth = this.initialAuth;
    this.startSync();
  }

  aboutToDisappear(): void {
    this.clearPollTimer();
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  private palette(): SettingsPalette {
    return settingsPalette(this.isDark);
  }

  /** 清理媒体轮询定时器。 */
  private clearPollTimer(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  /** 是否允许关闭弹窗：仅 done 阶段且未在中止等待中可关。 */
  private canClose(): boolean {
    return this.phase === 'done' && !this.abortRequested;
  }

  /** 中止落定态：清轮询、置 done、显示「已中止」文案。 */
  private finishAborted(): void {
    this.abortRequested = false;
    this.inMediaPhase = false;
    this.clearPollTimer();
    this.mediaProgress = '';
    this.statusText = this.localized($r('app.string.sync_aborted'));
    this.phase = 'done';
  }

  /**
   * 同步流程统一错误出口：
   * - 用户中止优先：落「已中止」态（done）；
   * - auth：会话过期，清凭证（关闭后 SyncGroup 回 loggedOut）；
   * - network/other：停留 done，显示错误文案，允许关闭。
   */
  private handleSyncError(error: Error): void {
    if (this.abortRequested) {
      this.finishAborted();
      return;
    }
    this.inMediaPhase = false;
    this.clearPollTimer();
    this.mediaProgress = '';
    const backendKind: number | undefined = error instanceof BackendError ? error.kind : undefined;
    const kind = classifySyncError(error, backendKind);
    hilog.error(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync error: kind=%{public}s backendKind=%{public}d msg=%{public}s',
      kind, backendKind ?? -1, error.message);
    if (kind === 'auth') {
      clearSyncAuth();
      this.auth = null;
      this.errorText = this.localized($r('app.string.sync_error_session_expired'));
    } else if (kind === 'network') {
      this.errorText = `${this.localized($r('app.string.sync_error_network'))} [kind=${backendKind ?? -1}]：${error.message}`;
    } else {
      this.errorText = `${this.localized($r('app.string.sync_error_generic'))} [kind=${backendKind ?? -1}]：${error.message}`;
    }
    this.phase = 'done';
  }

  /** 启动同步：SyncStatus → SyncCollection → 媒体阶段。 */
  private async startSync(): Promise<void> {
    const current: SyncAuth | null = this.auth;
    if (current === null) {
      this.errorText = this.localized($r('app.string.sync_error_session_expired'));
      this.phase = 'done';
      return;
    }
    this.errorText = '';
    this.statusText = '';
    this.mediaProgress = '';
    this.abortRequested = false;
    this.phase = 'syncing';
    try {
      let auth: SyncAuth = current;
      hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: calling syncStatus');
      const status: SyncStatusResponse = await this.syncService.syncStatus(auth);
      if (this.abortRequested) {
        this.finishAborted();
        return;
      }
      const statusEndpoint: string = extractNewEndpoint(status);
      if (statusEndpoint !== '') {
        auth = applyNewEndpoint(auth, statusEndpoint);
        this.auth = auth;
        saveSyncEndpoint(statusEndpoint);
      }
      const action: SyncStatusAction = decideSyncAction(status);
      hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: syncStatus done required=%{public}d action=%{public}s newEndpoint=%{public}s',
        status.required, action, statusEndpoint);
      if (action === 'none') {
        this.statusText = this.localized($r('app.string.sync_up_to_date'));
        this.phase = 'done';
        return;
      }

      hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: calling syncCollection syncMedia=true');
      const resp: SyncCollectionResponse = await this.syncService.syncCollection(auth, true);
      if (this.abortRequested) {
        this.finishAborted();
        return;
      }
      const collectionEndpoint: string = extractNewEndpoint(resp);
      if (collectionEndpoint !== '') {
        auth = applyNewEndpoint(auth, collectionEndpoint);
        this.auth = auth;
        saveSyncEndpoint(collectionEndpoint);
      }
      const outcome: CollectionOutcome = decideCollectionOutcome(resp);
      hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
        'sync: syncCollection done required=%{public}d outcome=%{public}s serverMediaUsn=%{public}d hostNumber=%{public}d serverMsg=%{public}s',
        resp.required, outcome, resp.serverMediaUsn, resp.hostNumber, resp.serverMessage);
      if (outcome === 'done') {
        this.startMediaPhase(auth);
        return;
      }

      // 全量冲突：进 conflict 阶段，等待用户选方向（不弹 CustomDialog，内联到本弹窗）
      this.pendingServerUsn = resp.serverMediaUsn;
      this.conflictKind = outcome;
      this.phase = 'conflict';
      hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: entering conflict phase kind=%{public}s', outcome);
    } catch (error) {
      this.handleSyncError(error instanceof Error ? error : new Error(`${error}`));
    }
  }

  /** 冲突确认：FullUploadOrDownload 成功后进入媒体阶段。 */
  private onConflictConfirm(upload: boolean): void {
    const auth: SyncAuth | null = this.auth;
    if (auth === null) {
      this.phase = 'done';
      return;
    }
    this.errorText = '';
    this.statusText = '';
    this.phase = 'syncing';
    hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
      'sync: calling fullUploadOrDownload upload=%{public}s serverUsn=%{public}s',
      upload ? 'true' : 'false', this.pendingServerUsn === null ? 'null' : `${this.pendingServerUsn}`);
    this.syncService.fullUploadOrDownload(auth, upload, this.pendingServerUsn)
      .then((): void => {
        hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: fullUploadOrDownload done, entering media phase');
        this.startMediaPhase(auth);
      })
      .catch((error: Error): void => {
        this.handleSyncError(error instanceof Error ? error : new Error(`${error}`));
      });
  }

  /**
   * 媒体阶段：SyncMedia 后台启动 → 1s 轮询 MediaSyncStatus。
   * rslib 约定：媒体同步出错后下一次 MediaSyncStatus 返回错误（走 catch 分支）。
   */
  private startMediaPhase(auth: SyncAuth): void {
    if (this.abortRequested) {
      this.finishAborted();
      return;
    }
    this.inMediaPhase = true;
    this.phase = 'syncing';
    const rpcStart: number = Date.now();
    hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
      'sync: calling syncMedia (background start) at %{public}d', rpcStart);
    this.syncService.syncMedia(auth)
      .then((): void => {
        if (this.abortRequested) {
          this.finishAborted();
          return;
        }
        hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
          'sync: syncMedia RPC returned in %{public}dms, starting polling', Date.now() - rpcStart);
        this.beginMediaPolling();
      })
      .catch((error: Error): void => {
        hilog.error(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
          'sync: syncMedia RPC FAILED in %{public}dms: %{public}s',
          Date.now() - rpcStart, error instanceof Error ? error.message : `${error}`);
        this.handleSyncError(error instanceof Error ? error : new Error(`${error}`));
      });
  }

  /**
   * 1s 轮询媒体进度。完成判定（修复 2026-07-22 假成功 bug）：
   * - mediaEverActive=true 后 active=false → 正常成功
   * - mediaEverActive=false 且 30 秒内从未 active → 报错"媒体同步未启动"
   * - 其他情况继续轮询
   * 旧逻辑 `!active && (everActive || checkCount>=10)` 的 checkCount>=10 兜底会让
   * sync_media_blocking 秒退返回 Ok 的场景被误报为成功（实际 0 字节传输）。
   */
  private beginMediaPolling(): void {
    this.clearPollTimer();
    this.mediaCheckCount = 0;
    this.mediaEverActive = false;
    const pollStart: number = Date.now();
    hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync: mediaPoll START at %{public}d', pollStart);
    this.pollTimer = setInterval((): void => {
      this.syncService.mediaSyncStatus()
        .then((status: MediaSyncStatusResponse): void => {
          if (this.abortRequested) {
            this.finishAborted();
            return;
          }
          this.mediaCheckCount++;
          if (status.active) {
            this.mediaEverActive = true;
          }
          // 后端 rslib 已通过 i18n 模板格式化为「已检查：N / 已新增：N↑ N↓ / 已删除：N↑ N↓」，
          // ↑=上传方向（本地→云端），↓=下载方向（云端→本地）。直接原样展示，不再替换符号。
          this.mediaProgress = `${this.localized($r('app.string.sync_syncing_media'))} ` +
            `${status.progress.checked}  ${status.progress.added}  ${status.progress.removed}`;
          hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
            'sync: mediaPoll check#%{public}d elapsed=%{public}dms active=%{public}s everActive=%{public}s checked=%{public}s added=%{public}s removed=%{public}s',
            this.mediaCheckCount, Date.now() - pollStart, status.active ? 'true' : 'false',
            this.mediaEverActive ? 'true' : 'false',
            status.progress.checked, status.progress.added, status.progress.removed);
          // 完成判定：必须 mediaEverActive=true 后再 active=false 才算成功；
          // 30 秒内从未 active 视为未启动/秒退，报错让用户重试，不再兜底假成功。
          if (!status.active) {
            if (this.mediaEverActive) {
              hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
                'sync: mediaPoll DONE (everActive=true, checkCount=%{public}d, elapsed=%{public}dms)',
                this.mediaCheckCount, Date.now() - pollStart);
              this.inMediaPhase = false;
              this.clearPollTimer();
              this.mediaProgress = '';
              this.statusText = this.localized($r('app.string.sync_success'));
              this.phase = 'done';
              this.onSyncCompleted();
            } else if (this.mediaCheckCount >= 30) {
              // 30 秒内媒体同步从未进入 active 状态：sync_media_blocking 可能秒退返回 Ok
              // 或 sync_media_in_background 因已有任务直接 return Ok 未启动新任务。
              hilog.error(SYNC_LOG_DOMAIN, SYNC_LOG_TAG,
                'sync: mediaPoll FAILED_TO_START (30s elapsed, everActive=false, checkCount=%{public}d)',
                this.mediaCheckCount);
              this.handleSyncError(new Error('media sync failed to start within 30s'));
            }
            // else: mediaEverActive=false && checkCount<30，继续等
          }
        })
        .catch((error: Error): void => {
          this.handleSyncError(error instanceof Error ? error : new Error(`${error}`));
        });
    }, 1000);
  }

  /** 中止按钮：媒体阶段 AbortMediaSync，集合阶段 AbortSync；待 pending promise settle 后落 done。 */
  private onAbortClick(): void {
    if (this.abortRequested) {
      return;
    }
    this.abortRequested = true;
    if (this.inMediaPhase) {
      this.syncService.abortMediaSync().catch((): void => {});
    } else {
      this.syncService.abortSync().catch((): void => {});
    }
  }

  @Builder
  private headerRow() {
    Row() {
      Text(this.localized($r('app.string.settings_sync_group')))
        .fontSize(AppDimens.FONT_PANEL_TITLE)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      // 仅 done 阶段显示 ×；syncing/conflict 隐藏避免误触
      if (this.canClose()) {
        Text('×')
          .fontSize(24)
          .fontColor($r('app.color.text_secondary'))
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            this.onClose();
          })
      }
    }
    .width('100%')
  }

  /** syncing 阶段：LoadingProgress + 文案 + 媒体进度 + 中止按钮。 */
  @Builder
  private syncingContent() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(18)
        .height(18)
        .color(this.palette().primary)
      Text($r('app.string.sync_syncing'))
        .fontSize(AppDimens.FONT_BODY)
        .fontColor(this.palette().textPrimary)
    }
    .width('100%')
    .height(40)

    if (this.mediaProgress !== '') {
      Text(this.mediaProgress)
        .fontSize(AppDimens.FONT_BODY_S)
        .fontColor(this.palette().textSecondary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }

    Button($r('app.string.sync_abort'))
      .width('100%')
      .height(40)
      .fontSize(AppDimens.FONT_BUTTON)
      .fontColor(this.palette().textPrimary)
      .backgroundColor(this.palette().chipBg)
      .borderRadius(20)
      .enabled(!this.abortRequested)
      .opacity(this.abortRequested ? 0.6 : 1)
      .onClick((): void => {
        this.onAbortClick();
      })
  }

  /** conflict 阶段：冲突说明 + 上传/下载按钮（无取消，强制选方向）。 */
  @Builder
  private conflictContent() {
    Text($r('app.string.sync_conflict_title'))
      .fontSize(AppDimens.FONT_BODY_M)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette().textPrimary)
      .width('100%')
    Text(this.conflictKind === 'fullDownload' ? $r('app.string.sync_download_only_message')
      : this.conflictKind === 'fullUpload' ? $r('app.string.sync_upload_only_message')
      : $r('app.string.sync_conflict_message'))
      .fontSize(AppDimens.FONT_BODY_S)
      .fontColor(this.palette().textSecondary)
      .width('100%')

    // 上传按钮：fullDownload 场景不展示
    if (this.conflictKind !== 'fullDownload') {
      Button($r('app.string.sync_conflict_upload'))
        .width('100%')
        .height(44)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontColor('#FFFFFF')
        .backgroundColor(this.palette().primary)
        .borderRadius(22)
        .onClick((): void => {
          this.onConflictConfirm(true);
        })
    }
    // 下载按钮：fullUpload 场景不展示
    if (this.conflictKind !== 'fullUpload') {
      Button($r('app.string.sync_conflict_download'))
        .width('100%')
        .height(44)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontColor('#FFFFFF')
        .backgroundColor(this.palette().primary)
        .borderRadius(22)
        .onClick((): void => {
          this.onConflictConfirm(false);
        })
    }
  }

  /** done 阶段：状态/错误文案 + 关闭按钮。 */
  @Builder
  private doneContent() {
    if (this.statusText !== '') {
      Text(this.statusText)
        .fontSize(AppDimens.FONT_BODY_S)
        .fontColor(this.palette().primary)
        .width('100%')
    }
    if (this.errorText !== '') {
      Text(this.errorText)
        .fontSize(AppDimens.FONT_BODY_S)
        .fontColor(this.palette().error)
        .width('100%')
        .maxLines(8)
    }
    Button($r('app.string.close'))
      .width('100%')
      .height(44)
      .fontSize(AppDimens.FONT_BUTTON)
      .fontColor('#FFFFFF')
      .backgroundColor(this.palette().primary)
      .borderRadius(22)
      .onClick((): void => {
        this.onClose();
      })
  }

  build() {
    Stack() {
      // 磨砂玻璃遮罩：canClose=false 时不响应点击
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.palette().mask)
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick((): void => {
          if (this.canClose()) {
            this.onClose();
          }
        })

      Column({ space: AppDimens.SPACE_12 }) {
        this.headerRow()

        if (this.accountName !== '') {
          Text(this.accountName)
            .fontSize(AppDimens.FONT_BODY)
            .fontColor(this.palette().textSecondary)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.phase === 'syncing') {
          this.syncingContent()
        } else if (this.phase === 'conflict') {
          this.conflictContent()
        } else {
          this.doneContent()
        }
      }
      .width('88%')
      .padding(20)
      .backgroundColor(this.palette().bg)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }
}
