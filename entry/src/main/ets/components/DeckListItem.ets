﻿import { DeckSummary, DeckTone, deckDisplayName } from '../model/HomeModels';
import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/** bindPopup onStateChange 回调的事件参数。 */
interface PopupStateEvent {
  isVisible: boolean;
}

/** 色条子菜单选项：tone + 颜色资源 + 标签资源；colorResource=null 表示无色块（None 项）。 */
interface ToneOption {
  tone: DeckTone;
  colorResource: Resource | null;
  labelResource: Resource;
}

// 卡组列表行：色条 + 名称/描述 + 待学计数，选中态高亮。
@Component
export struct DeckListItem {
  @Prop deck: DeckSummary = {
    id: '', name: '', fullName: '', depth: 0, parentId: '', hasChildren: false, ancestorIds: [],
    description: '',
    newCount: 0, learningCount: 0, reviewCount: 0, totalCards: 0,
    tone: DeckTone.Blue,
    displayName: '',
    backgroundImage: ''
  };
  @Prop selected: boolean = false;
  @Prop expanded: boolean = false;
  // 排序模式：true 时左侧显示≡手柄、行高亮描边、onClick 不触发选牌、长按不弹菜单。
  // 用户通过 DeckListItem 长按菜单的「拖动排序」项进入；Index.ets 顶部 Bar 上的「完成」退出。
  @Prop reorderMode: boolean = false;
  @State private showDeckMenu: boolean = false;
  @State private deckMenuMode: 'main' | 'tone' = 'main';
  // 沙盒背景图异步加载的 PixelMap。
  // 必须用 PixelMap 而不是直接传文件路径给 Image——ArkUI Image 对沙盒绝对路径解析不稳定，
  // 标准方式是 fileIo.openSync → image.createImageSource → createPixelMap → Image(pixelMap)。
  // LazyForEach keyItem 含 backgroundImage，deck 变化时 ListItem 重建，aboutToAppear 重新加载。
  @State private backgroundPixelMap: PixelMap | null = null;
  onSelect: (deckId: string) => void = (deckId: string): void => {
  };
  onToggle: (deckId: string) => void = (deckId: string): void => {
  };
  onToneChange: (deckId: string, tone: DeckTone) => void = (deckId: string, tone: DeckTone): void => {
  };
  onCustomizeDeck: (deckId: string) => void = (deckId: string): void => {
  };
  // 用户在长按菜单选「拖动排序」时触发；Index.ets 进入 isReorderMode=true 状态。
  onEnterReorder: (deckId: string) => void = (deckId: string): void => {
  };
  // 用户在长按菜单选「删除牌组」时触发；Index.ets 弹 AlertDialog 二次确认后真正调 removeDecks。
  onDeleteDeck: (deckId: string) => void = (deckId: string): void => {
  };
  // 用户在长按菜单选「隐藏牌组」时触发；Index.ets 写入 hiddenDeckIds 持久化并从列表过滤。
  // 与删除不同：隐藏只在前端列表里隐藏，不动后端数据；可在设置页「已隐藏牌组」恢复。
  onHideDeck: (deckId: string) => void = (deckId: string): void => {
  };

  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.surfaceSelected) private surfaceSelectedColor: string = '#E8EEFC';
  @StorageProp(COLOR_KEYS.primaryBorder) private primaryBorderColor: string = '#B8CEFA';
  @StorageProp(COLOR_KEYS.countNew) private countNewColor: string = '#3974D9';
  @StorageProp(COLOR_KEYS.countLearning) private countLearningColor: string = '#B56A22';
  @StorageProp(COLOR_KEYS.countReview) private countReviewColor: string = '#7056C8';

  aboutToAppear(): void {
    this.loadBackgroundPixelMap();
  }

  /** 异步加载沙盒背景图为 PixelMap。
   *  ArkUI Image 直接传沙盒绝对路径解析不稳定（部分版本白屏），
   *  标准方式是 fileIo.openSync → image.createImageSource(fd) → createPixelMap → Image(pixelMap)。
   *  失败时静默——backgroundPixelMap 保持 null，Stack 显示 surface_card 底色。 */
  private async loadBackgroundPixelMap(): Promise<void> {
    const path: string = this.deck.backgroundImage;
    if (path === '') {
      this.backgroundPixelMap = null;
      return;
    }
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      try {
        const imageSource: image.ImageSource = image.createImageSource(file.fd);
        try {
          this.backgroundPixelMap = await imageSource.createPixelMap();
        } finally {
          imageSource.release();
        }
      } finally {
        await fs.close(file);
      }
    } catch (error) {
      // 文件不存在或解码失败：backgroundPixelMap 保持 null，UI 显示底色
      this.backgroundPixelMap = null;
    }
  }

  private deckToneColor(tone: DeckTone): Resource {
    switch (tone) {
      case DeckTone.Purple:
        return $r('app.color.deck_purple');
      case DeckTone.Mint:
        return $r('app.color.deck_mint');
      case DeckTone.Amber:
        return $r('app.color.deck_amber');
      case DeckTone.Black:
        return $r('app.color.deck_black');
      case DeckTone.Red:
        return $r('app.color.deck_red');
      case DeckTone.Blue:
      default:
        return $r('app.color.deck_blue');
    }
  }

  /** 色条子菜单的 7 个选项（6 色 + None），顺序与原硬编码一致；None 项 colorResource=null 跳过色块。 */
  private readonly toneOptions: ToneOption[] = [
    { tone: DeckTone.Blue, colorResource: $r('app.color.deck_blue'), labelResource: $r('app.string.deck_tone_blue') },
    { tone: DeckTone.Purple, colorResource: $r('app.color.deck_purple'), labelResource: $r('app.string.deck_tone_purple') },
    { tone: DeckTone.Mint, colorResource: $r('app.color.deck_mint'), labelResource: $r('app.string.deck_tone_mint') },
    { tone: DeckTone.Amber, colorResource: $r('app.color.deck_amber'), labelResource: $r('app.string.deck_tone_amber') },
    { tone: DeckTone.Black, colorResource: $r('app.color.deck_black'), labelResource: $r('app.string.deck_tone_black') },
    { tone: DeckTone.Red, colorResource: $r('app.color.deck_red'), labelResource: $r('app.string.deck_tone_red') },
    { tone: DeckTone.None, colorResource: null, labelResource: $r('app.string.deck_tone_none') }
  ];

  // 注意：三个计数不能用 @Builder 方法渲染——ArkUI 的 @Builder 在首次渲染时
  // 捕获 this.deck 字段值后不响应 @Prop 后续变化，会导致学完卡后列表项的"新/学/复"
  // 数字不刷新。必须 inline 写在 build() 中，并由 build() 直接访问 this.deck.xxx。
  // 说明小字「今日还能学」用于解释这三个数字是"今日还能学多少"而非"总卡数"，
  // 对应 Anki 的 newCount = min(new_per_day - new_studied, 实际待学新卡数) 语义。

  /** 主菜单：切换色条 / 拖动排序 / 自定义牌组。点「切换色条」不关 Popup，切到 tone 子菜单。 */
  @Builder
  private deckMenuMain() {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.deck_menu_switch_tone'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('›')
          .fontSize(AppDimens.FONT_TITLE)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.deckMenuMode = 'tone';
      })
      Row() {
        Text($r('app.string.deck_menu_reorder'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.showDeckMenu = false;
        this.onEnterReorder(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_customize'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.showDeckMenu = false;
        this.onCustomizeDeck(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_menu_hide'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.showDeckMenu = false;
        this.onHideDeck(this.deck.id);
      })
      Row() {
        Text($r('app.string.deck_menu_delete'))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.error_text'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick(() => {
        this.showDeckMenu = false;
        this.onDeleteDeck(this.deck.id);
      })
    }
    .width(180)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(AppDimens.RADIUS_PANEL)
  }

  /** 单行色条选项：色块（None 项跳过）+ 标签 + 选中态勾选；点击上抛 onToneChange 并关 Popup。 */
  @Builder
  private toneOptionRow(option: ToneOption) {
    Row() {
      if (option.colorResource !== null) {
        Row()
          .width(12)
          .height(12)
          .backgroundColor(option.colorResource)
          .borderRadius(AppDimens.RADIUS_TONE)
          .margin({ right: 10 })
      }
      Text(option.labelResource)
        .fontSize(AppDimens.FONT_BODY)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.deck.tone === option.tone) {
        Text('✓')
          .fontSize(AppDimens.FONT_BODY)
          .fontColor(this.actionPrimaryColor)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.showDeckMenu = false;
      this.onToneChange(this.deck.id, option.tone);
    })
  }

  /** 色条子菜单：返回按钮 + 7 个色条选项（6 色 + None），用 ForEach 遍历 toneOptions。 */
  @Builder
  private deckMenuTone() {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.deck_menu_back'))
          .fontSize(AppDimens.FONT_BODY_S)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .onClick(() => {
        this.deckMenuMode = 'main';
      })
      ForEach(this.toneOptions, (option: ToneOption) => {
        this.toneOptionRow(option);
      }, (option: ToneOption) => option.tone.toString())
    }
    .width(180)
    .backgroundColor($r('app.color.surface_card'))
    .borderRadius(AppDimens.RADIUS_PANEL)
  }

  /** Popup 内容：根据 deckMenuMode 切换主菜单 / 色条子菜单。 */
  @Builder
  private deckMenuBuilder() {
    Column() {
      if (this.deckMenuMode === 'main') {
        this.deckMenuMain();
      } else {
        this.deckMenuTone();
      }
    }
  }

  build() {
    Stack() {
      // 底层：背景图（objectFit=Cover 与 DeckCustomizePanel 预览口径一致，
      // 用户在面板内裁剪出来的选区就是这里实际显示的区域）
      // 必须用 PixelMap 渲染——ArkUI Image 直接传沙盒绝对路径解析不稳定（白屏）
      if (this.backgroundPixelMap !== null) {
        Image(this.backgroundPixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(AppDimens.RADIUS_DECK)
      }
      // Row 内容：箭头/手柄/色条/文字/计数
      Row({ space: AppDimens.SPACE_12 }) {
        // 箭头槽位：所有行同宽占位，父子行内容纵向对齐；仅用 ▼ 字形旋转向右，规避 ▶ 的 emoji 呈现
        // reorderMode 时显示 ≡ 手柄（提示可拖），且 onClick 不触发折叠/展开
        Column() {
          if (this.reorderMode) {
            Text('≡')
              .fontSize(AppDimens.FONT_TITLE)
              .fontColor($r('app.color.text_secondary'))
          } else if (this.deck.hasChildren) {
            Text('▼')
              .fontSize(AppDimens.FONT_TITLE)
              .fontColor($r('app.color.text_secondary'))
              .rotate({ angle: this.expanded ? 0 : -90 })
              .animation({ duration: 150, curve: Curve.EaseOut })
          }
        }
        .width(AppDimens.ARROW_SLOT_WIDTH)
        .height(AppDimens.ARROW_SLOT_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: -AppDimens.SPACE_10 })
        .onClick(() => {
          if (this.reorderMode) {
            return;
          }
          if (this.deck.hasChildren) {
            this.onToggle(this.deck.id);
          }
        })
        // 色条：tone===None 时不渲染色块，但保留 Column 占位以维持行内对齐。
        Column()
          .width(AppDimens.TONE_BAR_WIDTH)
          .height(AppDimens.TONE_BAR_HEIGHT)
          .backgroundColor(
            this.deck.tone === DeckTone.None ? Color.Transparent : this.deckToneColor(this.deck.tone))
          .borderRadius(AppDimens.RADIUS_TONE)
        Column({ space: AppDimens.SPACE_5 }) {
          Text(deckDisplayName(this.deck))
            .fontSize(AppDimens.FONT_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.deck.description)
            .fontSize(AppDimens.FONT_BODY_M)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: AppDimens.SPACE_5 }) {
          Row({ space: AppDimens.SPACE_8 }) {
            Text($r('app.string.deck_new_short', this.deck.newCount))
              .fontSize(AppDimens.FONT_BODY_S)
              .fontColor(this.countNewColor)
            Text($r('app.string.deck_learning_short', this.deck.learningCount))
              .fontSize(AppDimens.FONT_BODY_S)
              .fontColor(this.countLearningColor)
            Text($r('app.string.deck_review_short', this.deck.reviewCount))
              .fontSize(AppDimens.FONT_BODY_S)
              .fontColor(this.countReviewColor)
          }
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding({
        left: AppDimens.SPACE_14 + this.deck.depth * AppDimens.SPACE_16,
        right: AppDimens.SPACE_14,
        top: AppDimens.SPACE_13,
        bottom: AppDimens.SPACE_13
      })
      .onClick(() => {
        // 排序模式下不触发选牌；长按手柄+拖动才是预期操作
        if (this.reorderMode) {
          return;
        }
        this.onSelect(this.deck.id);
      })
      // 排序模式下把 LongPressGesture 的 duration 改到极大值（等效禁用），
      // 避免子组件的长按手势偷走 List.onMove 的事件；onAction 内再加守卫兜底。
      .gesture(
        LongPressGesture({ repeat: false, duration: this.reorderMode ? 99999999 : 500 })
          .onAction(() => {
            if (this.reorderMode) {
              return;
            }
            this.deckMenuMode = 'main';
            this.showDeckMenu = true;
          })
      )
      .bindPopup(this.showDeckMenu, {
        builder: this.deckMenuBuilder,
        placement: Placement.Bottom,
        popupColor: $r('app.color.surface_card'),
        enableArrow: true,
        onStateChange: (event: PopupStateEvent): void => {
          if (!event.isVisible) {
            this.showDeckMenu = false;
          }
        }
      })
    }
    .width('100%')
    .height(AppDimens.DECK_ROW_HEIGHT)
    .clip(true)
    .borderRadius(AppDimens.RADIUS_DECK)
    .backgroundColor(this.selected ? this.surfaceSelectedColor : $r('app.color.surface_card'))
    .border({
      width: AppDimens.CARD_BORDER,
      // 排序模式下行描边用 action_primary 高亮，让用户感知「现在可拖」；
      // 选中态用 primary_border（比 action_primary 浅，避免选中行视觉过重）
      color: this.reorderMode
        ? this.actionPrimaryColor : (this.selected ?
          this.primaryBorderColor : $r('app.color.border_subtle'))
    })
  }
}
