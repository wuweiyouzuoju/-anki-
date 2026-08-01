// SPDX-License-Identifier: AGPL-3.0-or-later

import { 牌组汇总, 主页快照 } from '../model/主页模型';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 开始学习按钮 } from './开始学习按钮';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 牌组详情面板 {
  @Prop 是否深色: boolean = false;
  @Consume('selectedDeckId') 选中牌组Id: string;
  @Consume('snapshot') 主页快照数据: 主页快照;
  @Prop 牌组选项加载中: boolean = false;
  @Prop 牌组选项错误: string = '';
  开始学习: () => void = (): void => {
  };
  添加卡片: () => void = (): void => {
  };
  创建子牌组: () => void = (): void => {
  };
  导出牌组: () => void = (): void => {
  };
  打开牌组选项: () => void = (): void => {
  };

  @State private 显示更多: boolean = false;
  @StorageProp(颜色键.新卡计数色) private 新卡计数色: string = '#3974D9';
  @StorageProp(颜色键.学习中计数色) private 学习中计数色: string = '#B56A22';
  @StorageProp(颜色键.复习中计数色) private 复习中计数色: string = '#7056C8';
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.主色容器) private 主色容器色: string = '#E8EEFC';
  @State private 按下按钮编号: number = 0;

  build() {
    Stack() {
      Scroll() {
      Column({ space: 应用尺寸.间距_16 }) {
        Text($r('app.string.selected_deck'))
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        ForEach(this.主页快照数据.decks, (deck: 牌组汇总) => {
          if (deck.id === this.选中牌组Id) {
            Text(deck.displayName !== '' ? deck.displayName : deck.name)
              .fontSize(应用尺寸.字号_牌组标题)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Text(deck.description)
              .fontSize(应用尺寸.字号_正文)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Column({ space: 应用尺寸.间距_15 }) {
              Row() {
                Text($r('app.string.deck_total_cards'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.totalCards.toString())
                  .fontSize(应用尺寸.字号_卡片标题)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
              Row() {
                Text($r('app.string.new_cards'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.newCount.toString())
                  .fontSize(应用尺寸.字号_卡片标题)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.新卡计数色)
              }
              .width('100%')
              Row() {
                Text($r('app.string.learning_cards'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.learningCount.toString())
                  .fontSize(应用尺寸.字号_卡片标题)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.学习中计数色)
              }
              .width('100%')
              Row() {
                Text($r('app.string.review_cards'))
                  .fontSize(应用尺寸.字号_正文)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(deck.reviewCount.toString())
                  .fontSize(应用尺寸.字号_卡片标题)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.复习中计数色)
              }
              .width('100%')
            }
            .width('100%')
            .padding(应用尺寸.间距_17)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_指标卡)

            Button($r('app.string.deck_add_card'))
              .width('100%')
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_按钮)
              .fontColor(this.动作主色)
              .backgroundColor(this.按下按钮编号 === 1 ? this.主色容器色 : $r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
              .borderRadius(应用尺寸.圆角_胶囊)
              .animation({ duration: 80, curve: Curve.EaseOut })
              .onTouch((event: TouchEvent): void => {
                if (event.type === TouchType.Down) { this.按下按钮编号 = 1; }
                else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下按钮编号 = 0; }
              })
              .onClick(() => {
                this.添加卡片();
              })

            Row() {
              Text('▼')
                .fontSize(应用尺寸.字号_正文)
                .fontColor($r('app.color.text_secondary'))
                .rotate({ angle: this.显示更多 ? 0 : -90 })
                .animation({ duration: 150, curve: Curve.EaseOut })
                .width(应用尺寸.间距_16)
                .textAlign(TextAlign.Center)
              Text($r('app.string.deck_more'))
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Blank()
                .width(应用尺寸.间距_16)
            }
            .width('100%')
            .height(应用尺寸.按钮高度)
            .padding({ left: 应用尺寸.卡片内边距, right: 应用尺寸.卡片内边距 })
            .backgroundColor(this.按下按钮编号 === 2 ? this.主色容器色 : $r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_胶囊)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) { this.按下按钮编号 = 2; }
              else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下按钮编号 = 0; }
            })
            .onClick(() => {
              this.显示更多 = !this.显示更多;
            })

            if (this.显示更多) {
              Column({ space: 应用尺寸.间距_8 }) {
                Button($r('app.string.deck_create_subdeck'))
                  .width('100%')
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.按下按钮编号 === 3 ? this.主色容器色 : $r('app.color.surface_card'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.按下按钮编号 = 3; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下按钮编号 = 0; }
                  })
                  .onClick((): void => {
                    this.显示更多 = false;
                    this.创建子牌组();
                  })
                Button(this.牌组选项加载中 ? $r('app.string.deck_options_loading') : $r('app.string.deck_options_title'))
                  .width('100%')
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.按下按钮编号 === 4 ? this.主色容器色 : $r('app.color.surface_card'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.按下按钮编号 = 4; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下按钮编号 = 0; }
                  })
                  .enabled(!this.牌组选项加载中)
                  .onClick((): void => {
                    this.显示更多 = false;
                    this.打开牌组选项();
                  })
                Button($r('app.string.deck_export_this'))
                  .width('100%')
                  .height(应用尺寸.按钮高度)
                  .fontSize(应用尺寸.字号_按钮)
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor(this.按下按钮编号 === 5 ? this.主色容器色 : $r('app.color.surface_card'))
                  .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                  .borderRadius(应用尺寸.圆角_胶囊)
                  .animation({ duration: 80, curve: Curve.EaseOut })
                  .onTouch((event: TouchEvent): void => {
                    if (event.type === TouchType.Down) { this.按下按钮编号 = 5; }
                    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.按下按钮编号 = 0; }
                  })
                  .onClick((): void => {
                    this.显示更多 = false;
                    this.导出牌组();
                  })
              }
              .width('100%')
            }

            if (this.牌组选项错误 !== '') {
              Text(this.牌组选项错误)
                .fontSize(应用尺寸.字号_正文_小)
                .fontColor($r('app.color.error_text'))
                .width('100%')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            Blank()
            开始学习按钮({
              待学数: deck.newCount + deck.learningCount + deck.reviewCount,
              开始学习回调: (): void => {
                this.开始学习();
              }
            })
          }
        }, (deck: 牌组汇总) => `${deck.id}_${deck.totalCards}_${deck.newCount}_${deck.learningCount}_${deck.reviewCount}_${deck.displayName}`)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({
        left: 应用尺寸.卡片内边距,
        right: 应用尺寸.卡片内边距,
        top: 应用尺寸.卡片内边距,
        bottom: 应用尺寸.页面内边距_水平
      })
      .backgroundColor($r('app.color.surface_card'))
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .borderRadius(应用尺寸.圆角_卡片)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 应用尺寸.页面内边距_水平,
      right: 应用尺寸.页面内边距_水平,
      top: 应用尺寸.间距_4,
      bottom: 应用尺寸.页面内边距_水平
    })
  }
}
