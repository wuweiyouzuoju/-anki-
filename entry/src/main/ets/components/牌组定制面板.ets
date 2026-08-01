// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { IBestImageCropper } from '@ibestservices/ibest-ui';
import { IBestImageCropperController } from '@ibestservices/ibest-ui';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 牌组汇总, 牌组色调, 牌组显示名 } from '../model/主页模型';
import { 从图库选取图片 } from '../utils/文件导入助手';
import { 颜色键 } from '../model/颜色主题';

export type 牌组背景动作 = 'keep' | 'remove' | 'replace';

export interface 牌组定制结果 {
  新名: string;
  背景动作: 牌组背景动作;
  背景像素图: PixelMap | null;
}

@Component
export struct 牌组定制面板 {
  @Prop isDark: boolean = false;
  @Prop deck: 牌组汇总 = {
    id: '', name: '', fullName: '', depth: 0, parentId: '', hasChildren: false, ancestorIds: [],
    description: '',
    newCount: 0, learningCount: 0, reviewCount: 0, totalCards: 0,
    tone: 牌组色调.Blue,
    displayName: '',
    backgroundImage: ''
  };
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  onClose: () => void = (): void => {};
  onSave: (结果: 牌组定制结果) => void = (_r: 牌组定制结果): void => {};

  @State private 本地错误: string = '';

  @State private 编辑中名称: string = '';
  @State private 待裁剪Uri: string = '';
  @State private 裁剪模式: boolean = false;
  @State private 预览宽度: number = 0;
  @State private 预览高度: number = 0;
  @State private 背景动作: 牌组背景动作 = 'keep';
  @State private 已裁剪像素图: PixelMap | null = null;
  @State private 原像素图: PixelMap | null = null;

  private readonly 裁剪器控制器: IBestImageCropperController = new IBestImageCropperController();
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下: string = '#1E4FB8';
  @State private 已按下保存: boolean = false;

  aboutToAppear(): void {
    this.编辑中名称 = 牌组显示名(this.deck);
    this.背景动作 = 'keep';
    this.加载原像素图();
  }

  private async 加载原像素图(): Promise<void> {
    const 路径: string = this.deck.backgroundImage;
    if (路径 === '') {
      this.原像素图 = null;
      return;
    }
    try {
      const 文件: fileIo.File = fileIo.openSync(路径, fileIo.OpenMode.READ_ONLY);
      try {
        const 图像源: image.ImageSource = image.createImageSource(文件.fd);
        try {
          this.原像素图 = await 图像源.createPixelMap();
        } finally {
          图像源.release();
        }
      } finally {
        await fileIo.close(文件);
      }
    } catch (错误) {
      this.原像素图 = null;
    }
  }

  private 可提交(): boolean {
    if (this.busy) {
      return false;
    }
    if (this.编辑中名称.trim().length === 0) {
      return false;
    }
    if (this.背景动作 === 'replace' && this.待裁剪Uri !== '') {
      return false;
    }
    return true;
  }

  private async 选取并裁剪(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.本地错误 = '';
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (上下文 === undefined) {
      return;
    }
    const uri: string | null = await 从图库选取图片(上下文);
    if (uri === null || uri === '') {
      return;
    }
    this.待裁剪Uri = uri;
    this.裁剪模式 = true;
  }

  private async 应用裁剪(): Promise<void> {
    if (this.busy) {
      return;
    }
    try {
      const 像素图: PixelMap = await this.裁剪器控制器.getResult();
      this.已裁剪像素图 = 像素图;
      this.背景动作 = 'replace';
      this.裁剪模式 = false;
      this.待裁剪Uri = '';
    } catch (错误) {
      this.本地错误 = 错误 instanceof Error ? 错误.message : `${错误}`;
    }
  }

  private 是否有背景(): boolean {
    if (this.背景动作 === 'remove') {
      return false;
    }
    if (this.背景动作 === 'replace') {
      return this.已裁剪像素图 !== null;
    }
    return this.原像素图 !== null;
  }

  private 取消裁剪(): void {
    this.裁剪模式 = false;
    this.待裁剪Uri = '';
  }

  private 标记移除(): void {
    if (this.busy) {
      return;
    }
    this.背景动作 = 'remove';
    this.已裁剪像素图 = null;
    this.待裁剪Uri = '';
  }

  private 撤销移除(): void {
    if (this.busy) {
      return;
    }
    this.背景动作 = 'keep';
  }

  private 提交带像素图(): void {
    if (!this.可提交()) {
      return;
    }
    this.onSave({
      新名: this.编辑中名称,
      背景动作: this.背景动作,
      背景像素图: this.已裁剪像素图
    });
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
        .onClick(() => { if (!this.busy && !this.裁剪模式) this.onClose(); })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: 应用尺寸.间距_12 }) {
        Text($r('app.string.deck_customize_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Column({ space: 应用尺寸.间距_5 }) {
          Text($r('app.string.deck_customize_name_label'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({ text: this.编辑中名称 })
            .width('100%')
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
            .borderRadius(应用尺寸.圆角_面板)
            .enabled(!this.busy)
            .onChange((值: string) => { this.编辑中名称 = 值; })
        }.width('100%')

        Column({ space: 应用尺寸.间距_5 }) {
          Text($r('app.string.deck_customize_background_label'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text($r('app.string.deck_customize_background_hint'))
            .fontSize(应用尺寸.字号_说明)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')

          Stack() {
            if (this.背景动作 === 'remove') {
              Column({ space: 应用尺寸.间距_5 }) {
                Text($r('app.string.deck_customize_background_remove'))
                  .fontSize(应用尺寸.字号_正文_小)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => { this.撤销移除(); })
            } else if (this.背景动作 === 'replace' && this.已裁剪像素图 !== null) {
              Image(this.已裁剪像素图)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .borderRadius(应用尺寸.圆角_面板)
              Button('×')
                .type(ButtonType.Circle)
                .width(24)
                .height(24)
                .fontSize(应用尺寸.字号_正文)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor('rgba(0,0,0,0.45)')
                .markAnchor({ x: '100%', y: '0%' })
                .position({ x: '100%', y: 0 })
                .translate({ x: -4, y: 4 })
                .onClick(() => { this.标记移除(); })
            } else if (this.原像素图 !== null) {
              Image(this.原像素图)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .borderRadius(应用尺寸.圆角_面板)
              Button('×')
                .type(ButtonType.Circle)
                .width(24)
                .height(24)
                .fontSize(应用尺寸.字号_正文)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor('rgba(0,0,0,0.45)')
                .markAnchor({ x: '100%', y: '0%' })
                .position({ x: '100%', y: 0 })
                .translate({ x: -4, y: 4 })
                .onClick(() => { this.标记移除(); })
            } else {
              Column()
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
            }
          }
          .width('100%')
          .height(应用尺寸.牌组行高度)
          .backgroundColor($r('app.color.surface_page'))
          .borderRadius(应用尺寸.圆角_面板)
          .border({
            width: 应用尺寸.卡片边框,
            color: $r('app.color.border_subtle')
          })
          .onAreaChange((_旧: Area, 新区域: Area) => {
            const 宽: number = typeof 新区域.width === 'number'
              ? 新区域.width : parseInt(新区域.width as string, 10);
            const 高: number = typeof 新区域.height === 'number'
              ? 新区域.height : parseInt(新区域.height as string, 10);
            if (!Number.isNaN(宽) && !Number.isNaN(高)) {
              this.预览宽度 = 宽;
              this.预览高度 = 高;
            }
          })

          Row({ space: 应用尺寸.间距_8 }) {
            Button(this.是否有背景()
              ? $r('app.string.deck_customize_background_replace')
              : $r('app.string.deck_customize_background_pick'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_按钮)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
              .borderRadius(应用尺寸.圆角_胶囊)
              .enabled(!this.busy)
              .onClick(() => { this.选取并裁剪(); })
            if (this.是否有背景()) {
              Button($r('app.string.deck_customize_background_remove'))
                .type(ButtonType.Normal)
                .layoutWeight(1)
                .height(应用尺寸.按钮高度)
                .fontSize(应用尺寸.字号_按钮)
                .fontColor($r('app.color.error_text'))
                .backgroundColor($r('app.color.surface_card'))
                .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
                .borderRadius(应用尺寸.圆角_胶囊)
                .enabled(!this.busy)
                .onClick(() => { this.标记移除(); })
            }
          }
          .width('100%')
        }
        .width('100%')

        if (this.errorMessage !== '') {
          Text(this.errorMessage)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
        }
        if (this.本地错误 !== '') {
          Text(this.本地错误)
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.error_text'))
            .width('100%')
        }

        Blank()

        Button($r('app.string.deck_customize_save'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.已按下保存 ? this.主色按钮按下 : this.主色按钮背景)
          .borderRadius(应用尺寸.圆角_胶囊)
          .animation({ duration: 80, curve: Curve.EaseOut })
          .enabled(this.可提交())
          .onTouch((事件: TouchEvent): void => {
            if (事件.type === TouchType.Down) {
              this.已按下保存 = true;
            } else if (事件.type === TouchType.Up || 事件.type === TouchType.Cancel) {
              this.已按下保存 = false;
            }
          })
          .onClick(() => { this.提交带像素图(); })
      }
      .width('88%')
      .height('88%')
      .constraintSize({ maxWidth: 480 })
      .padding(应用尺寸.卡片内边距)
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

      if (this.裁剪模式) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.85)')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        Column({ space: 应用尺寸.间距_12 }) {
          Text($r('app.string.deck_customize_background_crop_title'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.deck_customize_background_crop_hint'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          if (this.预览宽度 > 0 && this.预览高度 > 0 && this.待裁剪Uri !== '') {
            Column() {
              IBestImageCropper({
                componentWidth: this.预览宽度,
                componentHeight: this.预览高度 * 3,
                url: this.待裁剪Uri,
                shape: 'rect',
                centerWidth: this.预览宽度,
                centerHeight: this.预览高度,
                showBorder: true,
                bdColor: this.动作主色,
                maxScale: 4,
                enableRotate: false,
                controller: this.裁剪器控制器
              })
            }
            .width('100%')
            .height(this.预览高度 * 3)
          }

          Row({ space: 应用尺寸.间距_8 }) {
            Button($r('app.string.deck_customize_background_crop_cancel'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_按钮)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
              .borderRadius(应用尺寸.圆角_胶囊)
              .onClick(() => { this.取消裁剪(); })
            Button($r('app.string.deck_customize_background_crop_confirm'))
              .type(ButtonType.Normal)
              .layoutWeight(1)
              .height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_按钮)
              .fontColor($r('app.color.action_on_primary'))
              .backgroundColor(this.主色按钮背景)
              .borderRadius(应用尺寸.圆角_胶囊)
              .onClick(() => { this.应用裁剪(); })
          }
          .width('100%')
        }
        .width('92%')
        .height('88%')
        .constraintSize({ maxWidth: 560 })
        .padding(应用尺寸.卡片内边距)
        .backgroundColor($r('app.color.surface_card'))
        .borderRadius(应用尺寸.圆角_卡片)
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
