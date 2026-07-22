// SPDX-License-Identifier: AGPL-3.0-or-later

import { SettingsPalette, settingsPalette } from '../../utils/SettingsColors';
import { COLOR_KEYS } from '../../model/ColorTheme';

/**
 * 数据管理分组：导入牌组 / 导出牌组 两个入口行。
 * 纯回调传递，无内部状态；点击后由父组件（SettingsPanel → Index.ets）打开 DataTransferPanel。
 */
@Component
export struct DataGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  onImportData: () => void = (): void => {};
  onExportData: () => void = (): void => {};
  onHiddenDecks: () => void = (): void => {};

  // @StorageProp 触发颜色主题切换时重 build，让 settingsPalette(isDark).primary 即时变化
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_data_management')))
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
        Column() {
          // 导入行
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.settings_import_data'))
                .fontSize(15)
                .fontColor(settingsPalette(this.isDark).textPrimary)
              Text($r('app.string.transfer_import_deck'))
                .fontSize(12)
                .fontColor(settingsPalette(this.isDark).textMuted)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('›')
              .fontSize(20)
              .fontColor(settingsPalette(this.isDark).textMuted)
          }
          .width('100%')
          .height(58)
          .onClick(() => {
            this.onImportData();
          })

          // 导出行
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.settings_export_data'))
                .fontSize(15)
                .fontColor(settingsPalette(this.isDark).textPrimary)
              Text($r('app.string.transfer_export_deck'))
                .fontSize(12)
                .fontColor(settingsPalette(this.isDark).textMuted)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('›')
              .fontSize(20)
              .fontColor(settingsPalette(this.isDark).textMuted)
          }
          .width('100%')
          .height(58)
          .onClick(() => {
            this.onExportData();
          })

          // 已隐藏牌组行
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.hidden_decks_entry'))
                .fontSize(15)
                .fontColor(settingsPalette(this.isDark).textPrimary)
              Text($r('app.string.hidden_decks_entry_subtitle'))
                .fontSize(12)
                .fontColor(settingsPalette(this.isDark).textMuted)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('›')
              .fontSize(20)
              .fontColor(settingsPalette(this.isDark).textMuted)
          }
          .width('100%')
          .height(58)
          .onClick(() => {
            this.onHiddenDecks();
          })
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
