// SPDX-License-Identifier: AGPL-3.0-or-later

import { loadFsrsEnabled, setFsrsEnabled } from '../../model/FsrsController';
import { settingsPalette, SettingsPalette } from '../../utils/SettingsColors';
import { COLOR_KEYS } from '../../model/ColorTheme';

/**
 * FSRS 调度器分组：开关 + 说明小字 + 错误提示。
 * 状态自管：fsrsEnabled/fsrsBusy/fsrsError；aboutToAppear 拉取后端当前值。
 * 乐观更新 UI，失败回滚并提示（与原 SettingsPanel 同语义）。
 */
@Component
export struct SchedulerGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  // ⓘ 按钮上抛：由父组件 SettingsPanel 统一渲染 FieldHelpPanel 浮层，避免嵌在分组卡片内
  onOpenHelp: (title: Resource, body: Resource) => void = (_title: Resource, _body: Resource): void => {};

  // @StorageLink 让本组件在 actionPrimary 变化时立即重渲染；resolvedPrimary() 直接引用此字段，
  // 让 FSRS 选中态主色在颜色主题切换瞬间同步更新（与 AppearanceGroup 同款机制）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';

  @State private fsrsEnabled: boolean | null = null;
  @State private fsrsBusy: boolean = false;
  @State private fsrsError: string = '';

  /** 面板打开时拉取 FSRS 当前状态与后端同步。失败时保留 null，UI 显示"读取失败"。 */
  async aboutToAppear(): Promise<void> {
    await this.refreshFsrsState();
  }

  private async refreshFsrsState(): Promise<void> {
    this.fsrsError = '';
    const value: boolean | null = await loadFsrsEnabled();
    this.fsrsEnabled = value;
    if (value === null) {
      this.fsrsError = this.localized($r('app.string.settings_fsrs_load_error'));
    }
  }

  /** 切换 FSRS 开关：乐观更新 UI，失败时回滚并提示。防重入避免快速连击。 */
  private async onFsrsToggle(value: boolean): Promise<void> {
    if (this.fsrsBusy || this.fsrsEnabled === null) {
      return;
    }
    const previous: boolean = this.fsrsEnabled;
    this.fsrsBusy = true;
    this.fsrsEnabled = value;
    this.fsrsError = '';
    try {
      await setFsrsEnabled(value);
    } catch (error) {
      this.fsrsEnabled = previous;
      this.fsrsError = error instanceof Error ? error.message : `${error}`;
    } finally {
      this.fsrsBusy = false;
    }
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行（与 AppearanceGroup 同款）。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_scheduler')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(palette.textSecondary)
      // 展开时才显示 ⓘ 按钮，点击弹出说明面板（替代原内联说明小字）
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
            this.onOpenHelp($r('app.string.settings_fsrs_label'), $r('app.string.settings_fsrs_help'));
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
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.onToggle(); });
    })
  }

  build() {
    Column() {
      this.groupHeader(settingsPalette(this.isDark))

      if (this.opened) {
        Column() {
          // FSRS 开关行：label + Toggle。说明文字已移到 groupHeader 的 ⓘ 按钮弹层中。
          // 注意：Toggle 的 isOn 必须用 $$ 双向绑定到 @State，否则开关不响应点击。
          // 但本场景需要乐观更新 + 失败回滚，所以改用单向绑定 + onChange 手动控制。
          Row() {
            Text($r('app.string.settings_fsrs_label'))
              .fontSize(15)
              .fontColor(settingsPalette(this.isDark).textPrimary)
              .layoutWeight(1)
            Blank()
            if (this.fsrsEnabled === null) {
              Text($r('app.string.settings_fsrs_loading'))
                .fontSize(13)
                .fontColor(settingsPalette(this.isDark).textTertiary)
            } else {
              Toggle({ type: ToggleType.Switch, isOn: this.fsrsEnabled })
                .selectedColor(this.resolvedPrimary())
                .enabled(!this.fsrsBusy)
                .onChange((value: boolean): void => {
                  this.onFsrsToggle(value);
                })
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          if (this.fsrsError !== '') {
            Text(this.fsrsError)
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).error)
              .width('100%')
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
