// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { 取全屏转场时长, 取全屏转场曲线 } from '../utils/转场时长';

/** 选择系统文件或应用云端目录的纯展示弹窗。 */
@Component
export struct 导入来源弹窗 {
  @Prop isDark: boolean = false;
  @Prop busy: boolean = false;
  onLocal: () => void = (): void => {};
  onCloud: () => void = (): void => {};
  onClose: () => void = (): void => {};

  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.选中背景) private 选中背景色: string = '#E8EEFC';

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
        .onClick((): void => {
          if (!this.busy) this.onClose();
        })
        .transition(TransitionEffect.OPACITY.animation({
          curve: 取全屏转场曲线(), duration: 取全屏转场时长()
        }))

      Column({ space: 应用尺寸.间距_16 }) {
        Text($r('app.string.import_source_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text($r('app.string.import_source_message'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Column({ space: 应用尺寸.间距_5 }) {
          Text($r('app.string.import_source_local_title'))
            .fontSize(应用尺寸.字号_正文)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.import_source_local_description'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .padding(应用尺寸.卡片内边距)
        .backgroundColor($r('app.color.surface_page'))
        .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
        .borderRadius(应用尺寸.圆角_面板)
        .enabled(!this.busy)
        .onClick((): void => { this.onLocal(); })

        Column({ space: 应用尺寸.间距_5 }) {
          Text($r('app.string.import_source_cloud_title'))
            .fontSize(应用尺寸.字号_正文)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.动作主色)
            .width('100%')
          Text($r('app.string.import_source_cloud_description'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .padding(应用尺寸.卡片内边距)
        .backgroundColor(this.选中背景色)
        .border({ width: 应用尺寸.卡片边框, color: this.动作主色 })
        .borderRadius(应用尺寸.圆角_面板)
        .enabled(!this.busy)
        .onClick((): void => { this.onCloud(); })

        Button($r('app.string.import_source_cancel'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_page'))
          .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
          .borderRadius(应用尺寸.圆角_面板)
          .enabled(!this.busy)
          .onClick((): void => { this.onClose(); })
      }
      .width('88%')
      .constraintSize({ maxWidth: 480 })
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
