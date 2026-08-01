// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 许可证面板 {
  @Prop isDark: boolean = false;
  onClose: () => void = (): void => {
  };
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';

  @Builder
  private 许可证段落(标题: Resource, 正文: Resource) {
    Column({ space: 应用尺寸.间距_4 }) {
      Text(标题)
        .fontSize(应用尺寸.字号_按钮)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(正文)
        .fontSize(应用尺寸.字号_正文_中)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private 许可证正文(正文: Resource) {
    Text(正文)
      .fontSize(应用尺寸.字号_正文_中)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
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
          this.onClose();
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: 应用尺寸.间距_12 }) {
        Row() {
          Text($r('app.string.licenses_title'))
            .fontSize(应用尺寸.字号_面板标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text($r('app.string.licenses_confirm'))
            .fontSize(应用尺寸.字号_强调)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.动作主色)
            .padding({
              left: 应用尺寸.页面内边距_水平,
              right: 应用尺寸.间距_4,
              top: 应用尺寸.间距_8,
              bottom: 应用尺寸.间距_8
            })
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        Scroll() {
          Column({ space: 应用尺寸.间距_16 }) {
            this.许可证段落($r('app.string.licenses_overview_section'),
              $r('app.string.licenses_overview_body'))
            this.许可证段落($r('app.string.licenses_app_section'),
              $r('app.string.licenses_app_body'))
            this.许可证段落($r('app.string.licenses_source_section'),
              $r('app.string.licenses_source_body'))
            this.许可证段落($r('app.string.licenses_rights_section'),
              $r('app.string.licenses_rights_body'))
            this.许可证段落($r('app.string.licenses_third_section'),
              $r('app.string.licenses_third_anki'))
            this.许可证正文($r('app.string.licenses_third_rust'))
            this.许可证正文($r('app.string.licenses_third_ibestui'))
            this.许可证段落($r('app.string.licenses_trademark_section'),
              $r('app.string.licenses_trademark_body'))
            this.许可证段落($r('app.string.licenses_disclaimer_section'),
              $r('app.string.licenses_disclaimer_body'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('88%')
      .constraintSize({ maxWidth: 480 })
      .height('88%')
      .padding(应用尺寸.卡片内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_面板)
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
    }
    .width('100%')
    .height('100%')
  }
}
