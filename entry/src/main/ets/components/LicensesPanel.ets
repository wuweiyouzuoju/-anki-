import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';

// 开源许可与第三方声明面板：应用许可、源码获取、用户权利、第三方组件与免责。
@Component
export struct LicensesPanel {
  @Prop isDark: boolean = false;
  onClose: () => void = (): void => {
  };
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';

  @Builder
  private licenseSection(title: Resource, body: Resource) {
    Column({ space: AppDimens.SPACE_4 }) {
      Text(title)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(AppDimens.FONT_BODY_M)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private licenseBody(body: Resource) {
    Text(body)
      .fontSize(AppDimens.FONT_BODY_M)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDark ? 'rgba(0,0,0,0.40)' : 'rgba(0,0,0,0.15)')
        // 磨砂玻璃质感：模糊下层内容避免叠字，材质着色跟随应用内主题（思路参考：华为开发者文档 backgroundBlurStyle）
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        // 遮罩扩展进安全区，否则状态栏/导航条区域露出下层背景
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => {
          this.onClose();
        })
        // 过渡仅动 opacity/translate/scale 合成属性，不触发布局（思路参考：华为官方 TransitionEffect 示例）
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: AppDimens.SPACE_12 }) {
        Row() {
          Text($r('app.string.licenses_title'))
            .fontSize(AppDimens.FONT_PANEL_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text($r('app.string.licenses_confirm'))
            .fontSize(AppDimens.FONT_EMPHASIS)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.actionPrimaryColor)
            .padding({
              left: AppDimens.PAGE_PADDING_H,
              right: AppDimens.SPACE_4,
              top: AppDimens.SPACE_8,
              bottom: AppDimens.SPACE_8
            })
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        Scroll() {
          Column({ space: AppDimens.SPACE_16 }) {
            this.licenseSection($r('app.string.licenses_app_section'),
              $r('app.string.licenses_app_body'))
            this.licenseSection($r('app.string.licenses_source_section'),
              $r('app.string.licenses_source_body'))
            this.licenseSection($r('app.string.licenses_rights_section'),
              $r('app.string.licenses_rights_body'))
            this.licenseSection($r('app.string.licenses_third_section'),
              $r('app.string.licenses_third_anki'))
            this.licenseBody($r('app.string.licenses_third_rust'))
            this.licenseBody($r('app.string.licenses_third_ibestui'))
            this.licenseSection($r('app.string.licenses_trademark_section'),
              $r('app.string.licenses_trademark_body'))
            this.licenseSection($r('app.string.licenses_disclaimer_section'),
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
      .padding(AppDimens.CARD_PADDING)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_PANEL)
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
