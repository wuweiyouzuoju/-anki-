// SPDX-License-Identifier: AGPL-3.0-or-later

import { 牌组列表项 } from '../牌组列表项';
import { 统一加载态 } from '../common/统一加载态';
import { 统一空态 } from '../common/统一空态';
import { 统一错误态 } from '../common/统一错误态';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 牌组列表数据源, 牌组汇总, 牌组色调, 主页加载状态 } from '../../model/主页模型';

@Component
export struct 主页牌组列表 {
  牌组数据源: 牌组列表数据源 = new 牌组列表数据源([]);
  牌组列表滚动器: Scroller = new Scroller();
  展开的牌组ID集合: Set<string> = new Set<string>();

  @Prop 选中的牌组ID: string = '';
  @Prop 排序模式中: boolean = false;
  @Prop 加载状态: 主页加载状态 = 'loading';
  @Prop @Watch('同步刷新指示器') 刷新中: boolean = false;
  @Prop 动作主色: string = '#2F5FD0';
  @Prop 主色按钮背景色: string = '#2F5FD0';

  @State private 刷新指示器开关: boolean = false;

  onMove: (from: number, to: number) => void = (from: number, to: number): void => {};
  onItemSelect: (deckId: string) => void = (deckId: string): void => {};
  onItemToggle: (deckId: string) => void = (deckId: string): void => {};
  onItemToneChange: (deckId: string, tone: 牌组色调) => void
    = (deckId: string, tone: 牌组色调): void => {};
  onItemCustomize: (deckId: string) => void = (deckId: string): void => {};
  onItemEnterReorder: (deckId: string) => void = (deckId: string): void => {};
  onItemDelete: (deckId: string) => void = (deckId: string): void => {};
  onItemHide: (deckId: string) => void = (deckId: string): void => {};
  onItemDoubleTap: (deckId: string) => void = (deckId: string): void => {};
  onExitReorder: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onRetry: () => void = (): void => {};

  aboutToAppear(): void {
    this.刷新指示器开关 = this.刷新中;
  }

  同步刷新指示器(): void {
    this.刷新指示器开关 = this.刷新中;
  }

  build() {
    Column({ space: 应用尺寸.间距_10 }) {
      Row({ space: 应用尺寸.间距_8 }) {
        Text($r('app.string.deck_section_title'))
          .fontSize(应用尺寸.字号_分区标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        if (this.排序模式中) {
          Button($r('app.string.deck_reorder_done'))
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.surface_page'))
            .backgroundColor(this.主色按钮背景色)
            .borderRadius(应用尺寸.圆角_胶囊)
            .onClick(() => {
              this.onExitReorder();
            })
        }
      }
      .width('100%')

      if (this.排序模式中) {
        Text($r('app.string.deck_reorder_hint'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .maxLines(2)
      }

      Refresh({ refreshing: $$this.刷新指示器开关 }) {
        List({ scroller: this.牌组列表滚动器, space: 应用尺寸.列表间距 }) {
          LazyForEach(this.牌组数据源, (deck: 牌组汇总) => {
            ListItem() {
              牌组列表项({
                deck: deck,
                selected: deck.id === this.选中的牌组ID,
                reorderMode: this.排序模式中,
                onSelect: (deckId: string): void => {
                  this.onItemSelect(deckId);
                },
                expanded: this.展开的牌组ID集合.has(deck.id),
                onToggle: (deckId: string): void => {
                  this.onItemToggle(deckId);
                },
                onToneChange: (deckId: string, tone: 牌组色调): void => {
                  this.onItemToneChange(deckId, tone);
                },
                onCustomizeDeck: (deckId: string): void => {
                  this.onItemCustomize(deckId);
                },
                onEnterReorder: (deckId: string): void => {
                  this.onItemEnterReorder(deckId);
                },
                onDeleteDeck: (deckId: string): void => {
                  this.onItemDelete(deckId);
                },
                onHideDeck: (deckId: string): void => {
                  this.onItemHide(deckId);
                },
                onDoubleTap: (deckId: string): void => {
                  this.onItemDoubleTap(deckId);
                }
              })
            }
          }, (deck: 牌组汇总) => `${deck.id}_${deck.tone}_${deck.displayName}_${deck.newCount}_${deck.learningCount}_${deck.reviewCount}_${deck.totalCards}_${deck.backgroundImage}_${this.排序模式中 ? 1 : 0}`)
          .onMove((from: number, to: number): void => {
            this.onMove(from, to);
          })

          if (this.加载状态 === 'loading') {
            ListItem() {
              Row() {
                统一加载态({
                  尺寸: 应用尺寸.加载指示器尺寸
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 应用尺寸.空态垂直内边距, bottom: 应用尺寸.空态垂直内边距 })
            }
          }
          if (this.加载状态 === 'error') {
            ListItem() {
              Row() {
                统一错误态({
                  文案: $r('app.string.home_load_error'),
                  重试文案: $r('app.string.home_retry'),
                  onRetry: (): void => {
                    this.onRetry();
                  }
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 应用尺寸.空态垂直内边距, bottom: 应用尺寸.空态垂直内边距 })
            }
          }
          if (this.加载状态 === 'empty') {
            ListItem() {
              Row() {
                统一空态({
                  标题: $r('app.string.empty_decks_title'),
                  副标题: $r('app.string.empty_decks_hint')
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 应用尺寸.空态垂直内边距, bottom: 应用尺寸.空态垂直内边距 })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
      .onRefreshing(() => {
        this.onRefresh();
      })
      .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
  }
}
