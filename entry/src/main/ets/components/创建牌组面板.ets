// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 组合牌组路径, 规范化牌组路径 } from '../model/牌组层级';
import type { 牌组汇总 } from '../model/主页模型';
import { 颜色键 } from '../model/颜色主题';
import { 字段帮助面板 } from './字段帮助面板';

@Component
export struct 创建牌组面板 {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop parentOptions: 牌组汇总[] = [];
  @Prop initialParentId: string = '';
  onCancel: () => void = (): void => {
  };
  onConfirm: (fullName: string) => void = (fullName: string): void => {
  };

  @State private deckName: string = '';
  @State private parentId: string = '';

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下: string = '#1E4FB8';
  @StorageProp(颜色键.选中背景) private 选中背景色: string = '#E8EEFC';
  @State private 已按下确认: boolean = false;
  @State private 显示帮助: boolean = false;
  @State private 帮助标题: Resource = $r('app.string.create_deck_help_title');
  @State private 帮助正文: Resource = $r('app.string.create_deck_help_body');

  aboutToAppear(): void {
    this.parentId = this.initialParentId;
  }

  private 按ID查找父牌组(id: string): 牌组汇总 | null {
    for (const 父牌组 of this.parentOptions) {
      if (父牌组.id === id) {
        return 父牌组;
      }
    }
    return null;
  }

  private 取本地化文本(resource: Resource): string {
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(resource.id);
  }

  private 预览父路径(): string {
    const 父牌组: 牌组汇总 | null = this.按ID查找父牌组(this.parentId);
    return 父牌组 === null ? '' : 父牌组.fullName;
  }

  private 预览叶节点(): string {
    if (this.deckName.trim().length === 0) {
      return '';
    }
    const 规范化结果: string | null = 规范化牌组路径(this.deckName);
    return 规范化结果 === null ? '' : 规范化结果;
  }

  private canSubmit(): boolean {
    const 父牌组: 牌组汇总 | null = this.按ID查找父牌组(this.parentId);
    const 完整路径: string | null = 组合牌组路径(父牌组 === null ? '' : 父牌组.fullName, this.deckName);
    return !this.busy && this.deckName.trim().length > 0 && 完整路径 !== null;
  }

  private 提交(): void {
    if (this.canSubmit()) {
      const 父牌组: 牌组汇总 | null = this.按ID查找父牌组(this.parentId);
      const 完整路径: string | null = 组合牌组路径(父牌组 === null ? '' : 父牌组.fullName, this.deckName);
      if (完整路径 !== null) {
        this.onConfirm(完整路径);
      }
    }
  }

  @Builder
  private 父牌组候选行(id: string, label: string, depth: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(应用尺寸.字号_正文)
          .fontColor(this.parentId === id ? this.动作主色 : $r('app.color.text_primary'))
          .fontWeight(this.parentId === id ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: 应用尺寸.间距_14,
        right: 应用尺寸.间距_14,
        top: 应用尺寸.间距_12,
        bottom: 应用尺寸.间距_12
      })
      .backgroundColor(this.parentId === id ?
        this.选中背景色 : $r('app.color.surface_page'))
      .border({
        width: 应用尺寸.卡片边框,
        color: this.parentId === id ? this.动作主色 : Color.Transparent
      })
      .borderRadius(应用尺寸.圆角_面板)
      .onClick(() => {
        if (!this.busy) {
          this.parentId = id;
        }
      })
    }
    .width('100%')
    .padding({ left: depth * 应用尺寸.父牌组候选项缩进 })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDark ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          if (!this.busy) {
            this.onCancel();
          }
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: 应用尺寸.间距_16 }) {
        Row() {
          Text($r('app.string.create_deck_title'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button($r('app.string.field_help_button'))
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor(this.动作主色)
            .fontSize(应用尺寸.字号_面板标题)
            .enabled(!this.busy)
            .onClick((): void => {
              this.显示帮助 = true;
            })
        }
        .width('100%')

        TextInput({ placeholder: $r('app.string.deck_name_placeholder'), text: this.deckName })
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.surface_card'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
          .borderRadius(应用尺寸.圆角_面板)
          .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
          .enabled(!this.busy)
          .onChange((value: string) => {
            this.deckName = value;
          })
          .onSubmit((): void => {
            this.提交();
          })

        if (this.预览父路径() !== '' && this.预览叶节点() !== '') {
          Text($r('app.string.create_deck_preview_child', this.预览父路径(), this.预览叶节点()))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(this.动作主色)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.预览父路径() !== '') {
          Text($r('app.string.create_deck_preview_child_pending', this.预览父路径()))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(this.动作主色)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.预览叶节点() !== '') {
          Text($r('app.string.create_deck_preview_top', this.预览叶节点()))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor(this.动作主色)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Scroll() {
          Column({ space: 应用尺寸.间距_5 }) {
            this.父牌组候选行('', this.取本地化文本($r('app.string.top_level_deck')), 0)
            ForEach(this.parentOptions, (父牌组: 牌组汇总) => {
              this.父牌组候选行(父牌组.id, 父牌组.name, 父牌组.depth)
            }, (父牌组: 牌组汇总): string => 父牌组.id)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        if (this.errorMessage !== '') {
          Text(this.errorMessage)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row({ space: 应用尺寸.间距_10 }) {
          Button($r('app.string.create_deck_cancel'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.busy)
            .onClick(() => {
              this.onCancel();
            })

          Button(this.busy ? $r('app.string.create_deck_creating') : $r('app.string.create_deck_confirm'))
            .height(应用尺寸.按钮高度)
            .layoutWeight(1)
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.已按下确认 ? this.主色按钮按下 : this.主色按钮背景)
            .borderRadius(应用尺寸.圆角_胶囊)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .opacity(this.canSubmit() ? 1 : 0.5)
            .enabled(this.canSubmit())
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) {
                this.已按下确认 = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.已按下确认 = false;
              }
            })
            .onClick(() => {
              this.提交();
            })
        }
        .width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, minHeight: '65%' })
      .padding(应用尺寸.面板内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .onClick(() => {
      })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 24 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: Curve.EaseOut, duration: 240 }),
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 16 }))
          .animation({ curve: Curve.EaseIn, duration: 180 })
      ))

      if (this.显示帮助) {
        字段帮助面板({
          标题: this.帮助标题,
          正文: this.帮助正文,
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
