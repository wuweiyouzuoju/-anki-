// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';
import { FieldHelpPanel } from './FieldHelpPanel';
import { COLOR_KEYS } from '../model/ColorTheme';

export interface AddNoteDeckOption {
  id: number;
  name: string;
}

export interface AddNoteNotetypeOption {
  id: number;
  name: string;
}

interface AddNoteSelectOption {
  value: string;
}

/**
 * Presentation-only add-note sheet. Its parent owns all backend calls and
 * returns a note id only after Anki has accepted the note.
 */
@Component
export struct AddNotePanel {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop selectedDeckId: number = 0;
  @Prop deckOptions: AddNoteDeckOption[] = [];
  @Prop selectedNotetypeId: number = 0;
  @Prop notetypeOptions: AddNoteNotetypeOption[] = [];
  @Watch('onFieldNamesChanged')
  @Prop fieldNames: string[] = [];
  onCancel: () => void = (): void => {
  };
  onSelectDeck: (deckId: number) => void = (_deckId: number): void => {
  };
  onSelectNotetype: (notetypeId: number) => void = (_notetypeId: number): void => {
  };
  onSave: (fields: string[], tags: string[], notetypeId: number) => Promise<number> =
    async (_fields: string[], _tags: string[], _notetypeId: number): Promise<number> => 0;
  onSaved: (noteId: number) => void = (_noteId: number): void => {
  };

  @State private fieldValues: string[] = [];
  @State private tags: string = '';
  @State private advancedExpanded: boolean = false;
  @State private localError: string = '';
  @State private showHelp: boolean = false;
  @State private helpTitle: Resource = $r('app.string.add_note_deck');
  @State private helpBody: Resource = $r('app.string.add_note_deck_help');

  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @State private savePressed: boolean = false;

  private openHelp(title: Resource, body: Resource): void {
    this.helpTitle = title;
    this.helpBody = body;
    this.showHelp = true;
  }

  aboutToAppear(): void {
    this.ensureFieldValues();
  }

  private onFieldNamesChanged(): void {
    this.fieldValues = this.fieldNames.map((_name: string): string => '');
  }

  private ensureFieldValues(): void {
    if (this.fieldValues.length !== this.fieldNames.length) {
      this.fieldValues = this.fieldNames.map((_name: string): string => '');
    }
  }

  private selectedDeckIndex(): number {
    const index = this.deckOptions.findIndex((deck: AddNoteDeckOption): boolean => deck.id === this.selectedDeckId);
    return index < 0 ? 0 : index;
  }

  // 官方 Select 文档：selected 只控制菜单初始高亮，按钮文本需由 value 提供，否则框内空白
  private selectedDeckName(): string {
    for (const deck of this.deckOptions) {
      if (deck.id === this.selectedDeckId) {
        return deck.name;
      }
    }
    return '';
  }

  private deckSelectOptions(): AddNoteSelectOption[] {
    const options: AddNoteSelectOption[] = [];
    for (const deck of this.deckOptions) {
      options.push({ value: deck.name });
    }
    return options;
  }

  private selectedNotetypeIndex(): number {
    const index = this.notetypeOptions.findIndex(
      (notetype: AddNoteNotetypeOption): boolean => notetype.id === this.selectedNotetypeId);
    return index < 0 ? 0 : index;
  }

  private selectedNotetypeName(): string {
    for (const notetype of this.notetypeOptions) {
      if (notetype.id === this.selectedNotetypeId) {
        return notetype.name;
      }
    }
    return '';
  }

  private notetypeSelectOptions(): AddNoteSelectOption[] {
    const options: AddNoteSelectOption[] = [];
    for (const notetype of this.notetypeOptions) {
      options.push({ value: notetype.name });
    }
    return options;
  }

  private updateField(index: number, value: string): void {
    const next = this.fieldValues.slice();
    next[index] = value;
    this.fieldValues = next;
  }

  private parseTags(): string[] {
    const seen: string[] = [];
    for (const tag of this.tags.split(/\s+/)) {
      const trimmed = tag.trim();
      if (trimmed !== '' && seen.indexOf(trimmed) < 0) {
        seen.push(trimmed);
      }
    }
    return seen;
  }

  private async submit(): Promise<void> {
    if (this.busy || this.selectedDeckId === 0 || this.selectedNotetypeId === 0) {
      return;
    }
    this.localError = '';
    try {
      const noteId = await this.onSave(this.fieldValues.slice(), this.parseTags(), this.selectedNotetypeId);
      this.fieldValues = this.fieldNames.map((_name: string): string => '');
      this.tags = '';
      this.onSaved(noteId);
    } catch (_error) {
      // The parent provides a localized message. Draft state intentionally remains unchanged.
    }
  }

  @Builder
  private labelWithHelp(label: Resource, help: Resource) {
    Row() {
      Text(label)
        .fontSize(AppDimens.FONT_BODY_S)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor(this.actionPrimaryColor)
        .enabled(!this.busy)
        .onClick((): void => {
          this.openHelp(label, help);
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

      Column({ space: AppDimens.SPACE_14 }) {
        // B12-Y2 2026-07-22：内容用 Scroll 包裹，fieldName 多或高级设置展开时可滚动，按钮固定底部
        // 避免 TextArea 越出面板边界、按钮 Row 被挤出面板外显示成"下面多出一个框"
        Scroll() {
          Column({ space: AppDimens.SPACE_14 }) {
            Text($r('app.string.add_note_title'))
              .fontSize(AppDimens.FONT_PANEL_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            this.labelWithHelp($r('app.string.add_note_deck'), $r('app.string.add_note_deck_help'))
            Select(this.deckSelectOptions())
              .selected(this.selectedDeckIndex())
              .value(this.selectedDeckName())
              .width('100%')
              .enabled(!this.busy && this.deckOptions.length > 0)
              .onSelect((index: number): void => {
                this.onSelectDeck(this.deckOptions[index].id);
              })

            this.labelWithHelp($r('app.string.add_note_notetype'), $r('app.string.add_note_notetype_help'))
            Select(this.notetypeSelectOptions())
              .selected(this.selectedNotetypeIndex())
              .value(this.selectedNotetypeName())
              .width('100%')
              .enabled(!this.busy && this.notetypeOptions.length > 0)
              .onSelect((index: number): void => {
                this.onSelectNotetype(this.notetypeOptions[index].id);
              })

            ForEach(this.fieldNames, (fieldName: string, index: number) => {
              Column({ space: AppDimens.SPACE_5 }) {
                Text(fieldName)
                  .fontSize(AppDimens.FONT_BODY_S)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                TextArea({ placeholder: fieldName, text: this.fieldValues[index] })
                  .width('100%')
                  // B12-Y2 2026-07-22：height 88 → 56，配合 Scroll 让字段多时可滚动不越界
                  .height(56)
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.surface_page'))
                  .borderRadius(AppDimens.RADIUS_PANEL)
                  .padding(AppDimens.SPACE_10)
                  .enabled(!this.busy)
                  .onChange((value: string): void => {
                    this.updateField(index, value);
                  })
              }
              .width('100%')
            }, (fieldName: string, index: number): string => `${index}-${fieldName}`)

            Button(this.advancedExpanded ? $r('app.string.add_note_advanced_hide') : $r('app.string.add_note_advanced'))
              .width('100%')
              .fontSize(AppDimens.FONT_BODY_S)
              .fontColor(this.actionPrimaryColor)
              .backgroundColor($r('app.color.surface_page'))
              .borderRadius(AppDimens.RADIUS_PANEL)
              .enabled(!this.busy)
              .onClick((): void => {
                this.advancedExpanded = !this.advancedExpanded;
              })

            if (this.advancedExpanded) {
              Column({ space: AppDimens.SPACE_5 }) {
                this.labelWithHelp($r('app.string.add_note_tags'), $r('app.string.add_note_tags_help'))
                TextInput({ placeholder: $r('app.string.add_note_tags_placeholder'), text: this.tags })
                  .width('100%')
                  .height(AppDimens.BUTTON_HEIGHT)
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_primary'))
                  .placeholderColor($r('app.color.text_tertiary'))
                  .backgroundColor($r('app.color.surface_page'))
                  .borderRadius(AppDimens.RADIUS_PANEL)
                  .padding({ left: AppDimens.SPACE_10, right: AppDimens.SPACE_10 })
                  .enabled(!this.busy)
                  .onChange((value: string): void => {
                    this.tags = value;
                  })
                Text($r('app.string.add_note_duplicate_rejected'))
                  .fontSize(AppDimens.FONT_BODY_S)
                  .fontColor($r('app.color.text_tertiary'))
                  .width('100%')
              }
              .width('100%')
            }

            if (this.errorMessage !== '' || this.localError !== '') {
              Text(this.errorMessage !== '' ? this.errorMessage : this.localError)
                .fontSize(AppDimens.FONT_BODY_S)
                .fontColor($r('app.color.error_text'))
                .width('100%')
                .maxLines(3)
            }
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)

        Row({ space: AppDimens.SPACE_10 }) {
          Button($r('app.string.add_note_cancel'))
            .height(AppDimens.BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(AppDimens.RADIUS_PILL)
            .enabled(!this.busy)
            .onClick((): void => {
              this.onCancel();
            })
          Button(this.busy ? $r('app.string.add_note_saving') : $r('app.string.add_note_save'))
            .height(AppDimens.BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.savePressed ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
            .borderRadius(AppDimens.RADIUS_PILL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .enabled(!this.busy && this.fieldNames.length > 0)
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) {
                this.savePressed = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.savePressed = false;
              }
            })
            .onClick((): void => {
              this.submit();
            })
        }
        .width('100%')
      }
      .width('88%')
      // B12-Y2 2026-07-22：maxHeight 88% + Scroll 让内容可滚动，按钮固定底部
      .constraintSize({ maxWidth: 520, maxHeight: '88%' })
      .padding(AppDimens.CARD_PADDING)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_CARD)
      .onClick(() => {
      })

      if (this.showHelp) {
        FieldHelpPanel({
          title: this.helpTitle,
          body: this.helpBody,
          onClose: (): void => {
            this.showHelp = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
