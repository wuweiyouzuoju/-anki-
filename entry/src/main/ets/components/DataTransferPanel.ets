// SPDX-License-Identifier: AGPL-3.0-or-later

import type { CollectionExportOptions, DeckExportOptions } from '../model/DataTransferModels';
import { AppDimens } from '../utils/AppDimens';
import { settingsPalette } from '../utils/SettingsColors';

export type DataTransferMode = 'exportDeck' | 'exportPersonalData' | 'importDeck' | 'importPersonalData';

export interface ExportDeckOption {
  id: number;
  name: string;
}

export interface ExportDeckIntent {
  kind: 'exportDeck';
  deckId: number;
  options: DeckExportOptions;
}

export interface ExportPersonalDataIntent {
  kind: 'exportPersonalData';
  options: CollectionExportOptions;
}

export interface ImportDeckIntent {
  kind: 'importDeck';
}

export interface ReplacePersonalDataIntent {
  kind: 'replacePersonalData';
  confirmed: true;
}

export type DataTransferIntent = ExportDeckIntent | ExportPersonalDataIntent | ImportDeckIntent | ReplacePersonalDataIntent;

class DeckSelectOption {
  value: string = '';
}

const TRANSFER_MODES: DataTransferMode[] = ['exportDeck', 'exportPersonalData', 'importDeck', 'importPersonalData'];

/** Presentation-only data management panel. File and backend work stay with its owner. */
@Component
export struct DataTransferPanel {
  @Prop deckId: number = 0;
  @Prop initialMode: DataTransferMode = 'exportDeck';
  @Prop deckOptions: ExportDeckOption[] = [];
  @Prop allowDeckSelection: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop personalReplacementStep: number = 0;
  @Prop stage: number = -1;
  @Prop isDark: boolean = false;
  @State private mode: DataTransferMode = 'exportDeck';
  @State private selectedExportDeckId: number = 0;
  @State private includeScheduling: boolean = true;
  @State private includeDeckConfigs: boolean = true;
  @State private includeMedia: boolean = true;
  @State private legacy: boolean = false;
  @State private personalReplacementAcknowledged: boolean = false;
  onIntent: (intent: DataTransferIntent) => void = (_intent: DataTransferIntent): void => {};
  onClose: () => void = (): void => {};

  aboutToAppear(): void {
    this.mode = this.initialMode;
    this.selectedExportDeckId = this.deckId;
    if (this.selectedExportDeckId <= 0 && this.deckOptions.length > 0) {
      this.selectedExportDeckId = this.deckOptions[0].id;
    }
  }

  private selectedDeckIndex(): number {
    const index = this.deckOptions.findIndex((deck: ExportDeckOption): boolean => deck.id === this.selectedExportDeckId);
    return index < 0 ? 0 : index;
  }

  // 官方 Select 文档：selected 仅控制菜单初始高亮，按钮文本需由 value 提供，否则框内空白
  private selectedDeckName(): string {
    for (const deck of this.deckOptions) {
      if (deck.id === this.selectedExportDeckId) {
        return deck.name;
      }
    }
    return '';
  }

  private deckSelectOptions(): DeckSelectOption[] {
    return this.deckOptions.map((deck: ExportDeckOption): DeckSelectOption => {
      const option = new DeckSelectOption();
      option.value = deck.name;
      return option;
    });
  }

  // 官方 Select 文档：selected 仅控制菜单初始高亮，按钮文本需由 value 提供，否则框内空白。
  // value 必须传 string：传 Resource 时按钮文本不显示（同 AdvancedDeckOptionsPanel 同款 bug）。
  private resolveText(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource.id); }
  private modeLabel(mode: DataTransferMode): string {
    if (mode === 'exportDeck') return this.resolveText($r('app.string.transfer_export_deck'));
    if (mode === 'exportPersonalData') return this.resolveText($r('app.string.transfer_export_personal'));
    if (mode === 'importDeck') return this.resolveText($r('app.string.transfer_import_deck'));
    return this.resolveText($r('app.string.transfer_import_personal'));
  }

  private subtitle(): string {
    if (this.mode === 'exportDeck') return this.resolveText($r('app.string.transfer_subtitle_export_deck'));
    if (this.mode === 'exportPersonalData') return this.resolveText($r('app.string.transfer_subtitle_export_personal'));
    if (this.mode === 'importDeck') return this.resolveText($r('app.string.transfer_subtitle_import_deck'));
    return this.resolveText($r('app.string.transfer_subtitle_import_personal'));
  }

  private primaryButtonLabel(): string {
    if (this.mode === 'importDeck') return this.resolveText($r('app.string.transfer_import_deck_merge'));
    if (this.mode === 'importPersonalData') {
      return this.personalReplacementStep === 0
        ? this.resolveText($r('app.string.transfer_confirm_personal'))
        : this.resolveText($r('app.string.transfer_replace_personal'));
    }
    return this.resolveText($r('app.string.continue'));
  }

  private busyLabel(): string {
    if (this.mode === 'exportDeck' || this.mode === 'exportPersonalData') {
      return this.resolveText($r('app.string.transfer_exporting'));
    }
    return this.resolveText($r('app.string.transfer_importing'));
  }

  // 阶段文案：根据 mode + stage 返回对应文字；stage < 0 时回退到通用 busyLabel
  private stageLabel(): string {
    if (this.stage < 0) return this.busyLabel();
    if (this.mode === 'importDeck') {
      if (this.stage === 0) return this.resolveText($r('app.string.transfer_stage_prepare_file'));
      if (this.stage === 1) return this.resolveText($r('app.string.transfer_stage_import_data'));
      if (this.stage === 2) return this.resolveText($r('app.string.transfer_stage_refresh_list'));
    } else if (this.mode === 'exportDeck' || this.mode === 'exportPersonalData') {
      if (this.stage === 0) return this.resolveText($r('app.string.transfer_stage_export_data'));
      if (this.stage === 1) return this.resolveText($r('app.string.transfer_stage_save_file'));
    } else if (this.mode === 'importPersonalData') {
      if (this.stage === 0) return this.resolveText($r('app.string.transfer_stage_prepare_file'));
      if (this.stage === 1) return this.resolveText($r('app.string.transfer_stage_close_db'));
      if (this.stage === 2) return this.resolveText($r('app.string.transfer_stage_import_data'));
      if (this.stage === 3) return this.resolveText($r('app.string.transfer_stage_restore_db'));
      if (this.stage === 4) return this.resolveText($r('app.string.transfer_stage_refresh_list'));
    }
    return this.busyLabel();
  }

  private canSubmit(): boolean {
    if (this.mode === 'exportDeck') return this.selectedExportDeckId > 0;
    if (this.mode === 'importPersonalData') return this.personalReplacementAcknowledged;
    return true;
  }

  private submit(): void {
    if (this.mode === 'exportDeck') {
      if (this.selectedExportDeckId <= 0) return;
      const options: DeckExportOptions = {
        withScheduling: this.includeScheduling, withDeckConfigs: this.includeDeckConfigs,
        withMedia: this.includeMedia, legacy: this.legacy
      };
      const intent: ExportDeckIntent = { kind: 'exportDeck', deckId: this.selectedExportDeckId, options: options };
      this.onIntent(intent);
      return;
    }
    if (this.mode === 'exportPersonalData') {
      const options: CollectionExportOptions = { includeMedia: this.includeMedia, legacy: this.legacy };
      const intent: ExportPersonalDataIntent = { kind: 'exportPersonalData', options: options };
      this.onIntent(intent);
      return;
    }
    if (this.mode === 'importDeck') {
      const intent: ImportDeckIntent = { kind: 'importDeck' };
      this.onIntent(intent);
      return;
    }
    if (this.personalReplacementAcknowledged) {
      const intent: ReplacePersonalDataIntent = { kind: 'replacePersonalData', confirmed: true };
      this.onIntent(intent);
    }
  }

  // 模式 Tab：选中态用 primary_container 背景 + action_primary 文字；未选中用 surface_page + text_secondary
  @Builder modeTab(mode: DataTransferMode) {
    Text(this.modeLabel(mode))
      .fontSize(AppDimens.FONT_BODY_M)
      .fontColor(this.mode === mode ? $r('app.color.action_primary') : $r('app.color.text_secondary'))
      .padding({
        left: AppDimens.SPACE_12, right: AppDimens.SPACE_12,
        top: AppDimens.SPACE_8, bottom: AppDimens.SPACE_8
      })
      .backgroundColor(this.mode === mode ? $r('app.color.surface_selected') : $r('app.color.surface_page'))
      .borderRadius(AppDimens.RADIUS_PILL)
      .enabled(!this.busy)
      .onClick(() => { this.mode = mode; })
  }

  // 选项行：label 左侧 layoutWeight(1) 撑满 + Toggle 右侧
  @Builder optionRow(label: string, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(AppDimens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange)
    }
    .width('100%')
  }

  build() {
    Stack() {
      // B13 2026-07-22：磨砂玻璃遮罩层（Thin 比 Regular/Thick 更轻薄，避免磨砂过厚）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(settingsPalette(this.isDark).mask)
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => { if (!this.busy) this.onClose(); })

      Column({ space: AppDimens.SPACE_12 }) {
      // === Header：标题 + 副标题 + 右上角 × ===
      Row() {
        Column() {
          Text(this.resolveText($r('app.string.transfer_panel_title')))
            .fontSize(AppDimens.FONT_PANEL_TITLE)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
          Text(this.subtitle())
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: AppDimens.SPACE_4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // B13 2026-07-22：busy 期间隐藏右上角 ×，避免误触；标题列 layoutWeight 自动撑满
        if (!this.busy) {
          Text('×')
            .fontSize(24)
            .fontColor($r('app.color.text_secondary'))
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.onClose(); })
        }
      }
      .width('100%')

      // === 模式选择 Tab（4 个水平排列）===
      Row({ space: AppDimens.SPACE_4 }) {
        this.modeTab('exportDeck')
        this.modeTab('exportPersonalData')
        this.modeTab('importDeck')
        this.modeTab('importPersonalData')
      }
      .width('100%')

      // === 牌组选择（仅 exportDeck 且允许选牌）===
      if (this.mode === 'exportDeck' && this.allowDeckSelection) {
        Row() {
          Text(this.resolveText($r('app.string.transfer_label_deck')))
            .fontSize(AppDimens.FONT_BODY)
            .fontColor($r('app.color.text_primary'))
            .margin({ right: AppDimens.SPACE_8 })
          Select(this.deckSelectOptions())
            .selected(this.selectedDeckIndex())
            .value(this.selectedDeckName())
            .layoutWeight(1)
            .enabled(!this.busy && this.deckOptions.length > 0)
            .onSelect((index: number): void => {
              this.selectedExportDeckId = this.deckOptions[index].id;
            })
        }
        .width('100%')
      }

      // === 导出选项（默认展开，label+Toggle 同行）===
      if (this.mode === 'exportDeck' || this.mode === 'exportPersonalData') {
        Column({ space: AppDimens.SPACE_8 }) {
          if (this.mode === 'exportDeck') {
            this.optionRow(this.resolveText($r('app.string.transfer_include_scheduling')),
              this.includeScheduling, (value: boolean) => { this.includeScheduling = value; })
            this.optionRow(this.resolveText($r('app.string.transfer_include_deck_configs')),
              this.includeDeckConfigs, (value: boolean) => { this.includeDeckConfigs = value; })
          }
          this.optionRow(this.resolveText($r('app.string.transfer_include_media')),
            this.includeMedia, (value: boolean) => { this.includeMedia = value; })
          this.optionRow(this.resolveText($r('app.string.transfer_legacy')),
            this.legacy, (value: boolean) => { this.legacy = value; })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      // === 个人数据替换警告（红色背景 + ⚠ + 勾选确认）===
      if (this.mode === 'importPersonalData') {
        Column({ space: AppDimens.SPACE_8 }) {
          Row({ space: AppDimens.SPACE_8 }) {
            Text('⚠')
              .fontSize(AppDimens.FONT_TITLE)
              .fontColor('#D32F2F')
            Text(this.resolveText($r('app.string.transfer_personal_replace_warning')))
              .fontSize(AppDimens.FONT_BODY_M)
              .fontColor('#D32F2F')
              .layoutWeight(1)
          }
          .width('100%')
          Row() {
            Text(this.resolveText($r('app.string.transfer_acknowledge_personal')))
              .fontSize(AppDimens.FONT_BODY)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Toggle({ type: ToggleType.Checkbox, isOn: this.personalReplacementAcknowledged })
              .onChange((isOn: boolean) => { this.personalReplacementAcknowledged = isOn; })
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppDimens.SPACE_12)
        .backgroundColor('#FFEBEE')
        .borderRadius(AppDimens.RADIUS_PANEL)
      }

      // === 错误信息（红字）===
      if (this.errorMessage !== '') {
        Text(this.errorMessage)
          .fontSize(AppDimens.FONT_BODY_M)
          .fontColor('#D32F2F')
          .width('100%')
      }

      // === 主按钮（primary 色）===
      Button(this.primaryButtonLabel())
        .width('100%')
        .height(AppDimens.BUTTON_HEIGHT)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontColor($r('app.color.action_on_primary'))
        .backgroundColor($r('app.color.action_primary'))
        .borderRadius(AppDimens.RADIUS_PILL)
        .enabled(!this.busy && (this.mode !== 'exportDeck' || this.selectedExportDeckId > 0) &&
          (this.mode !== 'importPersonalData' || this.personalReplacementAcknowledged))
        .onClick(() => this.submit())

      // === busy LoadingProgress + 文案 ===
      if (this.busy) {
        Row({ space: AppDimens.SPACE_8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.action_primary'))
          Text(this.stageLabel())
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('75%')
    // B12-Y2 2026-07-22：maxWidth 400 → 480（与 CreateDeckPanel/SettingsPanel 等其他弹层一致）
    .constraintSize({ maxWidth: 480 })
    .padding(AppDimens.CARD_PADDING)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(AppDimens.RADIUS_CARD)
    }
  }
}
