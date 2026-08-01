// SPDX-License-Identifier: AGPL-3.0-or-later

import { pasteboard } from '@kit.BasicServicesKit';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct AnkiWeb引导对话框 {
  isDark: boolean = false;
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  onClose: () => void = (): void => {};
  private readonly 网址: string = 'https://ankiweb.net/shared/decks';

  private async 复制网址(): Promise<void> {
    try {
      const 剪贴数据: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.网址);
      const 系统剪贴板: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await 系统剪贴板.setData(剪贴数据);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.ankiweb_guide_copied')
      });
    } catch (错误) {
    }
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
        .onClick(() => {
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: 应用尺寸.间距_12 }) {
        Text($r('app.string.ankiweb_guide_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text($r('app.string.ankiweb_guide_message'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .lineHeight(20)

        Text($r('app.string.ankiweb_guide_url_label'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ top: 应用尺寸.间距_4 })

        Text(this.网址)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.action_primary'))
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)

        Text($r('app.string.ankiweb_guide_notice'))
          .fontSize(应用尺寸.字号_说明)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .margin({ top: 应用尺寸.间距_4 })

        Row({ space: 应用尺寸.间距_12 }) {
          Button($r('app.string.ankiweb_guide_button_copy'))
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.action_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .onClick(() => { this.复制网址(); })

          Button($r('app.string.ankiweb_guide_button_ok'))
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.主色按钮背景)
            .borderRadius(应用尺寸.圆角_面板)
            .onClick(() => { this.onClose(); })
        }
        .width('100%')
        .margin({ top: 应用尺寸.间距_8 })
      }
      .width('85%')
      .constraintSize({ maxWidth: 480 })
      .padding(应用尺寸.间距_16)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
      .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
          .animation({ curve: Curve.EaseOut, duration: 200 }),
        TransitionEffect.opacity(0).combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: Curve.EaseIn, duration: 160 })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
