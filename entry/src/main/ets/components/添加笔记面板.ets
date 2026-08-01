// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 字段帮助面板 } from './字段帮助面板';
import { 颜色键 } from '../model/颜色主题';

export interface 添加笔记牌组选项 {
  id: number;
  name: string;
}

export interface 添加笔记笔记类型选项 {
  id: number;
  name: string;
}

interface 添加笔记下拉选项 {
  value: string;
}

@Component
export struct 添加笔记面板 {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop selectedDeckId: number = 0;
  @Prop deckOptions: 添加笔记牌组选项[] = [];
  @Prop selectedNotetypeId: number = 0;
  @Prop notetypeOptions: 添加笔记笔记类型选项[] = [];
  @Watch('onFieldNamesChanged')
  @Prop fieldNames: string[] = [];
  onCancel: () => void = (): void => {
  };
  onSelectDeck: (deckId: number) => void = (_牌组ID: number): void => {
  };
  onSelectNotetype: (notetypeId: number) => void = (_笔记类型ID: number): void => {
  };
  onSave: (fields: string[], tags: string[], notetypeId: number) => Promise<number> =
    async (_fields: string[], _tags: string[], _notetypeId: number): Promise<number> => 0;
  onSaved: (noteId: number) => void = (_noteId: number): void => {
  };

  @State private fieldValues: string[] = [];
  @State private tags: string = '';
  @State private 高级已展开: boolean = false;
  @State private 本地错误: string = '';
  @State private 显示帮助: boolean = false;
  @State private 帮助标题: Resource = $r('app.string.add_note_deck');
  @State private 帮助正文: Resource = $r('app.string.add_note_deck_help');

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下: string = '#1E4FB8';
  @State private 已按下保存: boolean = false;

  private 打开帮助(title: Resource, body: Resource): void {
    this.帮助标题 = title;
    this.帮助正文 = body;
    this.显示帮助 = true;
  }

  aboutToAppear(): void {
    this.确保字段值数组();
  }

  private onFieldNamesChanged(): void {
    this.fieldValues = this.fieldNames.map((_name: string): string => '');
  }

  private 确保字段值数组(): void {
    if (this.fieldValues.length !== this.fieldNames.length) {
      this.fieldValues = this.fieldNames.map((_name: string): string => '');
    }
  }

  private 选中牌组索引(): number {
    const 索引 = this.deckOptions.findIndex((牌组: 添加笔记牌组选项): boolean => 牌组.id === this.selectedDeckId);
    return 索引 < 0 ? 0 : 索引;
  }

  private 选中牌组名(): string {
    for (const 牌组 of this.deckOptions) {
      if (牌组.id === this.selectedDeckId) {
        return 牌组.name;
      }
    }
    return '';
  }

  private 牌组下拉选项(): 添加笔记下拉选项[] {
    const 选项: 添加笔记下拉选项[] = [];
    for (const 牌组 of this.deckOptions) {
      选项.push({ value: 牌组.name });
    }
    return 选项;
  }

  private 选中笔记类型索引(): number {
    const 索引 = this.notetypeOptions.findIndex(
      (笔记类型: 添加笔记笔记类型选项): boolean => 笔记类型.id === this.selectedNotetypeId);
    return 索引 < 0 ? 0 : 索引;
  }

  private 选中笔记类型名(): string {
    for (const 笔记类型 of this.notetypeOptions) {
      if (笔记类型.id === this.selectedNotetypeId) {
        return 笔记类型.name;
      }
    }
    return '';
  }

  private 笔记类型下拉选项(): 添加笔记下拉选项[] {
    const 选项: 添加笔记下拉选项[] = [];
    for (const 笔记类型 of this.notetypeOptions) {
      选项.push({ value: 笔记类型.name });
    }
    return 选项;
  }

  private 更新字段(索引: number, 值: string): void {
    const 新值 = this.fieldValues.slice();
    新值[索引] = 值;
    this.fieldValues = 新值;
  }

  private 解析标签(): string[] {
    const 已见: string[] = [];
    for (const 标签 of this.tags.split(/\s+/)) {
      const 修剪后 = 标签.trim();
      if (修剪后 !== '' && 已见.indexOf(修剪后) < 0) {
        已见.push(修剪后);
      }
    }
    return 已见;
  }

  private async 提交(): Promise<void> {
    if (this.busy || this.selectedDeckId === 0 || this.selectedNotetypeId === 0) {
      return;
    }
    this.本地错误 = '';
    try {
      const noteId = await this.onSave(this.fieldValues.slice(), this.解析标签(), this.selectedNotetypeId);
      this.fieldValues = this.fieldNames.map((_name: string): string => '');
      this.tags = '';
      this.onSaved(noteId);
    } catch (_错误) {
    }
  }

  @Builder
  private 带帮助的标签(label: Resource, help: Resource) {
    Row() {
      Text(label)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor(this.动作主色)
        .enabled(!this.busy)
        .onClick((): void => {
          this.打开帮助(label, help);
        })
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDark ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          if (!this.busy) {
            this.onCancel();
          }
        })

      Column({ space: 应用尺寸.间距_14 }) {
        Scroll() {
          Column({ space: 应用尺寸.间距_14 }) {
            Text($r('app.string.add_note_title'))
              .fontSize(应用尺寸.字号_面板标题)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            this.带帮助的标签($r('app.string.add_note_deck'), $r('app.string.add_note_deck_help'))
            Select(this.牌组下拉选项())
              .selected(this.选中牌组索引())
              .value(this.选中牌组名())
              .width('100%')
              .enabled(!this.busy && this.deckOptions.length > 0)
              .onSelect((index: number): void => {
                this.onSelectDeck(this.deckOptions[index].id);
              })

            this.带帮助的标签($r('app.string.add_note_notetype'), $r('app.string.add_note_notetype_help'))
            Select(this.笔记类型下拉选项())
              .selected(this.选中笔记类型索引())
              .value(this.选中笔记类型名())
              .width('100%')
              .enabled(!this.busy && this.notetypeOptions.length > 0)
              .onSelect((index: number): void => {
                this.onSelectNotetype(this.notetypeOptions[index].id);
              })

            ForEach(this.fieldNames, (字段名: string, index: number) => {
              Column({ space: 应用尺寸.间距_5 }) {
                Text(字段名)
                  .fontSize(应用尺寸.字号_正文_小)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                TextArea({ placeholder: 字段名, text: this.fieldValues[index] })
                  .width('100%')
                  .height(56)
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.surface_card'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                  .borderRadius(应用尺寸.圆角_面板)
                  .padding(应用尺寸.间距_10)
                  .enabled(!this.busy)
                  .onChange((value: string): void => {
                    this.更新字段(index, value);
                  })
              }
              .width('100%')
            }, (字段名: string, index: number): string => `${index}-${字段名}`)

            Button(this.高级已展开 ? $r('app.string.add_note_advanced_hide') : $r('app.string.add_note_advanced'))
              .width('100%')
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor(this.动作主色)
              .backgroundColor($r('app.color.surface_page'))
              .borderRadius(应用尺寸.圆角_面板)
              .enabled(!this.busy)
              .onClick((): void => {
                this.高级已展开 = !this.高级已展开;
              })

            if (this.高级已展开) {
              Column({ space: 应用尺寸.间距_5 }) {
                this.带帮助的标签($r('app.string.add_note_tags'), $r('app.string.add_note_tags_help'))
                TextInput({ placeholder: $r('app.string.add_note_tags_placeholder'), text: this.tags })
                  .width('100%')
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.surface_card'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
                  .borderRadius(应用尺寸.圆角_面板)
                  .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
                  .enabled(!this.busy)
                  .onChange((value: string): void => {
                    this.tags = value;
                  })
                Text($r('app.string.add_note_duplicate_rejected'))
                  .fontSize(应用尺寸.字号_正文_小)
                  .fontColor($r('app.color.text_tertiary'))
                  .width('100%')
              }
              .width('100%')
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)

        if (this.errorMessage !== '' || this.本地错误 !== '') {
          Text(this.errorMessage !== '' ? this.errorMessage : this.本地错误)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .maxLines(3)
        }

        Row({ space: 应用尺寸.间距_10 }) {
          Button($r('app.string.add_note_cancel'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.busy)
            .onClick((): void => {
              this.onCancel();
            })
          Button(this.busy ? $r('app.string.add_note_saving') : $r('app.string.add_note_save'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.已按下保存 ? this.主色按钮按下 : this.主色按钮背景)
            .borderRadius(应用尺寸.圆角_胶囊)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .enabled(!this.busy && this.fieldNames.length > 0)
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) {
                this.已按下保存 = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.已按下保存 = false;
              }
            })
            .onClick((): void => {
              this.提交();
            })
        }
        .width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 520, maxHeight: '88%' })
      .padding(应用尺寸.卡片内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .onClick(() => {
      })

      if (this.显示帮助) {
        字段帮助面板({
          title: this.帮助标题,
          body: this.帮助正文,
          onClose: (): void => {
            this.显示帮助 = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
