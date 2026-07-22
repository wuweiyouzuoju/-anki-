// SPDX-License-Identifier: AGPL-3.0-or-later

import { DeckSummary, HomeSnapshot } from '../model/HomeModels';
import { AppDimens } from '../utils/AppDimens';
import { StartStudyButton } from './StartStudyButton';
import { COLOR_KEYS } from '../model/ColorTheme';

// 宽屏详情pane：选中卡组的名称、描述、三类计数、牌组选项入口与开始学习按钮。
// 牌组选项的渲染由父页面（Index.ets）在根 Stack 中挂载以实现全局磨砂覆盖；
// pane 仅在点击「牌组选项」时通过 onOpenDeckOptions 回调上抛 deckId。
//
// 数据来源：@Consume selectedDeckId + @Consume snapshot（@Provide 来自 Index）。
// 响应式方案：直接在 build() 中用 ForEach + if 从 @Consume snapshot 渲染。
// ArkUI V1 限制（前 5 次失败根因）：
// - @Prop 对 plain interface 不响应后续更新
// - @State 对 plain interface 赋值不触发 build()
// - @Consume 在 private 方法内部访问不建立响应式依赖
// - @Watch 回调中 @State 赋值不触发 build() 重新执行
// - build() 中模板字符串引用 @Consume 不可靠
// 最终方案：ForEach(this.snapshot.decks) + if (deck.id === this.selectedDeckId) 直接渲染
@Component
export struct DeckDetailPane {
  @Prop isDark: boolean = false;
  @Consume('selectedDeckId') selectedDeckId: string;
  @Consume('snapshot') snapshot: HomeSnapshot;
  @Prop deckOptionsLoading: boolean = false;
  @Prop deckOptionsError: string = '';
  onStart: () => void = (): void => {
  };
  onAddCard: () => void = (): void => {
  };
  onCreateSubdeck: () => void = (): void => {
  };
  onExportDeck: () => void = (): void => {
  };
  onOpenDeckOptions: () => void = (): void => {
  };

  @State private showMore: boolean = false;
  @StorageProp(COLOR_KEYS.countNew) private countNewColor: string = '#3974D9';
  @StorageProp(COLOR_KEYS.countLearning) private countLearningColor: string = '#B56A22';
  @StorageProp(COLOR_KEYS.countReview) private countReviewColor: string = '#7056C8';
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.primaryContainer) private primaryContainerColor: string = '#E8EEFC';
  // 添加卡片 + 更多 + 3 个子按钮共用一个 pressed 状态：0=无，1=添加卡片，2=更多，3=创建子牌组，4=牌组选项，5=导出
  @State private buttonPressed: number = 0;

  build() {
    Stack() {
      Column({ space: AppDimens.SPACE_16 }) {
        Text($r('app.string.selected_deck'))
          .fontSize(AppDimens.FONT_BODY_M)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        // 第 6 次修复：完全绕过 @State/@Watch/@Builder 间接响应链，
        // 直接在 build() 中用 ForEach + if 从 @Consume snapshot 渲染。
        // ForEach 建立 @Consume snapshot 响应式依赖，
        // if (deck.id === this.selectedDeckId) 建立 @Consume selectedDeckId 依赖，
        // 直接用 deck.totalCards 等渲染，不经过 @State 中转。
        ForEach(this.snapshot.decks, (deck: DeckSummary) => {
          if (deck.id === this.selectedDeckId) {
            Text(deck.displayName !== '' ? deck.displayName : deck.name)
              .fontSize(AppDimens.FONT_DECK_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Text(deck.description)
              .fontSize(AppDimens.FONT_BODY)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Column({ space: AppDimens.SPACE_15 }) {
              Row() {
                Text($r('app.string.deck_total_cards'))
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.totalCards.toString())
                  .fontSize(AppDimens.FONT_CARD_TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
              Row() {
                Text($r('app.string.new_cards'))
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.newCount.toString())
                  .fontSize(AppDimens.FONT_CARD_TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.countNewColor)
              }
              .width('100%')
              Row() {
                Text($r('app.string.learning_cards'))
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.learningCount.toString())
                  .fontSize(AppDimens.FONT_CARD_TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.countLearningColor)
              }
              .width('100%')
              Row() {
                Text($r('app.string.review_cards'))
                  .fontSize(AppDimens.FONT_BODY)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.reviewCount.toString())
                  .fontSize(AppDimens.FONT_CARD_TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.countReviewColor)
              }
              .width('100%')
            }
            .width('100%')
            .padding(AppDimens.SPACE_17)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_METRIC)

            Button($r('app.string.deck_add_card'))
              .width('100%')
              .height(AppDimens.BUTTON_HEIGHT)
              .fontSize(AppDimens.FONT_BUTTON)
              .fontColor(this.actionPrimaryColor)
              .backgroundColor(this.buttonPressed === 1 ? this.primaryContainerColor : $r('app.color.surface_card'))
              .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
              .borderRadius(AppDimens.RADIUS_PILL)
              .animation({ duration: 80, curve: Curve.EaseOut })
              .onTouch((event: TouchEvent): void => {
                if (event.type === TouchType.Down) { this.buttonPressed = 1; }
                else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.buttonPressed = 0; }
              })
              .onClick(() => {
                this.onAddCard();
              })

            Row() {
              Text('▼')
                .fontSize(AppDimens.FONT_BODY)
                .fontColor($r('app.color.text_secondary'))
                .rotate({ angle: this.showMore ? 0 : -90 })
                .animation({ duration: 150, curve: Curve.EaseOut })
                .width(AppDimens.SPACE_16)
                .textAlign(TextAlign.Center)
              Text($r('app.string.deck_more'))
                .fontSize(AppDimens.FONT_BUTTON)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Blank()
                .width(AppDimens.SPACE_16)
            }
            .width('100%')
            .height(AppDimens.BUTTON_HEIGHT)
            .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
            .backgroundColor(this.buttonPressed === 2 ? this.primaryContainerColor : $r('app.color.surface_card'))
            .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
            .borderRadius(AppDimens.RADIUS_PILL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.buttonPressed = 2; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.buttonPressed = 0; }
            })
            .onClick(() => {
              this.showMore = !this.showMore;
            })

            if (this.showMore) {
              Column({ space: AppDimens.SPACE_8 }) {
                Button($r('app.string.deck_create_subdeck'))
                  .width('100%')
                  .height(AppDimens.BUTTON_HEIGHT)
                  .fontSize(AppDimens.FONT_BUTTON)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.buttonPressed === 3 ? this.primaryContainerColor : $r('app.color.surface_card'))
                  .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                  .borderRadius(AppDimens.RADIUS_PILL)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.buttonPressed = 3; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.buttonPressed = 0; }
                  })
                  .onClick((): void => {
                    this.showMore = false;
                    this.onCreateSubdeck();
                  })
                Button(this.deckOptionsLoading ? $r('app.string.deck_options_loading') : $r('app.string.deck_options_title'))
                  .width('100%')
                  .height(AppDimens.BUTTON_HEIGHT)
                  .fontSize(AppDimens.FONT_BUTTON)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.buttonPressed === 4 ? this.primaryContainerColor : $r('app.color.surface_card'))
                  .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                  .borderRadius(AppDimens.RADIUS_PILL)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.buttonPressed = 4; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.buttonPressed = 0; }
                  })
                  .enabled(!this.deckOptionsLoading)
                  .onClick((): void => {
                    this.showMore = false;
                    this.onOpenDeckOptions();
                  })
                Button($r('app.string.deck_export_this'))
                  .width('100%')
                  .height(AppDimens.BUTTON_HEIGHT)
                  .fontSize(AppDimens.FONT_BUTTON)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.buttonPressed === 5 ? this.primaryContainerColor : $r('app.color.surface_card'))
                  .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                  .borderRadius(AppDimens.RADIUS_PILL)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.buttonPressed = 5; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.buttonPressed = 0; }
                  })
                  .onClick((): void => {
                    this.showMore = false;
                    this.onExportDeck();
                  })
              }
              .width('100%')
            }

            if (this.deckOptionsError !== '') {
              Text(this.deckOptionsError)
                .fontSize(AppDimens.FONT_BODY_S)
                .fontColor($r('app.color.error_text'))
                .width('100%')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            Blank()
            StartStudyButton({
              pendingCount: deck.newCount + deck.learningCount + deck.reviewCount,
              onStart: (): void => {
                this.onStart();
              }
            })
          }
        }, (deck: DeckSummary) => deck.id)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .height('100%')
      .padding({
        left: AppDimens.CARD_PADDING,
        right: AppDimens.CARD_PADDING,
        top: AppDimens.CARD_PADDING,
        bottom: AppDimens.PAGE_PADDING_H
      })
      .backgroundColor($r('app.color.surface_card'))
      .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
      .borderRadius(AppDimens.RADIUS_CARD)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppDimens.PAGE_PADDING_H,
      right: AppDimens.PAGE_PADDING_H,
      top: AppDimens.SPACE_4,
      bottom: AppDimens.PAGE_PADDING_H
    })
  }
}
