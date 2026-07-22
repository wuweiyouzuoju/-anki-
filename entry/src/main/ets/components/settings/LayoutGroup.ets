// SPDX-License-Identifier: AGPL-3.0-or-later

import { loadStudyLayoutMode, saveStudyLayoutMode, StudyLayoutMode } from '../../model/StudyLayoutStore';
import { SettingsPalette, settingsPalette, chipTextColor } from '../../utils/SettingsColors';
import { COLOR_KEYS } from '../../model/ColorTheme';

/**
 * 复习页布局分组：底部固定 / 浮动可拖 两种模式切换。
 * studyLayoutMode=null 表示加载中；加载失败回退 'bottom'。
 * 切换后立即生效（下次进入复习页）。
 */
@Component
export struct LayoutGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};

  // @StorageLink 让本组件在 actionPrimary 变化时立即重渲染；resolvedPrimary() 直接引用此字段，
  // 让布局选中态主色在颜色主题切换瞬间同步更新（与 AppearanceGroup 同款机制）。
  @StorageLink(COLOR_KEYS.actionPrimary) private actionPrimaryLink: string = '';

  @State private studyLayoutMode: StudyLayoutMode | null = null;

  async aboutToAppear(): Promise<void> {
    // 失败回退到 'bottom'（默认），保证 chip 一直可选。
    try {
      this.studyLayoutMode = await loadStudyLayoutMode();
    } catch (error) {
      this.studyLayoutMode = 'bottom';
    }
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  /** 选中态主色：直接引用 @StorageLink actionPrimaryLink 让颜色主题切换时 @Builder 重执行（与 AppearanceGroup 同款）。 */
  private resolvedPrimary(): string {
    return this.actionPrimaryLink !== '' ? this.actionPrimaryLink : settingsPalette(this.isDark).primary;
  }

  /** 复习页布局模式标签：bottom=底部固定；float=浮动可拖。 */
  private layoutLabel(mode: StudyLayoutMode): string {
    if (mode === 'float') {
      return this.localized($r('app.string.settings_study_layout_float'));
    }
    return this.localized($r('app.string.settings_study_layout_bottom'));
  }

  /** 切换布局模式：乐观更新 UI + 异步持久化；持久化失败仅丢失下次启动后的值，不回滚 UI。 */
  private async onLayoutChange(mode: StudyLayoutMode): Promise<void> {
    if (this.studyLayoutMode === mode) {
      return;
    }
    this.studyLayoutMode = mode;
    try {
      await saveStudyLayoutMode(mode);
    } catch (error) {
      // 持久化失败可接受：UI 已切换，下次启动会回退到上次保存的值。
    }
  }

  @Builder
  private layoutButton(palette: SettingsPalette, mode: StudyLayoutMode) {
    Button(this.layoutLabel(mode))
      .height(36)
      .fontSize(13)
      .fontColor(chipTextColor(palette, this.studyLayoutMode === mode))
      .backgroundColor(this.studyLayoutMode === mode ? this.resolvedPrimary() : palette.chipBg)
      .borderRadius(18)
      .margin({ right: 8, bottom: 6 })
      .onClick((): void => {
        if (this.studyLayoutMode !== null) {
          this.onLayoutChange(mode);
        }
      })
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_study_layout')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(palette.textSecondary)
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
        Column({ space: 8 }) {
          // 模式 chip：加载中（null）时也渲染但不可点；切换后立即生效（下次进入复习页）。
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
            this.layoutButton(settingsPalette(this.isDark), 'bottom');
            this.layoutButton(settingsPalette(this.isDark), 'float');
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })

          // 拖动提示：仅 float 模式下显示，告诉用户工具栏可以拖到侧边。
          if (this.studyLayoutMode === 'float') {
            Text($r('app.string.study_toolbar_drag_hint'))
              .fontSize(12)
              .fontColor(settingsPalette(this.isDark).textTertiary)
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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
