// SPDX-License-Identifier: AGPL-3.0-or-later

import type { 整库导出选项, 牌组导出选项 } from '../model/数据传输模型';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 设置面板色板_取 } from '../utils/设置面板配色';
import { 颜色键 } from '../model/颜色主题';

export type 数据迁移模式 = 'exportDeck' | 'exportPersonalData' | 'importDeck' | 'importPersonalData';

export interface 导出牌组选项 {
  id: number;
  name: string;
}

export interface 导出牌组意图 {
  kind: 'exportDeck';
  deckId: number;
  options: 牌组导出选项;
}

export interface 导出个人数据意图 {
  kind: 'exportPersonalData';
  options: 整库导出选项;
}

export interface 导入牌组意图 {
  kind: 'importDeck';
}

export interface 替换个人数据意图 {
  kind: 'replacePersonalData';
  confirmed: true;
}

export type 数据迁移意图 = 导出牌组意图 | 导出个人数据意图 | 导入牌组意图 | 替换个人数据意图;

class 牌组选择项 {
  value: string = '';
}

const 迁移模式列表: 数据迁移模式[] = ['exportDeck', 'exportPersonalData', 'importDeck', 'importPersonalData'];

@Component
export struct 数据迁移面板 {
  @Prop deckId: number = 0;
  @Prop initialMode: 数据迁移模式 = 'exportDeck';
  @Prop deckOptions: 导出牌组选项[] = [];
  @Prop allowDeckSelection: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop personalReplacementStep: number = 0;
  @Prop stage: number = -1;
  @Prop isDark: boolean = false;
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @State private 模式: 数据迁移模式 = 'exportDeck';
  @State private 已选导出牌组Id: number = 0;
  @State private 包含调度信息: boolean = true;
  @State private 包含牌组配置: boolean = true;
  @State private 包含媒体: boolean = true;
  @State private 旧版兼容: boolean = false;
  @State private 已确认替换个人数据: boolean = false;
  onIntent: (意图: 数据迁移意图) => void = (_意图: 数据迁移意图): void => {};
  onClose: () => void = (): void => {};

  aboutToAppear(): void {
    this.模式 = this.initialMode;
    this.已选导出牌组Id = this.deckId;
    if (this.已选导出牌组Id <= 0 && this.deckOptions.length > 0) {
      this.已选导出牌组Id = this.deckOptions[0].id;
    }
  }

  private 已选牌组索引(): number {
    const 索引 = this.deckOptions.findIndex((牌组: 导出牌组选项): boolean => 牌组.id === this.已选导出牌组Id);
    return 索引 < 0 ? 0 : 索引;
  }

  private 已选牌组名称(): string {
    for (const 牌组 of this.deckOptions) {
      if (牌组.id === this.已选导出牌组Id) {
        return 牌组.name;
      }
    }
    return '';
  }

  private 牌组下拉选项(): 牌组选择项[] {
    return this.deckOptions.map((牌组: 导出牌组选项): 牌组选择项 => {
      const 选项 = new 牌组选择项();
      选项.value = 牌组.name;
      return 选项;
    });
  }

  private 解析文本(资源: Resource): string { return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id); }
  private 模式标签(模式: 数据迁移模式): string {
    if (模式 === 'exportDeck') return this.解析文本($r('app.string.transfer_export_deck'));
    if (模式 === 'exportPersonalData') return this.解析文本($r('app.string.transfer_export_personal'));
    if (模式 === 'importDeck') return this.解析文本($r('app.string.transfer_import_deck'));
    return this.解析文本($r('app.string.transfer_import_personal'));
  }

  private 副标题(): string {
    if (this.模式 === 'exportDeck') return this.解析文本($r('app.string.transfer_subtitle_export_deck'));
    if (this.模式 === 'exportPersonalData') return this.解析文本($r('app.string.transfer_subtitle_export_personal'));
    if (this.模式 === 'importDeck') return this.解析文本($r('app.string.transfer_subtitle_import_deck'));
    return this.解析文本($r('app.string.transfer_subtitle_import_personal'));
  }

  private 主按钮文案(): string {
    if (this.模式 === 'importDeck') return this.解析文本($r('app.string.transfer_import_deck_merge'));
    if (this.模式 === 'importPersonalData') {
      return this.personalReplacementStep === 0
        ? this.解析文本($r('app.string.transfer_confirm_personal'))
        : this.解析文本($r('app.string.transfer_replace_personal'));
    }
    return this.解析文本($r('app.string.continue'));
  }

  private 忙碌文案(): string {
    if (this.模式 === 'exportDeck' || this.模式 === 'exportPersonalData') {
      return this.解析文本($r('app.string.transfer_exporting'));
    }
    return this.解析文本($r('app.string.transfer_importing'));
  }

  private 阶段文案(): string {
    if (this.stage < 0) return this.忙碌文案();
    if (this.模式 === 'importDeck') {
      if (this.stage === 0) return this.解析文本($r('app.string.transfer_stage_prepare_file'));
      if (this.stage === 1) return this.解析文本($r('app.string.transfer_stage_import_data'));
      if (this.stage === 2) return this.解析文本($r('app.string.transfer_stage_refresh_list'));
    } else if (this.模式 === 'exportDeck' || this.模式 === 'exportPersonalData') {
      if (this.stage === 0) return this.解析文本($r('app.string.transfer_stage_export_data'));
      if (this.stage === 1) return this.解析文本($r('app.string.transfer_stage_save_file'));
    } else if (this.模式 === 'importPersonalData') {
      if (this.stage === 0) return this.解析文本($r('app.string.transfer_stage_prepare_file'));
      if (this.stage === 1) return this.解析文本($r('app.string.transfer_stage_close_db'));
      if (this.stage === 2) return this.解析文本($r('app.string.transfer_stage_import_data'));
      if (this.stage === 3) return this.解析文本($r('app.string.transfer_stage_restore_db'));
      if (this.stage === 4) return this.解析文本($r('app.string.transfer_stage_refresh_list'));
    }
    return this.忙碌文案();
  }

  private 打开旧版帮助(): void {
    this.getUIContext().showAlertDialog({
      title: this.解析文本($r('app.string.transfer_legacy')),
      message: this.解析文本($r('app.string.transfer_legacy_help')),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: this.解析文本($r('app.string.close')),
        action: (): void => {}
      }
    });
  }

  private 可提交(): boolean {
    if (this.模式 === 'exportDeck') return this.已选导出牌组Id > 0;
    if (this.模式 === 'importPersonalData') return this.已确认替换个人数据;
    return true;
  }

  private 提交(): void {
    if (this.模式 === 'exportDeck') {
      if (this.已选导出牌组Id <= 0) return;
      const 选项: 牌组导出选项 = {
        withScheduling: this.包含调度信息, withDeckConfigs: this.包含牌组配置,
        withMedia: this.包含媒体, legacy: this.旧版兼容
      };
      const 意图: 导出牌组意图 = { kind: 'exportDeck', deckId: this.已选导出牌组Id, options: 选项 };
      this.onIntent(意图);
      return;
    }
    if (this.模式 === 'exportPersonalData') {
      const 选项: 整库导出选项 = { includeMedia: this.包含媒体, legacy: this.旧版兼容 };
      const 意图: 导出个人数据意图 = { kind: 'exportPersonalData', options: 选项 };
      this.onIntent(意图);
      return;
    }
    if (this.模式 === 'importDeck') {
      const 意图: 导入牌组意图 = { kind: 'importDeck' };
      this.onIntent(意图);
      return;
    }
    if (this.已确认替换个人数据) {
      const 意图: 替换个人数据意图 = { kind: 'replacePersonalData', confirmed: true };
      this.onIntent(意图);
    }
  }

  private 模式下拉选项(): 牌组选择项[] {
    return 迁移模式列表.map((模式: 数据迁移模式): 牌组选择项 => {
      const 选项 = new 牌组选择项();
      选项.value = this.模式标签(模式);
      return 选项;
    });
  }

  private 模式下拉索引(): number {
    const 索引 = 迁移模式列表.indexOf(this.模式);
    return 索引 < 0 ? 0 : 索引;
  }

  @Builder 选项行(标签: string, 是否开启: boolean, 改变回调: (值: boolean) => void) {
    Row() {
      Text(标签)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: 是否开启 })
        .onChange(改变回调)
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(设置面板色板_取(this.isDark).遮罩)
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => { if (!this.busy) this.onClose(); })

      Column({ space: 应用尺寸.间距_12 }) {
      Row() {
        Column() {
          Text(this.解析文本($r('app.string.transfer_panel_title')))
            .fontSize(应用尺寸.字号_面板标题)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
          Text(this.副标题())
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 应用尺寸.间距_4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

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

      Select(this.模式下拉选项())
        .selected(this.模式下拉索引())
        .value(this.模式标签(this.模式))
        .width('100%')
        .enabled(!this.busy)
        .onSelect((索引: number): void => {
          this.模式 = 迁移模式列表[索引];
        })

      if (this.模式 === 'exportDeck' && this.allowDeckSelection) {
        Row() {
          Text(this.解析文本($r('app.string.transfer_label_deck')))
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.text_primary'))
            .margin({ right: 应用尺寸.间距_8 })
          Select(this.牌组下拉选项())
            .selected(this.已选牌组索引())
            .value(this.已选牌组名称())
            .layoutWeight(1)
            .enabled(!this.busy && this.deckOptions.length > 0)
            .onSelect((索引: number): void => {
              this.已选导出牌组Id = this.deckOptions[索引].id;
            })
        }
        .width('100%')
      }

      if (this.模式 === 'exportDeck' || this.模式 === 'exportPersonalData') {
        Column({ space: 应用尺寸.间距_8 }) {
          if (this.模式 === 'exportDeck') {
            this.选项行(this.解析文本($r('app.string.transfer_include_scheduling')),
              this.包含调度信息, (值: boolean) => { this.包含调度信息 = 值; })
            this.选项行(this.解析文本($r('app.string.transfer_include_deck_configs')),
              this.包含牌组配置, (值: boolean) => { this.包含牌组配置 = 值; })
          }
          this.选项行(this.解析文本($r('app.string.transfer_include_media')),
            this.包含媒体, (值: boolean) => { this.包含媒体 = 值; })
          Row() {
            Text(this.解析文本($r('app.string.transfer_legacy')))
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Button($r('app.string.field_help_button'))
              .type(ButtonType.Normal)
              .backgroundColor(Color.Transparent)
              .fontColor(this.主色按钮背景)
              .fontSize(应用尺寸.字号_正文)
              .onClick(() => this.打开旧版帮助())
            Toggle({ type: ToggleType.Switch, isOn: this.旧版兼容 })
              .onChange((值: boolean) => { this.旧版兼容 = 值; })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.模式 === 'importPersonalData') {
        Column({ space: 应用尺寸.间距_8 }) {
          Row({ space: 应用尺寸.间距_8 }) {
            Text('⚠')
              .fontSize(应用尺寸.字号_标题)
              .fontColor('#D32F2F')
            Text(this.解析文本($r('app.string.transfer_personal_replace_warning')))
              .fontSize(应用尺寸.字号_正文_中)
              .fontColor('#D32F2F')
              .layoutWeight(1)
          }
          .width('100%')
          Row() {
            Text(this.解析文本($r('app.string.transfer_acknowledge_personal')))
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Toggle({ type: ToggleType.Checkbox, isOn: this.已确认替换个人数据 })
              .onChange((是否开启: boolean) => { this.已确认替换个人数据 = 是否开启; })
          }
          .width('100%')
        }
        .width('100%')
        .padding(应用尺寸.间距_12)
        .backgroundColor('#FFEBEE')
        .borderRadius(应用尺寸.圆角_面板)
      }

      if (this.errorMessage !== '') {
        Text(this.errorMessage)
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor('#D32F2F')
          .width('100%')
      }

      Button(this.主按钮文案())
        .width('100%')
        .height(应用尺寸.按钮高度)
        .fontSize(应用尺寸.字号_按钮)
        .fontColor($r('app.color.action_on_primary'))
        .backgroundColor(this.主色按钮背景)
        .borderRadius(应用尺寸.圆角_胶囊)
        .enabled(!this.busy && (this.模式 !== 'exportDeck' || this.已选导出牌组Id > 0) &&
          (this.模式 !== 'importPersonalData' || this.已确认替换个人数据))
        .onClick(() => this.提交())

      if (this.busy) {
        Row({ space: 应用尺寸.间距_8 }) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.action_primary'))
          Text(this.阶段文案())
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('75%')
    .constraintSize({ maxWidth: 480 })
    .padding(应用尺寸.卡片内边距)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(应用尺寸.圆角_卡片)
    }
  }
}
