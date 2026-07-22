// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';
import { composeDeckPath, normalizeDeckPath } from '../model/DeckHierarchy';
import type { DeckSummary } from '../model/HomeModels';
import { COLOR_KEYS } from '../model/ColorTheme';

/**
 * 新建牌组弹层（纯 UI 积木）。
 * 不接触后端：名称经 onConfirm 上抛，忙碌/错误态由父级通过 Prop 下发。
 */
@Component
export struct CreateDeckPanel {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop parentOptions: DeckSummary[] = [];
  @Prop initialParentId: string = '';
  onCancel: () => void = (): void => {
  };
  onConfirm: (fullName: string) => void = (fullName: string): void => {
  };

  @State private deckName: string = '';
  @State private parentId: string = '';

  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @StorageProp(COLOR_KEYS.surfaceSelected) private surfaceSelectedColor: string = '#E8EEFC';
  @State private confirmPressed: boolean = false;

  aboutToAppear(): void {
    this.parentId = this.initialParentId;
  }

  private parentForId(id: string): DeckSummary | null {
    for (const parent of this.parentOptions) {
      if (parent.id === id) {
        return parent;
      }
    }
    return null;
  }

  private localized(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource.id);
  }

  // 预览取词：父路径与规范化叶名分态展示，一眼可见新牌组归属
  private previewParentPath(): string {
    const parent: DeckSummary | null = this.parentForId(this.parentId);
    return parent === null ? '' : parent.fullName;
  }

  private previewLeaf(): string {
    if (this.deckName.trim().length === 0) {
      return '';
    }
    const normalized: string | null = normalizeDeckPath(this.deckName);
    return normalized === null ? '' : normalized;
  }

  private canSubmit(): boolean {
    const parent: DeckSummary | null = this.parentForId(this.parentId);
    const fullName: string | null = composeDeckPath(parent === null ? '' : parent.fullName, this.deckName);
    return !this.busy && this.deckName.trim().length > 0 && fullName !== null;
  }

  private submit(): void {
    if (this.canSubmit()) {
      const parent: DeckSummary | null = this.parentForId(this.parentId);
      const fullName: string | null = composeDeckPath(parent === null ? '' : parent.fullName, this.deckName);
      if (fullName !== null) {
        this.onConfirm(fullName);
      }
    }
  }

  // 父牌组候选行：外层 padding 实现整张选择卡向右缩进（框开头短一截），内层承载边框/背景/文字
  // 字号 12→14、字重 Normal→Medium / Medium→Bold、padding 加大，整体更「粗」
  @Builder
  private parentOptionRow(id: string, label: string, depth: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(AppDimens.FONT_BODY)
          .fontColor(this.parentId === id ? this.actionPrimaryColor : $r('app.color.text_primary'))
          .fontWeight(this.parentId === id ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: AppDimens.SPACE_14,
        right: AppDimens.SPACE_14,
        top: AppDimens.SPACE_12,
        bottom: AppDimens.SPACE_12
      })
      .backgroundColor(this.parentId === id ?
        this.surfaceSelectedColor : $r('app.color.surface_page'))
      .border({
        width: AppDimens.CARD_BORDER,
        color: this.parentId === id ? this.actionPrimaryColor : Color.Transparent
      })
      .borderRadius(AppDimens.RADIUS_PANEL)
      .onClick(() => {
        if (!this.busy) {
          this.parentId = id;
        }
      })
    }
    .width('100%')
    .padding({ left: depth * AppDimens.PARENT_OPTION_INDENT })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDark ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        // 磨砂玻璃质感：模糊下层内容避免叠字，材质着色跟随应用内主题（思路参考：华为开发者文档 backgroundBlurStyle）
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        // 遮罩扩展进安全区，否则状态栏/导航条区域露出下层背景
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          if (!this.busy) {
            this.onCancel();
          }
        })
        // 过渡仅动 opacity/translate/scale 合成属性，不触发布局（思路参考：华为官方 TransitionEffect 示例）
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: AppDimens.SPACE_16 }) {
        Text($r('app.string.create_deck_title'))
          .fontSize(AppDimens.FONT_PANEL_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        // 牌组名称输入框上移到标题下方（先填名称 → 再选父牌组 → 看预览 → 提交）
        TextInput({ placeholder: $r('app.string.deck_name_placeholder'), text: this.deckName })
          .width('100%')
          .height(AppDimens.BUTTON_HEIGHT)
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.surface_page'))
          .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_input') })
          .borderRadius(AppDimens.RADIUS_PANEL)
          .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
          .enabled(!this.busy)
          .onChange((value: string) => {
            this.deckName = value;
          })
          .onSubmit((): void => {
            this.submit();
          })

        if (this.previewParentPath() !== '' && this.previewLeaf() !== '') {
          Text($r('app.string.create_deck_preview_child', this.previewParentPath(), this.previewLeaf()))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor(this.actionPrimaryColor)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.previewParentPath() !== '') {
          Text($r('app.string.create_deck_preview_child_pending', this.previewParentPath()))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor(this.actionPrimaryColor)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (this.previewLeaf() !== '') {
          Text($r('app.string.create_deck_preview_top', this.previewLeaf()))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor(this.actionPrimaryColor)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // 父牌组列表：layoutWeight(1) 吃掉卡片撑高后的剩余空间，按钮自然贴底，无底部空白
        Scroll() {
          Column({ space: AppDimens.SPACE_5 }) {
            this.parentOptionRow('', this.localized($r('app.string.top_level_deck')), 0)
            ForEach(this.parentOptions, (parent: DeckSummary) => {
              this.parentOptionRow(parent.id, parent.name, parent.depth)
            }, (parent: DeckSummary): string => parent.id)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        if (this.errorMessage !== '') {
          Text(this.errorMessage)
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row({ space: AppDimens.SPACE_10 }) {
          Button($r('app.string.create_deck_cancel'))
            .height(AppDimens.BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(AppDimens.RADIUS_PILL)
            .enabled(!this.busy)
            .onClick(() => {
              this.onCancel();
            })

          Button(this.busy ? $r('app.string.create_deck_creating') : $r('app.string.create_deck_confirm'))
            .height(AppDimens.BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.confirmPressed ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
            .borderRadius(AppDimens.RADIUS_PILL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .opacity(this.canSubmit() ? 1 : 0.5)
            .enabled(this.canSubmit())
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) {
                this.confirmPressed = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.confirmPressed = false;
              }
            })
            .onClick(() => {
              this.submit();
            })
        }
        .width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, minHeight: '65%' })
      .padding(AppDimens.PANEL_PADDING)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_CARD)
      .onClick(() => {
        // 阻断点击穿透到遮罩
      })
      // 居中浮卡：缩放+淡入过渡（思路参考：华为官方 TransitionEffect 示例）
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 24 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: Curve.EaseOut, duration: 240 }),
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 16 }))
          .animation({ curve: Curve.EaseIn, duration: 180 })
      ))
    }
    .width('100%')
    .height('100%')
  }
}
