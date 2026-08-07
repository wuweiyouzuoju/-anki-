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
  保存同步端点,
  设置媒体待同步,
  加载媒体待同步,
  加载媒体同步开关
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
import { 取全屏转场时长, 取全屏转场曲线 } from '../utils/转场时长';
import { 颜色键 } from '../model/颜色主题';
import { hilog } from '@kit.PerformanceAnalysisKit';

// 同步流程诊断日志：DOMAIN 0x4342 与 EntryAbility 一致，tag 用 jidecards 便于过滤
const 同步日志域: number = 0x4342;
const 同步日志标签: string = 'jidecards';

/** 全量同步方向冲突类型（与 同步流程 的 集合同步结果走向 冲突分支一一对应）。 */
type 冲突类型 = 'fullSync' | 'fullDownload' | 'fullUpload';

// ========================================================
// @块ID COMP-SYNC-PANEL-001
// @名称 同步面板组件声明与状态字段
//
// @作用
// AnkiWeb 云同步独立弹窗（B14 2026-07-22）。
// 从 SyncGroup 抽出来的同步流程：登录/注销留在 SyncGroup，点「立即同步」后由 Index
// 挂载本弹窗。弹窗生命周期内完整跑 SyncStatus → SyncCollection → 媒体阶段，关闭守卫
// 确保 syncing/conflict/abortRequested 期间不可关闭——避免定时器泄漏、错误被吞、冲突中断。
//
// 状态机：
// - syncing：同步进行中（含 SyncStatus/SyncCollection/mediaSync pending 与媒体轮询中）
// - conflict：服务端要求全量同步，等用户选方向（内联 UI，不再用 CustomDialog）
// - done：同步完成 / 已是最新 / 已中止 / 错误，允许关闭
//
// auth 流转：initialAuth 由 Index 透传；内部若服务端下发新端点，写回 preferences
// （saveSyncEndpoint）并更新内部 auth。下次 SyncGroup.aboutToAppear 会读到最新值。
// auth 类错误时清凭证（clearSyncAuth），关闭弹窗后 SyncGroup 重新 aboutToAppear 会回 loggedOut。
//
// @输入
// 是否深色 / 账号名 / 初始鉴权 / 同步完成回调 / 关闭回调（由 Index 挂载时透传）。
//
// @输出
// 一个全屏 Stack 弹窗：磨砂遮罩 + 居中浮卡（按阶段切换 syncing/conflict/done 内容）。
//
// @业务规则
// 关闭守卫：仅 done 阶段且未在中止等待中可关闭。
// 颜色主题通过 @StorageProp 触发重 build，让 设置面板色板_取(isDark).主色 即时变化。
//
// @副作用
// 持有 同步服务 实例与轮询定时器；aboutToDisappear 清理定时器。
// ========================================================

@Component
export struct 同步面板 {
  @Prop 是否深色: boolean = false;
  @Prop 账号名: string = '';
  // 初始鉴权 由 Index 在挂载本组件时传入（来自 SyncGroup 上抛）
  初始鉴权: SyncAuth | null = null;
  同步完成回调: () => void = (): void => {};
  关闭回调: () => void = (): void => {};

  // @StorageProp 触发颜色主题切换时重 build，让 设置面板色板_取(isDark).主色 即时变化
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';

  @State private 当前阶段: 'syncing' | 'conflict' | 'done' = 'syncing';
  @State private 状态文案: string = '';
  @State private 错误文案: string = '';
  @State private 媒体进度文案: string = '';
  @State private 当前冲突类型: 冲突类型 = 'fullSync';
  @State private 是否请求中止: boolean = false;

  // 内部（非 @State，不参与 UI 刷新）
  private 鉴权: SyncAuth | null = null;
  private 轮询定时器: number = -1;
  private 媒体检查次数: number = 0;
  /** 媒体同步是否曾进入 active=true 状态（防误判：未启动时 active=false 不应立即判完成）。 */
  private 媒体曾进入活跃: boolean = false;
  private 待定服务器USN: number | null = null;
  private 是否在媒体阶段: boolean = false;
  /** syncCollection 已完成（数据已写入本地 DB）；中止后据此决定是否刷新牌组列表。 */
  private 集合已同步: boolean = false;
  private readonly 同步服务实例: 同步服务 = new 同步服务();

  aboutToAppear(): void {
    this.鉴权 = this.初始鉴权;
    this.启动同步();
  }

  aboutToDisappear(): void {
    this.清理轮询定时器();
  }

  // ========================================================
  // @块ID COMP-SYNC-PANEL-002
  // @名称 色板/本地化/定时器/关闭判定辅助方法
  //
  // @作用
  // 提供四个无状态的小辅助：取本地化资源字符串、取设置面板色板、
  // 清理媒体轮询定时器、判定弹窗是否允许关闭。
  //
  // @输入
  // 取本地化文案：Resource；取色板：isDark；清理轮询定时器：无；是否允许关闭：无（读 this.当前阶段 与 this.是否请求中止）。
  //
  // @输出
  // 取本地化文案：本地化字符串；取色板：设置面板色板 对象；其余无返回。
  //
  // @业务规则
  // 关闭判定：仅 当前阶段 === 'done' 且 是否请求中止 === false 才允许关闭。
  //
  // @副作用
  // 清理轮询定时器会 clearInterval 并置位 -1。
  // ========================================================

  private 取本地化文案(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  private 取色板(): 设置面板色板 {
    return 设置面板色板_取(this.是否深色);
  }

  /** 清理媒体轮询定时器。 */
  private 清理轮询定时器(): void {
    if (this.轮询定时器 >= 0) {
      clearInterval(this.轮询定时器);
      this.轮询定时器 = -1;
    }
  }

  /** 是否允许关闭弹窗：仅 done 阶段且未在中止等待中可关。 */
  private 是否允许关闭(): boolean {
    return this.当前阶段 === 'done' && !this.是否请求中止;
  }

  // ========================================================
  // @块ID COMP-SYNC-PANEL-003
  // @名称 同步中止与错误统一处理
  //
  // @作用
  // 同步流程统一错误出口与中止落定态处理：
  // - 完成中止：清轮询、置 done、显示「已中止」文案；若 syncCollection 已完成则刷新牌组列表。
  // - 处理同步错误：用户中止优先走完成中止；其余按 auth/network/other 分类显示错误文案；
  //   媒体阶段出错且集合已同步时仍刷新牌组列表。
  //
  // @输入
  // 完成中止：无（读 this.集合已同步）；处理同步错误：Error 实例。
  //
  // @输出
  // 当前阶段置 'done'，状态文案/错误文案更新，必要时调用 同步完成回调。
  //
  // @业务规则
  // auth 错误：清凭证（关闭后 SyncGroup 回 loggedOut）。
  // network/other：停留 done，显示错误文案，允许关闭。
  // 中止或错误时若 集合已同步=true，仍需刷新牌组列表让用户看到已同步的牌组。
  //
  // @副作用
  // 清理轮询定时器；auth 错误时 清除同步凭证 + 置 鉴权=null；调用 同步完成回调。
  // ========================================================

  /** 中止落定态：清轮询、置 done、显示「已中止」文案。 */
  private 完成中止(): void {
    const 集合是否已同步: boolean = this.集合已同步;
    this.是否请求中止 = false;
    this.集合已同步 = false;
    this.是否在媒体阶段 = false;
    this.清理轮询定时器();
    this.媒体进度文案 = '';
    this.状态文案 = this.取本地化文案($r('app.string.sync_aborted'));
    this.当前阶段 = 'done';
    // syncCollection 已完成（数据已入 DB）但用户中止了媒体阶段：仍需刷新牌组列表，
    // 否则用户看不到刚同步的牌组，再点同步又显示「已最新」但 UI 不更新。
    if (集合是否已同步) {
      hilog.info(同步日志域, 同步日志标签, 'sync: aborted after collection synced, refreshing deck list');
      this.同步完成回调();
    }
  }

  /**
   * 同步流程统一错误出口：
   * - 用户中止优先：落「已中止」态（done）；
   * - auth：会话过期，清凭证（关闭后 SyncGroup 回 loggedOut）；
   * - network/other：停留 done，显示错误文案，允许关闭。
   */
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
    // 媒体阶段出错时集合同步已完成（数据已入 DB），仍需刷新牌组列表让用户看到已同步的牌组。
    if (集合是否已同步) {
      hilog.info(同步日志域, 同步日志标签, 'sync: error after collection synced, refreshing deck list');
      this.同步完成回调();
    }
  }

  // ========================================================
  // @块ID COMP-SYNC-PANEL-004
  // @名称 启动同步主流程
  //
  // @作用
  // 执行 SyncStatus → SyncCollection → 媒体阶段 的主流程：
  // - 调 syncStatus 推断新端点并应用；
  // - 判定同步动作：none=已最新；否则调 syncCollection；
  // - 判定集合同步走向：done=进入媒体阶段；否则进 conflict 阶段等用户决策。
  //
  // @输入
  // 读 this.鉴权 / this.是否请求中止。
  //
  // @输出
  // 更新 this.鉴权（端点迁移时）、this.状态文案、this.当前阶段、this.待定服务器USN、this.当前冲突类型。
  //
  // @业务规则
  // 任一阶段检测到 是否请求中止 立即走 完成中止。
  // action=none 时直接置 done 并刷新牌组列表（本地 UI 可能未反映上次写入 DB 的数据）。
  // outcome=done 时标记 集合已同步=true 再进媒体阶段。
  //
  // @副作用
  // 调 同步服务.同步状态检查 / 同步集合；端点变更时 保存同步端点；调 同步完成回调。
  // ========================================================

  /** 启动同步：SyncStatus → SyncCollection → 媒体阶段。 */
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
        // 集合层面无变化。但若上次媒体同步被中断（删后台/进程被杀），
        // media_sync_pending 仍为 true——此时需继续媒体阶段，否则媒体永远无法同步。
        // 但若用户已关闭媒体同步开关，不再继续媒体阶段，并清除残留标志。
        if (加载媒体同步开关() && 加载媒体待同步()) {
          hilog.info(同步日志域, 同步日志标签,
            'sync: syncStatus=NO_CHANGES but media_sync_pending=true, resuming media phase');
          this.集合已同步 = true;
          this.启动媒体阶段(鉴权);
          return;
        }
        if (!加载媒体同步开关() && 加载媒体待同步()) {
          // 媒体同步已禁用，清除残留的待完成标志。
          设置媒体待同步(false);
        }
        this.状态文案 = this.取本地化文案($r('app.string.sync_up_to_date'));
        this.当前阶段 = 'done';
        // 服务端认为已最新，但本地 UI 可能未反映上次（中止的）同步写入 DB 的数据，刷新牌组列表。
        this.同步完成回调();
        return;
      }

      // 读取媒体同步开关（对齐 Anki 桌面端 Preferences → Sync → "Sync media"）。
      // 关闭时 syncMedia=false（rslib 不挂起媒体同步任务），同步面板跳过媒体阶段。
      const 媒体同步开启: boolean = 加载媒体同步开关();
      hilog.info(同步日志域, 同步日志标签, 'sync: calling syncCollection syncMedia=%{public}s',
        媒体同步开启 ? 'true' : 'false');
      const 集合响应: SyncCollectionResponse = await this.同步服务实例.同步集合(鉴权, 媒体同步开启);
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
        // outcome=done = 集合已原子提交到本地 DB；标记以便后续中止时刷新牌组列表。
        this.集合已同步 = true;
        // 媒体同步开关关闭（对齐 Anki 桌面端 "Sync media" 开关）：不进媒体阶段，直接完成。
        if (!媒体同步开启) {
          hilog.info(同步日志域, 同步日志标签, 'sync: syncCollection done, media sync disabled, skipping media phase');
          // 媒体同步已禁用，清除待完成标志（避免上次中断的媒体同步残留标志干扰）。
          设置媒体待同步(false);
          this.状态文案 = this.取本地化文案($r('app.string.sync_success'));
          this.当前阶段 = 'done';
          this.同步完成回调();
          return;
        }
        // 集合同步成功，媒体同步待完成——若媒体同步被中断，下次同步凭此标志继续。
        设置媒体待同步(true);
        this.启动媒体阶段(鉴权);
        return;
      }

      // 全量冲突：进 conflict 阶段，等待用户选方向（不弹 CustomDialog，内联到本弹窗）
      this.待定服务器USN = 集合响应.serverMediaUsn;
      this.当前冲突类型 = 走向;
      this.当前阶段 = 'conflict';
      hilog.info(同步日志域, 同步日志标签, 'sync: entering conflict phase kind=%{public}s', 走向);
    } catch (error) {
      this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
    }
  }

  // ========================================================
  // @块ID COMP-SYNC-PANEL-005
  // @名称 冲突确认与媒体阶段启动
  //
  // @作用
  // - 冲突确认：用户选上传/下载方向后调 全量上传或下载，成功后进媒体阶段；
  // - 媒体阶段启动：调 同步媒体 后台启动，RPC 返回后开始 1s 轮询媒体状态。
  //
  // @输入
  // 冲突确认：是否上传（boolean）；启动媒体阶段：当前 SyncAuth。
  //
  // @输出
  // 当前阶段置 'syncing'，集合已同步=true（全量上传/下载成功后）。
  //
  // @业务规则
  // 全量上传/下载完成 = 集合已写入本地 DB，标记 集合已同步=true 以便后续中止时刷新牌组列表。
  // 媒体阶段开始即检查 是否请求中止，命中则走 完成中止。
  //
  // @副作用
  // 调 同步服务.全量上传或下载 / 同步媒体；RPC 失败走 处理同步错误。
  // ========================================================

  /** 冲突确认：FullUploadOrDownload 成功后进入媒体阶段。 */
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
        // 全量上传/下载完成 = 集合已写入本地 DB；标记以便后续中止时刷新牌组列表。
        this.集合已同步 = true;
        // 媒体同步开关关闭：不进媒体阶段，直接完成。
        if (!加载媒体同步开关()) {
          hilog.info(同步日志域, 同步日志标签, 'sync: fullUploadOrDownload done, media sync disabled, skipping media phase');
          设置媒体待同步(false);
          this.状态文案 = this.取本地化文案($r('app.string.sync_success'));
          this.当前阶段 = 'done';
          this.同步完成回调();
          return;
        }
        hilog.info(同步日志域, 同步日志标签, 'sync: fullUploadOrDownload done, entering media phase');
        // 集合同步成功，媒体同步待完成——若媒体同步被中断，下次同步凭此标志继续。
        设置媒体待同步(true);
        this.启动媒体阶段(鉴权);
      })
      .catch((error: Error): void => {
        this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
      });
  }

  /**
   * 媒体阶段：SyncMedia 后台启动 → 1s 轮询 MediaSyncStatus。
   * rslib 约定：媒体同步出错后下一次 MediaSyncStatus 返回错误（走 catch 分支）。
   */
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

  // ========================================================
  // @块ID COMP-SYNC-PANEL-006
  // @名称 媒体轮询与完成判定
  //
  // @作用
  // 每 1s 调 媒体同步状态 轮询进度，按 active / 媒体曾进入活跃 / 媒体检查次数 判定完成：
  // - 媒体曾进入活跃=true 后 active=false → 正常成功；
  // - 媒体曾进入活跃=false 且 30 秒内从未 active → 报错"媒体同步未启动"；
  // - 其他情况继续轮询。
  //
  // @输入
  // 无（读 this.是否请求中止 / this.轮询定时器 等内部状态）。
  //
  // @输出
  // 更新 this.媒体进度文案 / this.状态文案 / this.当前阶段；完成时调 同步完成回调。
  //
  // @业务规则
  // 旧逻辑 `!active && (everActive || checkCount>=10)` 的 checkCount>=10 兜底会让
  // sync_media_blocking 秒退返回 Ok 的场景被误报为成功（实际 0 字节传输）——已修复。
  // 后端 rslib 已通过 i18n 模板格式化进度文本，原样展示不再替换符号。
  //
  // @副作用
  // setInterval 注册定时器；调 媒体同步状态 RPC；调 同步完成回调；调 处理同步错误。
  // ========================================================

  /**
   * 1s 轮询媒体进度。完成判定（修复 2026-07-22 假成功 bug）：
   * - mediaEverActive=true 后 active=false → 正常成功
   * - mediaEverActive=false 且 30 秒内从未 active → 报错"媒体同步未启动"
   * - 其他情况继续轮询
   * 旧逻辑 `!active && (everActive || checkCount>=10)` 的 checkCount>=10 兜底会让
   * sync_media_blocking 秒退返回 Ok 的场景被误报为成功（实际 0 字节传输）。
   */
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
          // 后端 rslib 已通过 i18n 模板格式化为「已检查：N / 已新增：N↑ N↓ / 已删除：N↑ N↓」，
          // ↑=上传方向（本地→云端），↓=下载方向（云端→本地）。直接原样展示，不再替换符号。
          this.媒体进度文案 = `${this.取本地化文案($r('app.string.sync_syncing_media'))} ` +
            `${状态.progress.checked}  ${状态.progress.added}  ${状态.progress.removed}`;
          hilog.info(同步日志域, 同步日志标签,
            'sync: mediaPoll check#%{public}d elapsed=%{public}dms active=%{public}s everActive=%{public}s checked=%{public}s added=%{public}s removed=%{public}s',
            this.媒体检查次数, Date.now() - 轮询开始时间, 状态.active ? 'true' : 'false',
            this.媒体曾进入活跃 ? 'true' : 'false',
            状态.progress.checked, 状态.progress.added, 状态.progress.removed);
          // 完成判定：必须 mediaEverActive=true 后再 active=false 才算成功；
          // 30 秒内从未 active 视为未启动/秒退，报错让用户重试，不再兜底假成功。
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
              // 媒体同步成功，清除待完成标志。
              设置媒体待同步(false);
              this.同步完成回调();
            } else if (this.媒体检查次数 >= 30) {
              // 30 秒内媒体同步从未进入 active 状态：sync_media_blocking 可能秒退返回 Ok
              // 或 sync_media_in_background 因已有任务直接 return Ok 未启动新任务。
              hilog.error(同步日志域, 同步日志标签,
                'sync: mediaPoll FAILED_TO_START (30s elapsed, everActive=false, checkCount=%{public}d)',
                this.媒体检查次数);
              this.处理同步错误(new Error('media sync failed to start within 30s'));
            }
            // else: mediaEverActive=false && checkCount<30，继续等
          }
        })
        .catch((error: Error): void => {
          this.处理同步错误(error instanceof Error ? error : new Error(`${error}`));
        });
    }, 1000);
  }

  // ========================================================
  // @块ID COMP-SYNC-PANEL-007
  // @名称 同步弹窗 UI 构建器与主构建
  //
  // @作用
  // 渲染弹窗：磨砂遮罩 + 居中浮卡。浮卡内按 当前阶段 切换三种内容：
  // - syncing：LoadingProgress + 同步文案 + 媒体进度（用户决策 2026-07-23 移除中止按钮）；
  // - conflict：冲突说明 + 上传/下载按钮（无取消，强制选方向）；
  // - done：状态/错误文案 + 关闭按钮。
  // 头部行：标题 + × 关闭按钮（仅 done 阶段显示 ×，避免误触）。
  //
  // @输入
  // 读 this.当前阶段 / this.状态文案 / this.错误文案 / this.媒体进度文案 / this.当前冲突类型 / this.账号名 等。
  //
  // @输出
  // 一个全屏 Stack：磨砂遮罩层 + 居中浮卡（88% 宽，maxWidth 480）。
  //
  // @业务规则
  // canClose=false 时遮罩不响应点击（避免 syncing/conflict 期间误关）。
  // conflict 阶段：fullDownload 不展示上传按钮；fullUpload 不展示下载按钮。
  //
  // @副作用
  // 无（仅渲染；按钮点击通过回调上抛）。
  // ========================================================

  @Builder
  private 头部行() {
    Row() {
      Text(this.取本地化文案($r('app.string.settings_sync_group')))
        .fontSize(应用尺寸.字号_面板标题)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      // 仅 done 阶段显示 ×；syncing/conflict 隐藏避免误触
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

  /** syncing 阶段：LoadingProgress + 文案 + 媒体进度（用户决策 2026-07-23：移除中止按钮）。 */
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

  /** conflict 阶段：冲突说明 + 上传/下载按钮（无取消，强制选方向）。 */
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

    // 上传按钮：fullDownload 场景不展示
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
    // 下载按钮：fullUpload 场景不展示
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

  /** done 阶段：状态/错误文案 + 关闭按钮。 */
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
      // 磨砂玻璃遮罩：canClose=false 时不响应点击
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
        .transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))

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
      .constraintSize({ maxWidth: 480, maxHeight: '88%' })
      .padding(20)
      .backgroundColor(this.取色板().背景)
      .borderRadius(应用尺寸.圆角_卡片)
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }),
        TransitionEffect.opacity(0)
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() })
      ))
    }
    .width('100%')
    .height('100%')
  }
}
