// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { 打开应用内好评 } from '../utils/好评引导';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 好评引导对话框 {
  isDark: boolean = false;
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  onClose: () => void = (): void => {};
  private readonly 本应用包名: string = 'com.jide.kapian';
  private readonly 反馈邮箱: string = 'wuweiyouzuoju@proton.me';

  private 取能力上下文(): common.UIAbilityContext | null {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return 上下文 === undefined ? null : 上下文;
  }

  private 去好评(): void {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 !== null) {
      打开应用内好评(上下文, this.本应用包名);
    }
    this.onClose();
  }

  private async 复制反馈邮箱(): Promise<void> {
    try {
      const 剪贴数据: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.反馈邮箱);
      const 系统剪贴板: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await 系统剪贴板.setData(剪贴数据);
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.rate_guide_feedback_copied')
      });
    } catch (错误) {
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.feedback_email')
      });
    }
    this.onClose();
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
        Text($r('app.string.rate_guide_title'))
          .fontSize(应用尺寸.字号_面板标题)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Text($r('app.string.rate_guide_message'))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .lineHeight(20)

        Row({ space: 应用尺寸.间距_12 }) {
          Button($r('app.string.rate_guide_button_later'))
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface_page'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .onClick(() => { this.onClose(); })

          Button($r('app.string.rate_guide_button_feedback'))
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文)
            .fontColor($r('app.color.action_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_subtle') })
            .borderRadius(应用尺寸.圆角_面板)
            .onClick(() => { this.复制反馈邮箱(); })
        }
        .width('100%')
        .margin({ top: 应用尺寸.间距_8 })

        Button($r('app.string.rate_guide_button_rate'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(应用尺寸.按钮高度)
          .fontSize(应用尺寸.字号_正文)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.主色按钮背景)
          .borderRadius(应用尺寸.圆角_面板)
          .onClick(() => { this.去好评(); })
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
