// SPDX-License-Identifier: AGPL-3.0-or-later

import { 牌组汇总, 牌组色调, 牌组显示名 } from '../model/主页模型';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';

interface 弹层状态事件 {
  isVisible: boolean;
}

interface 色条选项 {
  tone: 牌组色调;
  colorResource: Resource | null;
  labelResource: Resource;
}

@Component
export struct 牌组列表项 {
  @Prop deck: 牌组汇总 = {
    id: '', name: '', fullName: '', depth: 0, parentId: '', hasChildren: false, ancestorIds: [],
    description: '',
    newCount: 0, learningCount: 0, reviewCount: 0, totalCards: 0,
    tone: 牌组色调.Blue,
    displayName: '',
    backgroundImage: ''
  };
  @Prop selected: boolean = false;
  @Prop expanded: boolean = false;
  @Prop reorderMode: boolean = false;
  @State private 显示牌组菜单: boolean = false;
  @State private 菜单模式: 'main' | 'tone' = 'main';
  @State private 背景像素图: PixelMap | null = null;
  private 上次点击时间: number = 0;
  onSelect: (deckId: string) => void = (deckId: string): void => {
  };
  onToggle: (deckId: string) => void = (deckId: string): void => {
  };
  onToneChange: (deckId: string, tone: 牌组色调) => void = (deckId: string, tone: 牌组色调): void => {
  };
  onCustomizeDeck: (deckId: string) => void = (deckId: string): void => {
  };
  onEnterReorder: (deckId: string) => void = (deckId: string): void => {
  };
  onDeleteDeck: (deckId: string) => void = (deckId: string): void => {
  };
  onHideDeck: (deckId: string) => void = (deckId: string): void => {
  };
  onDoubleTap: (deckId: string) => void = (deckId: string): void => {
  };

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.选中背景) private 选中背景色: string = '#E8EEFC';
  @StorageProp(颜色键.主色边框) private 主色边框色: string = '#B8CEFA';
  @StorageProp(颜色键.新卡计数色) private 新卡计数色: string = '#3974D9';
  @StorageProp(颜色键.学习中计数色) private 学习中计数色: string = '#B56A22';
  @StorageProp(颜色键.复习中计数色) private 复习中计数色: string = '#7056C8';

  aboutToAppear(): void {
    this.异步加载背景像素图();
  }

  private async 异步加载背景像素图(): Promise<void> {
    const 路径: string = this.deck.backgroundImage;
    if (路径 === '') {
      this.背景像素图 = null;
      return;
    }
    try {
      const 文件: fs.File = fs.openSync(路径, fs.OpenMode.READ_ONLY);
      try {
        const 图像源: image.ImageSource = image.createImageSource(文件.fd);
        try {
          this.背景像素图 = await 图像源.createPixelMap();
        } finally {
          图像源.release();
        }
      } finally {
        await fs.close(文件);
      }
    } catch (error) {
      this.背景像素图 = null;
    }
  }

  private 取色条颜色(tone: 牌组色调): Resource {
    switch (tone) {
      case 牌组色调.Purple:
        return $r('app.color.deck_purple');
      case 牌组色调.Mint:
        return $r('app.color.deck_mint');
      case 牌组色调.Amber:
        return $r('app.color.deck_amber');
      case 牌组色调.Black:
        return $r('app.color.deck_black');
      case 牌组色调.Red:
        return $r('app.color.deck_red');
      case 牌组色调.Blue:
      default:
        return $r('app.color.deck_blue');
    }
  }

  private readonly 色条选项列表: 色条选项[] = [
    { tone: 牌组色调.Blue, colorResource: $r('app.color.deck_blue'), labelResource: $r('app.string.deck_tone_blue') },
    { tone: 牌组色调.Purple, colorResource: $r('app.color.deck_purple'), labelResource: $r('app.string.deck_tone_purple') },
    { tone: 牌组色调.Mint, colorResource: $r('app.color.deck_mint'), labelResource: $r('app.string.deck_tone_mint') },
    { tone: 牌组色调.Amber, colorResource: $r('app.color.deck_amber'), labelResource: $r('app.string.deck_tone_amber') },
    { tone: 牌组色调.Black, colorResource: $r('app.color.deck_black'), labelResource: $r('app.string.deck_tone_black') },
    { tone: 牌组色调.Red, colorResource: $r('app.color.deck_red'), labelResource: $r('app.string.deck_tone_red') },
    { tone: 牌组色调.None, colorResource: null, labelResource: $r('app.string.deck_tone_none') }
  ];

  @Builder
  private 主菜单() {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.deck_menu_switch_tone'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('›')
          .fontSize(应用尺寸.字号_标题)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.菜单模式 = 'tone';
      })
      Row() {
        Text($r('app.string.deck_menu_reorder'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.显示牌组菜单 = false;
        this.onEnterReorder(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_customize'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.显示牌组菜单 = false;
        this.onCustomizeDeck(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_menu_hide'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.显示牌组菜单 = false;
        this.onHideDeck(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_menu_delete'))
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.error_text'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.显示牌组菜单 = false;
        this.onDeleteDeck(this.deck.id);
      })
    }
    .width(180)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(应用尺寸.圆角_面板)
  }

  @Builder
  private 单行色条选项(选项: 色条选项) {
    Row() {
      if (选项.colorResource !== null) {
        Row()
          .width(12)
          .height(12)
          .backgroundColor(选项.colorResource)
          .borderRadius(应用尺寸.圆角_色条)
          .margin({ right: 10 })
      }
      Text(选项.labelResource)
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.deck.tone === 选项.tone) {
        Text('✓')
          .fontSize(应用尺寸.字号_正文)
          .fontColor(this.动作主色)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.显示牌组菜单 = false;
      this.onToneChange(this.deck.id, 选项.tone);
    })
  }

  @Builder
  private 色条子菜单() {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.deck_menu_back'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => {
        this.菜单模式 = 'main';
      })
      ForEach(this.色条选项列表, (选项: 色条选项) => {
        this.单行色条选项(选项);
      }, (选项: 色条选项) => 选项.tone.toString())
    }
    .width(180)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(应用尺寸.圆角_面板)
  }

  @Builder
  private 弹层内容() {
    Column() {
      if (this.菜单模式 === 'main') {
        this.主菜单();
      } else {
        this.色条子菜单();
      }
    }
  }

  build() {
    Stack() {
      if (this.背景像素图 !== null) {
        Image(this.背景像素图)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(应用尺寸.圆角_牌组行)
      }
      Row({ space: 应用尺寸.间距_12 }) {
        Column() {
          if (this.reorderMode) {
            Text('≡')
              .fontSize(应用尺寸.字号_标题)
              .fontColor($r('app.color.text_secondary'))
          } else if (this.deck.hasChildren) {
            Text('▼')
              .fontSize(应用尺寸.字号_标题)
              .fontColor($r('app.color.text_secondary'))
              .rotate({ angle: this.expanded ? 0 : -90 })
              .animation({ duration: 150, curve: Curve.EaseOut })
          }
        }
        .width(应用尺寸.箭头槽位宽度)
        .height(应用尺寸.箭头槽位高度)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: -应用尺寸.间距_10 })
        .onClick(() => {
          if (this.reorderMode) {
            return;
          }
          if (this.deck.hasChildren) {
            this.onToggle(this.deck.id);
          }
        })
        Column()
          .width(应用尺寸.色条宽度)
          .height(应用尺寸.色条高度)
          .backgroundColor(
            this.deck.tone === 牌组色调.None ? Color.Transparent : this.取色条颜色(this.deck.tone))
          .borderRadius(应用尺寸.圆角_色条)
        Column({ space: 应用尺寸.间距_5 }) {
          Text(牌组显示名(this.deck))
            .fontSize(应用尺寸.字号_标题)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.deck.description)
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 应用尺寸.间距_5 }) {
          Row({ space: 应用尺寸.间距_8 }) {
            Text($r('app.string.deck_new_short', this.deck.newCount))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor(this.新卡计数色)
            Text($r('app.string.deck_learning_short', this.deck.learningCount))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor(this.学习中计数色)
            Text($r('app.string.deck_review_short', this.deck.reviewCount))
              .fontSize(应用尺寸.字号_正文_小)
              .fontColor(this.复习中计数色)
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding({
        left: 应用尺寸.间距_14 + this.deck.depth * 应用尺寸.间距_16,
        right: 应用尺寸.间距_14,
        top: 应用尺寸.间距_13,
        bottom: 应用尺寸.间距_13
      })
      .onClick(() => {
        if (this.reorderMode) {
          return;
        }
        const 当前时间: number = Date.now();
        const 间隔: number = 当前时间 - this.上次点击时间;
        if (间隔 < 300 && this.deck.hasChildren) {
          this.上次点击时间 = 0;
          this.onDoubleTap(this.deck.id);
          return;
        }
        this.上次点击时间 = 当前时间;
        this.onSelect(this.deck.id);
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: this.reorderMode ? 99999999 : 500 })
          .onAction(() => {
            if (this.reorderMode) {
              return;
            }
            this.菜单模式 = 'main';
            this.显示牌组菜单 = true;
          })
      )
      .bindPopup(this.显示牌组菜单, {
        builder: this.弹层内容,
        placement: Placement.Bottom,
        popupColor: $r('app.color.surface_card'),
        enableArrow: true,
        onStateChange: (event: 弹层状态事件): void => {
          if (!event.isVisible) {
            this.显示牌组菜单 = false;
          }
        }
      })
    }
    .width('100%')
    .height(应用尺寸.牌组行高度)
    .clip(true)
    .borderRadius(应用尺寸.圆角_牌组行)
    .backgroundColor(this.selected ? this.选中背景色 : $r('app.color.surface_card'))
    .border({
      width: 应用尺寸.卡片边框,
      color: this.reorderMode
        ? this.动作主色 : (this.selected ?
          this.主色边框色 : $r('app.color.border_subtle'))
    })
  }
}
