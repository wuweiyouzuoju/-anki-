// SPDX-License-Identifier: AGPL-3.0-or-later

import { SyncService } from '../../backend/SyncService';
import { BackendError } from '../../backend/errors';
import type { SyncAuth } from '../../proto/messages/SyncMessages';
import {
  clearSyncAuth,
  loadSyncAuth,
  saveSyncAuth
} from '../../model/SyncAuthStore';
import type { SyncAuthInfo } from '../../model/SyncAuthStore';
import { classifySyncError } from '../../model/SyncFlow';
import { SettingsPalette, settingsPalette } from '../../utils/SettingsColors';
import { COLOR_KEYS } from '../../model/ColorTheme';

/**
 * AnkiWeb 云同步分组（M10-T14 / B14 2026-07-22 重构）：
 * 仅负责登录/注销状态机，同步流程已抽到独立弹窗 SyncPanel。
 *
 * 三态简化为两态：loggedOut（登录表单）/ loggedIn（账号 + 立即同步/注销）。
 * 点「立即同步」时 loadSyncAuth 拿最新凭证（端点可能被 SyncPanel 更新过），
 * 上抛 onOpenSync(auth, accountName) 给 Index，Index 挂载 SyncPanel 弹窗。
 *
 * 同步流程不再放在本组件的原因：
 * - 之前在 SettingsPanel 内 syncing 中关闭会导致定时器泄漏、错误被吞、冲突中断；
 * - SyncPanel 作为独立弹窗，关闭守卫确保 syncing/conflict/abortRequested 期间不可关闭。
 */
@Component
export struct SyncGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  // 用户点「立即同步」：上抛当前 auth + 账号名给 Index，Index 挂载 SyncPanel 弹窗
  onOpenSync: (auth: SyncAuth, accountName: string) => void = (_auth: SyncAuth, _accountName: string): void => {};
  // 用户选「先备份后同步」：上抛给 Index 打开 DataTransferPanel 导出 collection
  // 备份完成用户自己回到设置页再点「立即同步」—— 备份与同步是两步分离操作
  onExportData: () => void = (): void => {};
  // ⓘ 按钮上抛：由父组件 SettingsPanel 统一渲染 FieldHelpPanel 浮层（与其他分组一致）
  onOpenHelp: (title: Resource, body: Resource) => void = (_title: Resource, _body: Resource): void => {};

  // @StorageLink 让本组件在 actionPrimary 变化时立即重渲染；resolvedPrimary() 直接引用此字段，
  // 让登录按钮主色在颜色主题切换瞬间同步更新（与 AppearanceGroup 同款机制）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';

  // ---- @State 全部集中声明在 struct 顶部（ArkTS 约束） ----
  /** 状态机：loggedOut / loggedIn（同步流程在 SyncPanel 弹窗，不占 phase） */
  @State private phase: 'loggedOut' | 'loggedIn' = 'loggedOut';
  /** 登录表单输入 */
  @State private usernameInput: string = '';
  @State private passwordInput: string = '';
  /** 登录请求进行中（按钮 busy 态显示 sync_logging_in） */
  @State private loginBusy: boolean = false;
  /** 已登录账号名（仅展示用） */
  @State private accountName: string = '';
  /** 错误提示（面板内红字） */
  @State private errorText: string = '';

  // ---- 内部（非 @State，不参与 UI 刷新） ----
  /** 登录成功后持有的会话凭证（hkey + endpoint） */
  private auth: SyncAuth | null = null;

  private readonly syncService: SyncService = new SyncService();

  aboutToAppear(): void {
    // 启动读取本地凭证：有 hkey 直接进 loggedIn（重启免登录）
    const info: SyncAuthInfo | null = loadSyncAuth();
    if (info !== null) {
      const auth: SyncAuth = {
        hkey: info.hkey,
        endpoint: info.endpoint,
        ioTimeoutSecs: 0
      };
      this.auth = auth;
      this.accountName = info.username;
      this.phase = 'loggedIn';
    } else {
      this.phase = 'loggedOut';
    }
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行（与 AppearanceGroup 同款）。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  /** 登录：成功持久化 hkey（密码绝不落盘）；失败按 classifySyncError 归类提示，停留 loggedOut。 */
  private async onLoginClick(): Promise<void> {
    if (this.loginBusy) {
      return;
    }
    this.loginBusy = true;
    this.errorText = '';
    try {
      const auth: SyncAuth = await this.syncService.syncLogin(this.usernameInput, this.passwordInput);
      const info: SyncAuthInfo = {
        hkey: auth.hkey,
        username: this.usernameInput,
        endpoint: auth.endpoint
      };
      saveSyncAuth(info);
      this.auth = auth;
      this.accountName = this.usernameInput;
      this.passwordInput = '';
      this.errorText = '';
      this.phase = 'loggedIn';
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(`${error}`);
      const backendKind: number | undefined = err instanceof BackendError ? err.kind : undefined;
      const kind = classifySyncError(err, backendKind);
      if (kind === 'auth') {
        // 诊断阶段：附带 kind 与实际错误信息，定位"原本可以现在不行"的真实原因
        this.errorText = `${this.localized($r('app.string.sync_error_auth'))} [kind=${backendKind ?? -1}]：${err.message}`;
      } else if (kind === 'network') {
        // 诊断阶段：附带 kind 与实际错误信息
        this.errorText = `${this.localized($r('app.string.sync_error_network'))} [kind=${backendKind ?? -1}]：${err.message}`;
      } else {
        this.errorText = `${this.localized($r('app.string.sync_error_generic'))} [kind=${backendKind ?? -1}]：${err.message}`;
      }
    } finally {
      this.loginBusy = false;
    }
  }

  /** 注销：弹 AlertDialog 二次确认后清空本地凭证与面板状态，回登录表单。 */
  private onLogoutClick(): void {
    AlertDialog.show({
      title: this.localized($r('app.string.sync_logout')),
      message: this.localized($r('app.string.sync_logout_confirm_message')),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: (): void => {}
      },
      secondaryButton: {
        value: $r('app.string.sync_logout'),
        fontColor: $r('app.color.error_text'),
        action: (): void => {
          this.confirmLogout();
        }
      }
    });
  }

  /** 真正执行注销：清凭证 + 清状态 + 回 loggedOut。 */
  private confirmLogout(): void {
    clearSyncAuth();
    this.auth = null;
    this.accountName = '';
    this.errorText = '';
    this.usernameInput = '';
    this.passwordInput = '';
    this.phase = 'loggedOut';
  }

  /**
   * 立即同步：loadSyncAuth 拿最新凭证（端点可能被上次 SyncPanel 更新过），
   * 上抛 onOpenSync 给 Index 挂载 SyncPanel 弹窗。
   */
  private onSyncNowClick(): void {
    const info: SyncAuthInfo | null = loadSyncAuth();
    if (info === null) {
      this.errorText = this.localized($r('app.string.sync_error_session_expired'));
      this.phase = 'loggedOut';
      return;
    }
    const auth: SyncAuth = {
      hkey: info.hkey,
      endpoint: info.endpoint,
      ioTimeoutSecs: 0
    };
    this.auth = auth;
    this.errorText = '';
    this.onOpenSync(auth, this.accountName);
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_sync_group')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(palette.textSecondary)
      // 展开时才显示 ⓘ 按钮，点击弹出说明面板（与 SchedulerGroup/VoiceGroup/GlossaryGroup 一致）
      if (this.opened) {
        Button($r('app.string.field_help_button'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontSize(14)
          .fontColor(palette.textTertiary)
          .width(28)
          .height(28)
          .padding(0)
          .onClick(() => {
            this.onOpenHelp($r('app.string.settings_sync_group'), $r('app.string.sync_help_text'));
          })
      }
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(palette.textMuted)
        .rotate({ angle: this.opened ? 0 : -90 })
    }
    .width('100%')
    .height(40)
    .onClick(() => {
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.onToggle();
      });
    })
  }

  /** loggedOut：副标题 + 用户名/密码输入 + 登录按钮 + 错误红字。 */
  @Builder
  private loggedOutContent(palette: SettingsPalette) {
    Text($r('app.string.sync_subtitle_logged_out'))
      .fontSize(12)
      .fontColor(palette.textSecondary)
      .width('100%')
    TextInput({ placeholder: $r('app.string.sync_username_hint'), text: this.usernameInput })
      .width('100%')
      .height(44)
      .fontSize(14)
      .fontColor(palette.textPrimary)
      .placeholderColor(palette.textMuted)
      .backgroundColor(palette.chipBg)
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .enabled(!this.loginBusy)
      .onChange((value: string) => {
        this.usernameInput = value;
      })
    TextInput({ placeholder: $r('app.string.sync_password_hint'), text: this.passwordInput })
      .width('100%')
      .height(44)
      .fontSize(14)
      .fontColor(palette.textPrimary)
      .placeholderColor(palette.textMuted)
      .backgroundColor(palette.chipBg)
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .type(InputType.Password)
      .enabled(!this.loginBusy)
      .onChange((value: string) => {
        this.passwordInput = value;
      })
      .onSubmit((): void => {
        this.onLoginClick();
      })
    Button(this.loginBusy ? $r('app.string.sync_logging_in') : $r('app.string.sync_login'))
      .width('100%')
      .height(44)
      .fontSize(15)
      .fontColor('#FFFFFF')
      .backgroundColor(this.resolvedPrimary())
      .borderRadius(22)
      .enabled(!this.loginBusy)
      .opacity(this.loginBusy ? 0.6 : 1)
      .onClick((): void => {
        this.onLoginClick();
      })
    if (this.errorText !== '') {
      Text(this.errorText)
        .fontSize(12)
        .fontColor(palette.error)
        .width('100%')
        .maxLines(8)
    }
  }

  /** loggedIn：账号名 + 先备份后同步/立即同步/注销 三按钮 + 错误提示。 */
  @Builder
  private loggedInContent(palette: SettingsPalette) {
    Text(this.accountName)
      .fontSize(15)
      .fontColor(palette.textPrimary)
      .width('100%')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    // B12-Y2 2026-07-22：三按钮都用中性底（chipBg），无主色按钮
    // 用户决策：三个按钮不需要颜色，因「立即同步」与「先备份后同步」都是用户主动选的操作，
    // 无主次关系；注销按钮本就是次按钮，统一风格更协调
    Row({ space: 8 }) {
      Button($r('app.string.sync_backup_first'))
        .layoutWeight(1)
        .height(40)
        .fontSize(13)
        .fontColor(palette.textPrimary)
        .backgroundColor(palette.chipBg)
        .borderRadius(20)
        .onClick((): void => {
          this.onExportData();
        })
      Button($r('app.string.sync_now'))
        .layoutWeight(1)
        .height(40)
        .fontSize(13)
        .fontColor(palette.textPrimary)
        .backgroundColor(palette.chipBg)
        .borderRadius(20)
        .onClick((): void => {
          this.onSyncNowClick();
        })
      Button($r('app.string.sync_logout'))
        .layoutWeight(1)
        .height(40)
        .fontSize(13)
        .fontColor(palette.textPrimary)
        .backgroundColor(palette.chipBg)
        .borderRadius(20)
        .onClick((): void => {
          this.onLogoutClick();
        })
    }
    .width('100%')
    if (this.errorText !== '') {
      Text(this.errorText)
        .fontSize(12)
        .fontColor(palette.error)
        .width('100%')
        .maxLines(8)
    }
  }

  build() {
    Column() {
      this.groupHeader(settingsPalette(this.isDark))

      if (this.opened) {
        Column({ space: 10 }) {
          if (this.phase === 'loggedOut') {
            this.loggedOutContent(settingsPalette(this.isDark))
          } else {
            this.loggedInContent(settingsPalette(this.isDark))
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(settingsPalette(this.isDark).bg)
    .borderRadius(12)
  }
}
