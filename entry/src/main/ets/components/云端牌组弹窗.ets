// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { 云端牌组目录项, 格式化云端牌组大小 } from '../model/云端牌组模型';
import { 取全屏转场时长, 取全屏转场曲线 } from '../utils/转场时长';

/** 云端牌组目录、选择、进度和结果的纯展示弹窗。 */
@Component
export struct 云端牌组弹窗 {
  @Prop isDark: boolean = false;
  @Prop loading: boolean = false;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  @Prop decks: 云端牌组目录项[] = [];
  @Prop selectedIds: string[] = [];
  @Prop successIds: string[] = [];
  @Prop failedIds: string[] = [];
  @Prop currentDeckName: string = '';
  @Prop currentStage: string = '';
  @Prop progressPercent: number = 0;
  @Prop completedCount: number = 0;
  @Prop taskCount: number = 0;
  onToggle: (deckId: string) => void = (deckId: string): void => {};
  onRetry: () => void = (): void => {};
  onDownload: () => void = (): void => {};
  onEnter: () => void = (): void => {};

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.选中背景) private 选中背景色: string = '#E8EEFC';

  private 已选中(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private 已成功(id: string): boolean {
    return this.successIds.indexOf(id) >= 0;
  }

  private 已失败(id: string): boolean {
    return this.failedIds.indexOf(id) >= 0;
  }

  @Builder
  private 牌组行(deck: 云端牌组目录项) {
    Row({ space: 应用尺寸.间距_12 }) {
      if (deck.accessType === 'public') {
        Toggle({ type: ToggleType.Checkbox, isOn: this.已选中(deck.id) })
          .selectedColor(this.动作主色)
          .enabled(!this.busy && !this.已成功(deck.id))
          .hitTestBehavior(HitTestMode.None)
      } else {
        Text($r('app.string.cloud_deck_locked_badge'))
          .fontSize(应用尺寸.字号_说明)
          .fontColor($r('app.color.text_tertiary'))
          .padding({ left: 应用尺寸.间距_8, right: 应用尺寸.间距_8,
            top: 应用尺寸.间距_4, bottom: 应用尺寸.间距_4 })
          .backgroundColor($r('app.color.surface_page'))
          .borderRadius(应用尺寸.圆角_胶囊)
      }

      Column({ space: 应用尺寸.间距_5 }) {
        Row({ space: 应用尺寸.间距_8 }) {
          Text(deck.name)
            .fontSize(应用尺寸.字号_正文)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.已成功(deck.id)) {
            Text($r('app.string.cloud_deck_status_success'))
              .fontSize(应用尺寸.字号_说明)
              .fontColor($r('app.color.status_ready'))
          } else if (this.已失败(deck.id)) {
            Text($r('app.string.cloud_deck_status_failed'))
              .fontSize(应用尺寸.字号_说明)
              .fontColor($r('app.color.error_text'))
          }
        }
        .width('100%')

        if (deck.description.length > 0) {
          Text(deck.description)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (deck.cardCount !== undefined) {
          Text(格式化云端牌组大小(deck.size).length > 0 ?
            $r('app.string.cloud_deck_meta_cards', deck.cardCount, deck.version,
              格式化云端牌组大小(deck.size)) :
            $r('app.string.cloud_deck_meta_cards_unknown_size', deck.cardCount, deck.version))
            .fontSize(应用尺寸.字号_说明)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        } else {
          Text(格式化云端牌组大小(deck.size).length > 0 ?
            $r('app.string.cloud_deck_meta', deck.version, 格式化云端牌组大小(deck.size)) :
            $r('app.string.cloud_deck_meta_unknown', deck.version))
            .fontSize(应用尺寸.字号_说明)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(应用尺寸.卡片内边距)
    .backgroundColor(this.已选中(deck.id) ? this.选中背景色 : $r('app.color.surface_page'))
    .border({
      width: 应用尺寸.卡片边框,
      color: this.已选中(deck.id) ? this.动作主色 : $r('app.color.border_subtle')
    })
    .borderRadius(应用尺寸.圆角_面板)
    .onClick((): void => {
      if (!this.busy && deck.accessType === 'public' && !this.已成功(deck.id)) {
        this.onToggle(deck.id);
      }
    })
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
        .transition(TransitionEffect.OPACITY.animation({
          curve: 取全屏转场曲线(), duration: 取全屏转场时长()
        }))

      Column({ space: 应用尺寸.间距_12 }) {
        Text($r('app.string.cloud_deck_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text($r('app.string.cloud_deck_onboarding_message'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        if (this.loading) {
          Column({ space: 应用尺寸.间距_8 }) {
            LoadingProgress()
              .width(应用尺寸.加载指示器尺寸)
              .height(应用尺寸.加载指示器尺寸)
              .color(this.动作主色)
            Text($r('app.string.cloud_deck_loading'))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(应用尺寸.间距_16)
        } else if (this.errorMessage.length > 0) {
          Column({ space: 应用尺寸.间距_12 }) {
            Text(this.errorMessage)
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.error_text'))
              .textAlign(TextAlign.Center)
            Button($r('app.string.cloud_deck_retry'))
              .type(ButtonType.Normal)
              .fontColor(this.动作主色)
              .backgroundColor($r('app.color.surface_page'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
              .borderRadius(应用尺寸.圆角_面板)
              .onClick((): void => { this.onRetry(); })
          }
          .width('100%')
          .padding(应用尺寸.间距_16)
        } else if (this.decks.length === 0) {
          Text($r('app.string.cloud_deck_empty'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(应用尺寸.间距_16)
        } else {
          Scroll() {
            Column({ space: 应用尺寸.间距_8 }) {
              ForEach(this.decks, (deck: 云端牌组目录项) => {
                this.牌组行(deck)
              }, (deck: 云端牌组目录项): string => deck.id)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }

        if (this.busy) {
          Column({ space: 应用尺寸.间距_8 }) {
            Text(this.currentStage === 'importing' ?
              $r('app.string.cloud_deck_progress_importing', this.currentDeckName) :
              $r('app.string.cloud_deck_progress_downloading', this.currentDeckName))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Progress({ value: this.progressPercent, total: 100, type: ProgressType.Linear })
              .width('100%')
              .color(this.动作主色)
            Text($r('app.string.cloud_deck_progress_count', this.completedCount, this.taskCount))
              .fontSize(应用尺寸.字号_说明)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
          }
          .width('100%')
        }

        Row({ space: 应用尺寸.间距_12 }) {
          Button($r('app.string.cloud_deck_download', this.selectedIds.length))
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.主色按钮背景)
            .borderRadius(应用尺寸.圆角_面板)
            .enabled(!this.busy && !this.loading && this.errorMessage.length === 0 && this.selectedIds.length > 0)
            .onClick((): void => { this.onDownload(); })

          if (this.successIds.length > 0) {
            Button($r('app.string.cloud_deck_enter'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.action_on_primary'))
              .backgroundColor(this.主色按钮背景)
              .borderRadius(应用尺寸.圆角_面板)
              .enabled(!this.busy)
              .onClick((): void => { this.onEnter(); })
          }
        }
        .width('100%')
      }
      .width('90%')
      .constraintSize({ maxWidth: 560, maxHeight: '88%' })
      .padding(应用尺寸.间距_16)
      .backgroundColor($r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_卡片)
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }),
        TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
