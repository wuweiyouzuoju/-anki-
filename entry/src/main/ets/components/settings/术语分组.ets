// SPDX-License-Identifier: AGPL-3.0-or-later

import { 设置面板色板_取, 设置面板色板 } from '../../utils/设置面板配色';

@Component
export struct 术语分组 {
  @Prop 是否深色: boolean = false;
  @Prop 是否展开: boolean = false;
  切换展开回调: () => void = (): void => {};
  打开说明回调: (标题: Resource, 正文: Resource) => void = (_标题: Resource, _正文: Resource): void => {};
  @StorageProp('themeMode') private 主题模式监听: string = 'system';

  private readonly 条目列表: 术语条目[] = [
    {
      标签资源: $r('app.string.glossary_bury_label'),
      帮助标题资源: $r('app.string.glossary_bury_label'),
      帮助正文资源: $r('app.string.glossary_bury_help')
    },
    {
      标签资源: $r('app.string.glossary_suspend_label'),
      帮助标题资源: $r('app.string.glossary_suspend_label'),
      帮助正文资源: $r('app.string.glossary_suspend_help')
    },
    {
      标签资源: $r('app.string.glossary_siblings_label'),
      帮助标题资源: $r('app.string.glossary_siblings_label'),
      帮助正文资源: $r('app.string.glossary_siblings_help')
    },
    {
      标签资源: $r('app.string.glossary_delete_label'),
      帮助标题资源: $r('app.string.glossary_delete_label'),
      帮助正文资源: $r('app.string.glossary_delete_help')
    },
    {
      标签资源: $r('app.string.glossary_undo_label'),
      帮助标题资源: $r('app.string.glossary_undo_label'),
      帮助正文资源: $r('app.string.glossary_undo_help')
    },
    {
      标签资源: $r('app.string.glossary_ratings_label'),
      帮助标题资源: $r('app.string.glossary_ratings_label'),
      帮助正文资源: $r('app.string.glossary_ratings_help')
    },
    {
      标签资源: $r('app.string.glossary_lapse_label'),
      帮助标题资源: $r('app.string.glossary_lapse_label'),
      帮助正文资源: $r('app.string.glossary_lapse_help')
    },
    {
      标签资源: $r('app.string.glossary_leech_label'),
      帮助标题资源: $r('app.string.glossary_leech_label'),
      帮助正文资源: $r('app.string.glossary_leech_help')
    },
    {
      标签资源: $r('app.string.glossary_graduating_interval_label'),
      帮助标题资源: $r('app.string.glossary_graduating_interval_label'),
      帮助正文资源: $r('app.string.glossary_graduating_interval_help')
    },
    {
      标签资源: $r('app.string.glossary_fsrs_retention_label'),
      帮助标题资源: $r('app.string.glossary_fsrs_retention_label'),
      帮助正文资源: $r('app.string.glossary_fsrs_retention_help')
    },
    {
      标签资源: $r('app.string.glossary_fuzz_label'),
      帮助标题资源: $r('app.string.glossary_fuzz_label'),
      帮助正文资源: $r('app.string.glossary_fuzz_help')
    },
    {
      标签资源: $r('app.string.glossary_shortcuts_label'),
      帮助标题资源: $r('app.string.glossary_shortcuts_label'),
      帮助正文资源: $r('app.string.glossary_shortcuts_help')
    }
  ];

  private 取本地化文本(资源: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(资源.id);
  }

  @Builder
  private 分组头部() {
    Row() {
      Text(this.取本地化文本($r('app.string.settings_glossary')))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(设置面板色板_取(this.是否深色).次文字)
      Blank()
      Text('▼')
        .fontSize(11)
        .fontColor(设置面板色板_取(this.是否深色).弱化文字)
        .rotate({ angle: this.是否展开 ? 0 : -90 })
    }
    .width('100%')
    .height(40)
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.切换展开回调(); });
    })
  }

  @Builder
  private 术语行(色板: 设置面板色板, 条目: 术语条目) {
    Row() {
      Text(条目.标签资源)
        .fontSize(15)
        .fontColor(色板.主文字)
        .layoutWeight(1)
      Button($r('app.string.field_help_button'))
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontSize(14)
        .fontColor(色板.三级文字)
        .width(28)
        .height(28)
        .padding(0)
        .onClick(() => {
          this.打开说明回调(条目.帮助标题资源, 条目.帮助正文资源);
        })
    }
    .width('100%')
    .height(44)
  }

  build() {
    Column() {
      this.分组头部()

      if (this.是否展开) {
        Column() {
          ForEach(this.条目列表, (条目: 术语条目) => {
            this.术语行(设置面板色板_取(this.是否深色), 条目)
          }, (条目: 术语条目): string => this.取本地化文本(条目.标签资源))
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(设置面板色板_取(this.是否深色).背景)
    .borderRadius(12)
  }
}

interface 术语条目 {
  标签资源: Resource;
  帮助标题资源: Resource;
  帮助正文资源: Resource;
}
