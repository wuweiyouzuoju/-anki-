// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 牌组自定义弹层（全屏磨砂覆盖层）。
// 承载两件事：
//   1. 牌组改名（保留原 fullName 含 :: 以编辑层级；走本地 displayName 覆盖，不动后端）
//   2. 牌组背景图：PhotoViewPicker 选图 → IBestImageCropper 裁剪 → PixelMap 上抛 Index 落盘
//
// 裁剪框尺寸 = 预览区实际尺寸（onAreaChange 测量），与 DeckListItem 渲染时 objectFit=Cover
// 保持一致，确保用户在裁剪器里看到的选区就是牌组行实际显示的区域。
import { common } from '@kit.AbilityKit';
import { IBestImageCropper } from '@ibestservices/ibest-ui';
import { IBestImageCropperController } from '@ibestservices/ibest-ui';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppDimens } from '../utils/AppDimens';
import { DeckSummary, DeckTone, deckDisplayName } from '../model/HomeModels';
import { pickImageFromGallery } from '../utils/FileImportHelper';
import { COLOR_KEYS } from '../model/ColorTheme';

/** 面板提交时携带的背景图动作。 */
export type DeckBackgroundAction = 'keep' | 'remove' | 'replace';

/** 面板 onSave 上抛的结果：新名 + 背景图动作 + 裁剪后的 PixelMap（仅 replace 时有效）。 */
export interface DeckCustomizeResult {
  newName: string;
  backgroundAction: DeckBackgroundAction;
  backgroundPixelMap: PixelMap | null;
}

@Component
export struct DeckCustomizePanel {
  @Prop isDark: boolean = false;
  @Prop deck: DeckSummary = {
    id: '', name: '', fullName: '', depth: 0, parentId: '', hasChildren: false, ancestorIds: [],
    description: '',
    newCount: 0, learningCount: 0, reviewCount: 0, totalCards: 0,
    tone: DeckTone.Blue,
    displayName: '',
    backgroundImage: ''
  };
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  onClose: () => void = (): void => {};
  onSave: (result: DeckCustomizeResult) => void = (_r: DeckCustomizeResult): void => {};

  // 裁剪/选图等内部操作的错误信息（与父组件传入的 errorMessage 分开，build 里一并显示）
  @State private localError: string = '';

  @State private editingName: string = '';
  // 选图后等待裁剪的源图 uri（PhotoViewPicker 返回的 provider uri）
  @State private pendingCropUri: string = '';
  // 是否进入裁剪模式（全屏覆盖原面板）
  @State private cropMode: boolean = false;
  // 裁剪框尺寸（由预览区 onAreaChange 测量得到，未测量前用 0 占位，0 时 cropper 不渲染）
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;
  // 用户在裁剪模式按"取消"前的背景图动作意图：用于区分"用户主动移除"与"保留原状"
  @State private backgroundAction: DeckBackgroundAction = 'keep';
  // 裁剪后的 PixelMap（仅 replace 时非空）；@State 持有让 Image 预览能响应刷新
  @State private croppedPixelMap: PixelMap | null = null;
  // 原背景图（keep 态显示）异步加载的 PixelMap；与 DeckListItem 同款方式：
  // fileIo.openSync → image.createImageSource → createPixelMap，避免直接传沙盒路径白屏
  @State private originalPixelMap: PixelMap | null = null;

  private readonly cropperController: IBestImageCropperController = new IBestImageCropperController();
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @State private savePressed: boolean = false;

  aboutToAppear(): void {
    this.editingName = deckDisplayName(this.deck);
    // 已有背景图：保留态；无背景图：保留态（不修改）。用户操作后切到 remove/replace。
    this.backgroundAction = 'keep';
    this.loadOriginalPixelMap();
  }

  /** 异步加载牌组原有背景图为 PixelMap（与 DeckListItem.loadBackgroundPixelMap 同款）。
   *  ArkUI Image 直接传沙盒绝对路径解析不稳定，必须用 PixelMap。 */
  private async loadOriginalPixelMap(): Promise<void> {
    const path: string = this.deck.backgroundImage;
    if (path === '') {
      this.originalPixelMap = null;
      return;
    }
    try {
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const imageSource: image.ImageSource = image.createImageSource(file.fd);
        try {
          this.originalPixelMap = await imageSource.createPixelMap();
        } finally {
          imageSource.release();
        }
      } finally {
        await fileIo.close(file);
      }
    } catch (error) {
      this.originalPixelMap = null;
    }
  }

  private canSubmit(): boolean {
    if (this.busy) {
      return false;
    }
    if (this.editingName.trim().length === 0) {
      return false;
    }
    // 替换背景必须先完成裁剪（pendingCropUri === '' 表示已裁剪完成或未选图）
    if (this.backgroundAction === 'replace' && this.pendingCropUri !== '') {
      return false;
    }
    return true;
  }

  /** 点"选择图片"或"替换图片"：调起 PhotoViewPicker → 进入裁剪模式。 */
  private async pickAndCrop(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.localError = '';
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) {
      return;
    }
    const uri: string | null = await pickImageFromGallery(context);
    if (uri === null || uri === '') {
      // 用户取消或选图失败：静默返回，不打错误提示（cancel 是正常流程）
      return;
    }
    this.pendingCropUri = uri;
    this.cropMode = true;
  }

  /** 用户在裁剪模式点"应用裁剪"：从 cropper 拿 PixelMap，标记 replace，关闭裁剪模式。
   *  PixelMap 暂存到 croppedPixelMap 字段（@State），submit 时上抛。
   *  注意：必须清空 pendingCropUri——canSubmit() 用 `backgroundAction === 'replace'
   *  && pendingCropUri !== ''` 判断"replace 但还没裁剪"，若不清空会卡死保存键。 */
  private async applyCrop(): Promise<void> {
    if (this.busy) {
      return;
    }
    try {
      const pixelMap: PixelMap = await this.cropperController.getResult();
      this.croppedPixelMap = pixelMap;
      this.backgroundAction = 'replace';
      this.cropMode = false;
      this.pendingCropUri = '';
    } catch (error) {
      // 裁剪失败：留在裁剪模式让用户重试，错误显示到面板底部 localError
      this.localError = error instanceof Error ? error.message : `${error}`;
    }
  }

  /** 当前预览框是否有图（用于按钮文本/显示判断）。
   *  remove 态无图；replace 态看 croppedPixelMap；keep 态看 originalPixelMap。 */
  private hasBackground(): boolean {
    if (this.backgroundAction === 'remove') {
      return false;
    }
    if (this.backgroundAction === 'replace') {
      return this.croppedPixelMap !== null;
    }
    // keep
    return this.originalPixelMap !== null;
  }

  /** 用户在裁剪模式点"取消"：放弃当前选图，回到面板。
   *  只关闭裁剪模式 + 清 pendingCropUri；不动 croppedPixelMap 与 backgroundAction：
   *  - 首次选图取消：backgroundAction 仍是 keep、croppedPixelMap 仍是 null → 回到原态
   *  - 已裁剪后再次选图取消：backgroundAction 仍是 replace、croppedPixelMap 保留上次结果 → 回到上次裁剪预览
   *  旧实现清掉 croppedPixelMap 并把 replace 回退为 keep，会丢失用户上一次的裁剪成果。 */
  private cancelCrop(): void {
    this.cropMode = false;
    this.pendingCropUri = '';
  }

  /** 用户点"移除背景"：标记 remove，清掉待裁剪状态。 */
  private markRemove(): void {
    if (this.busy) {
      return;
    }
    this.backgroundAction = 'remove';
    this.croppedPixelMap = null;
    this.pendingCropUri = '';
  }

  /** 移除后又想保留：点预览区恢复。 */
  private unmarkRemove(): void {
    if (this.busy) {
      return;
    }
    this.backgroundAction = 'keep';
  }

  /** 提交时把 croppedPixelMap 拼进结果（覆盖 null 占位）。 */
  private submitWithPixelMap(): void {
    if (!this.canSubmit()) {
      return;
    }
    this.onSave({
      newName: this.editingName,
      backgroundAction: this.backgroundAction,
      backgroundPixelMap: this.croppedPixelMap
    });
  }

  build() {
    Stack() {
      // ---- 底层：磨砂遮罩 + 主面板 ----
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDark ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => { if (!this.busy && !this.cropMode) this.onClose(); })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      // ---- 主面板 ----
      Column({ space: AppDimens.SPACE_12 }) {
        Text($r('app.string.deck_customize_title'))
          .fontSize(AppDimens.FONT_PANEL_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        // 牌组名输入：保留原 fullName（含 ::）以编辑层级
        Column({ space: AppDimens.SPACE_5 }) {
          Text($r('app.string.deck_customize_name_label'))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({ text: this.editingName })
            .width('100%')
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BODY)
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(AppDimens.RADIUS_PANEL)
            .enabled(!this.busy)
            .onChange((value: string) => { this.editingName = value; })
        }.width('100%')

        // 背景图预览与操作区
        Column({ space: AppDimens.SPACE_5 }) {
          Text($r('app.string.deck_customize_background_label'))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text($r('app.string.deck_customize_background_hint'))
            .fontSize(AppDimens.FONT_CAPTION)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')

          // 预览框：与牌组行实际渲染口径一致（objectFit=Cover + 同宽度 + 同高度）
          // onAreaChange 测量实际尺寸供 cropper 使用；
          // 预览框高度 = AppDimens.DECK_ROW_HEIGHT（与 DeckListItem 自适应行高一致，
          // 保证用户在裁剪器看到的选区比例就是牌组行实际显示的比例）
          Stack() {
            if (this.backgroundAction === 'remove') {
              // 已标记移除：显示空态可恢复
              Column({ space: AppDimens.SPACE_5 }) {
                Text($r('app.string.deck_customize_background_remove'))
                  .fontSize(AppDimens.FONT_BODY_S)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => { this.unmarkRemove(); })
            } else if (this.backgroundAction === 'replace' && this.croppedPixelMap !== null) {
              // 已裁剪：显示裁剪结果预览（PixelMap）
              Image(this.croppedPixelMap)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .borderRadius(AppDimens.RADIUS_PANEL)
              // 右上角 × 删除：markAnchor 锚定元素右上角，position 锚定 Stack 右上角，
              // translate 推 4px 内边距；避免 position('88%') 在不同预览宽度下距右边漂移
              Button('×')
                .type(ButtonType.Circle)
                .width(24)
                .height(24)
                .fontSize(AppDimens.FONT_BODY)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor('rgba(0,0,0,0.45)')
                .markAnchor({ x: '100%', y: '0%' })
                .position({ x: '100%', y: 0 })
                .translate({ x: -4, y: 4 })
                .onClick(() => { this.markRemove(); })
            } else if (this.originalPixelMap !== null) {
              // 沿用原背景图（用 PixelMap 渲染，避免沙盒路径白屏）
              Image(this.originalPixelMap)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .borderRadius(AppDimens.RADIUS_PANEL)
              Button('×')
                .type(ButtonType.Circle)
                .width(24)
                .height(24)
                .fontSize(AppDimens.FONT_BODY)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor('rgba(0,0,0,0.45)')
                .markAnchor({ x: '100%', y: '0%' })
                .position({ x: '100%', y: 0 })
                .translate({ x: -4, y: 4 })
                .onClick(() => { this.markRemove(); })
            } else {
              // 无背景图：空态
              Column()
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
            }
          }
          .width('100%')
          .height(AppDimens.DECK_ROW_HEIGHT)
          .backgroundColor($r('app.color.surface_page'))
          .borderRadius(AppDimens.RADIUS_PANEL)
          .border({
            width: AppDimens.CARD_BORDER,
            color: $r('app.color.border_subtle')
          })
          .onAreaChange((_old: Area, newArea: Area) => {
            // Area.width/height 在 ArkTS 里是 Length 类型（string|number），需转 number
            const w: number = typeof newArea.width === 'number'
              ? newArea.width : parseInt(newArea.width as string, 10);
            const h: number = typeof newArea.height === 'number'
              ? newArea.height : parseInt(newArea.height as string, 10);
            if (!Number.isNaN(w) && !Number.isNaN(h)) {
              this.previewWidth = w;
              this.previewHeight = h;
            }
          })

          // 操作按钮：选择图片 / 替换图片 / 移除背景
          // 按钮文本与显示用 hasBackground() 统一判断，避免 markRemove 后 deck.backgroundImage
          // 仍非空导致按钮文本/显示不正确
          Row({ space: AppDimens.SPACE_8 }) {
            Button(this.hasBackground()
              ? $r('app.string.deck_customize_background_replace')
              : $r('app.string.deck_customize_background_pick'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(AppDimens.BUTTON_HEIGHT)
              .fontSize(AppDimens.FONT_BUTTON)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
              .borderRadius(AppDimens.RADIUS_PILL)
              .enabled(!this.busy)
              .onClick(() => { this.pickAndCrop(); })
            if (this.hasBackground()) {
              Button($r('app.string.deck_customize_background_remove'))
                .type(ButtonType.Normal)
                .layoutWeight(1)
                .height(AppDimens.BUTTON_HEIGHT)
                .fontSize(AppDimens.FONT_BUTTON)
                .fontColor($r('app.color.error_text'))
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
                .borderRadius(AppDimens.RADIUS_PILL)
                .enabled(!this.busy)
                .onClick(() => { this.markRemove(); })
            }
          }
          .width('100%')
        }
        .width('100%')

        if (this.errorMessage !== '') {
          Text(this.errorMessage)
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.error_text'))
            .width('100%')
        }
        if (this.localError !== '') {
          Text(this.localError)
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.error_text'))
            .width('100%')
        }

        Blank()

        Button($r('app.string.deck_customize_save'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(AppDimens.BUTTON_HEIGHT)
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.savePressed ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
          .borderRadius(AppDimens.RADIUS_PILL)
          .animation({ duration: 80, curve: Curve.EaseOut })
          .enabled(this.canSubmit())
          .onTouch((event: TouchEvent): void => {
            if (event.type === TouchType.Down) {
              this.savePressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.savePressed = false;
            }
          })
          .onClick(() => { this.submitWithPixelMap(); })
      }
      .width('88%')
      .height('88%')
      .constraintSize({ maxWidth: 480 })
      .padding(AppDimens.CARD_PADDING)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_CARD)
      .onClick(() => {
        // 阻断点击穿透到遮罩
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

      // ---- 顶层：裁剪模式覆盖层（仅 cropMode=true 时显示）----
      if (this.cropMode) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.85)')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        Column({ space: AppDimens.SPACE_12 }) {
          Text($r('app.string.deck_customize_background_crop_title'))
            .fontSize(AppDimens.FONT_PANEL_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.deck_customize_background_crop_hint'))
            .fontSize(AppDimens.FONT_BODY_S)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          // 裁剪器：仅在 previewWidth/Height 测量完成后渲染（避免 0 尺寸导致组件初始化异常）
          // 组件高度 = 预览高度 * 3，给用户足够的拖动空间；裁剪框尺寸 = 预览尺寸（与实机一致）
          if (this.previewWidth > 0 && this.previewHeight > 0 && this.pendingCropUri !== '') {
            Column() {
              IBestImageCropper({
                componentWidth: this.previewWidth,
                componentHeight: this.previewHeight * 3,
                url: this.pendingCropUri,
                shape: 'rect',
                centerWidth: this.previewWidth,
                centerHeight: this.previewHeight,
                showBorder: true,
                bdColor: this.actionPrimaryColor,
                maxScale: 4,
                enableRotate: false,
                controller: this.cropperController
              })
            }
            .width('100%')
            .height(this.previewHeight * 3)
          }

          Row({ space: AppDimens.SPACE_8 }) {
            Button($r('app.string.deck_customize_background_crop_cancel'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(AppDimens.BUTTON_HEIGHT)
              .fontSize(AppDimens.FONT_BUTTON)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
              .borderRadius(AppDimens.RADIUS_PILL)
              .onClick(() => { this.cancelCrop(); })
            Button($r('app.string.deck_customize_background_crop_confirm'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(AppDimens.BUTTON_HEIGHT)
              .fontSize(AppDimens.FONT_BUTTON)
              .fontColor($r('app.color.action_on_primary'))
              .backgroundColor(this.actionPrimaryColor)
              .borderRadius(AppDimens.RADIUS_PILL)
              .onClick(() => { this.applyCrop(); })
          }
          .width('100%')
        }
        .width('92%')
        .height('88%')
        .constraintSize({ maxWidth: 560 })
        .padding(AppDimens.CARD_PADDING)
        .backgroundColor($r('app.color.surface_card'))
        .borderRadius(AppDimens.RADIUS_CARD)
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.opacity(0)
            .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
            .animation({ curve: Curve.EaseOut, duration: 200 }),
          TransitionEffect.opacity(0)
            .animation({ curve: Curve.EaseIn, duration: 150 })
        ))
      }
    }
    .width('100%')
    .height('100%')
  }
}
