// SPDX-License-Identifier: AGPL-3.0-or-later

import { settingsPalette, SettingsPalette } from '../../utils/SettingsColors';

/**
 * 术语表分组：列出复习页常见操作术语（埋藏/暂停/删除/撤销/评分按钮等），
 * 每项点击 ⓘ 弹 FieldHelpPanel 显示详细说明。
 * 与 Anki 桌面端 More 菜单的语义保持一致；入口仅在设置页提供，
 * 复习页本身的按钮文字不内嵌长说明，避免打断学习节奏。
 *
 * 条目顺序按相关性分组：
 *   基础操作（埋藏/暂停/同级卡/删除/撤销/评分）
 *   → 评分相关（遗忘/难卡/毕业间隔）
 *   → 算法相关（FSRS 目标保持率/随机抖动）
 *
 * @Component
 */
@Component
export struct GlossaryGroup {
  @Prop isDark: boolean = false;
  @Prop opened: boolean = false;
  onToggle: () => void = (): void => {};
  // ⓘ 按钮上抛：由父组件 SettingsPanel 统一渲染 FieldHelpPanel 浮层，避免嵌在分组卡片内
  onOpenHelp: (title: Resource, body: Resource) => void = (_title: Resource, _body: Resource): void => {};

  /** 术语条目：labelResource 用于行内显示，helpTitleResource/helpBodyResource 用于弹层。 */
  private readonly entries: GlossaryEntry[] = [
    {
      labelKey: $r('app.string.glossary_bury_label'),
      helpTitleKey: $r('app.string.glossary_bury_label'),
      helpBodyKey: $r('app.string.glossary_bury_help')
    },
    {
      labelKey: $r('app.string.glossary_suspend_label'),
      helpTitleKey: $r('app.string.glossary_suspend_label'),
      helpBodyKey: $r('app.string.glossary_suspend_help')
    },
    {
      labelKey: $r('app.string.glossary_siblings_label'),
      helpTitleKey: $r('app.string.glossary_siblings_label'),
      helpBodyKey: $r('app.string.glossary_siblings_help')
    },
    {
      labelKey: $r('app.string.glossary_delete_label'),
      helpTitleKey: $r('app.string.glossary_delete_label'),
      helpBodyKey: $r('app.string.glossary_delete_help')
    },
    {
      labelKey: $r('app.string.glossary_undo_label'),
      helpTitleKey: $r('app.string.glossary_undo_label'),
      helpBodyKey: $r('app.string.glossary_undo_help')
    },
    {
      labelKey: $r('app.string.glossary_ratings_label'),
      helpTitleKey: $r('app.string.glossary_ratings_label'),
      helpBodyKey: $r('app.string.glossary_ratings_help')
    },
    {
      labelKey: $r('app.string.glossary_lapse_label'),
      helpTitleKey: $r('app.string.glossary_lapse_label'),
      helpBodyKey: $r('app.string.glossary_lapse_help')
    },
    {
      labelKey: $r('app.string.glossary_leech_label'),
      helpTitleKey: $r('app.string.glossary_leech_label'),
      helpBodyKey: $r('app.string.glossary_leech_help')
    },
    {
      labelKey: $r('app.string.glossary_graduating_interval_label'),
      helpTitleKey: $r('app.string.glossary_graduating_interval_label'),
      helpBodyKey: $r('app.string.glossary_graduating_interval_help')
    },
    {
      labelKey: $r('app.string.glossary_fsrs_retention_label'),
      helpTitleKey: $r('app.string.glossary_fsrs_retention_label'),
      helpBodyKey: $r('app.string.glossary_fsrs_retention_help')
    },
    {
      labelKey: $r('app.string.glossary_fuzz_label'),
      helpTitleKey: $r('app.string.glossary_fuzz_label'),
      helpBodyKey: $r('app.string.glossary_fuzz_help')
    },
    {
      labelKey: $r('app.string.glossary_shortcuts_label'),
      helpTitleKey: $r('app.string.glossary_shortcuts_label'),
      helpBodyKey: $r('app.string.glossary_shortcuts_help')
    }
  ];

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  @Builder
  private groupHeader(palette: SettingsPalette) {
    Row() {
      Text(this.localized($r('app.string.settings_glossary')))
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

  /** 单条术语行：名称 + ⓘ 按钮，点击 ⓘ 上抛 onOpenHelp 显示该术语的详细说明。 */
  @Builder
  private glossaryRow(palette: SettingsPalette, entry: GlossaryEntry) {
    Row() {
      Text(entry.labelKey)
        .fontSize(15)
        .fontColor(palette.textPrimary)
        .layoutWeight(1)
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(14)
        .fontColor(palette.textTertiary)
        .width(28)
        .height(28)
        .padding(0)
        .onClick(() => {
          this.onOpenHelp(entry.helpTitleKey, entry.helpBodyKey);
        })
    }
    .width('100%')
    .height(44)
  }

  build() {
    Column() {
      this.groupHeader(settingsPalette(this.isDark))

      if (this.opened) {
        Column() {
          ForEach(this.entries, (entry: GlossaryEntry) => {
            this.glossaryRow(settingsPalette(this.isDark), entry)
          }, (entry: GlossaryEntry): string => this.localized(entry.labelKey))
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

/** 术语条目数据结构：labelResource 用于行内显示，helpTitleResource/helpBodyResource 用于弹层。 */
interface GlossaryEntry {
  labelKey: Resource;
  helpTitleKey: Resource;
  helpBodyKey: Resource;
}
