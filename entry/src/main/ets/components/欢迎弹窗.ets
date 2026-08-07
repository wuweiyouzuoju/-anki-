// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @名称 欢迎弹窗 — 首次启动欢迎+更新日志+作者的话
//
// @作用
// 用户首次打开应用时显示，介绍此次更新改动 / 作者的话（含同系列应用跳转 + 评论入口）
// 样式复刻 jidecube WelcomePanel：磨砂玻璃遮罩 + 白色内容卡 + 圆角阴影
//
// @输入
// onClose: 关闭回调（首页负责调 标记已展示欢迎弹窗 持久化「已显示」标记）
//
// @输出
// 无（通过 onClose 回调关闭）
//
// @业务规则
// 文案走 string.json 资源（welcome_* key），便于 i18n 与后续调整
// Section 2、3 因含可点击跳转的 Span，文案在代码内拼接（资源文件无法绑事件）
// 点击遮罩 / 点击「开始体验」按钮 / 点击右上角 × 均可关闭
//
// @副作用
// 点击同系列应用名 / 「评论」时调 startAbility 跳转应用市场详情页（失败静默）
// 点击 ankiweb.net 链接时调 startAbility 跳转浏览器（失败静默）
// ========================================================

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 取全屏转场时长, 取全屏转场曲线 } from '../utils/转场时长';
import { 颜色键 } from '../model/颜色主题';

@Component
export struct 欢迎弹窗 {
  onClose: () => void = () => {};
  @Prop 是否深色: boolean = false;
  // 跟随用户选择的颜色主题（与首页"创建牌组"按钮同款绑定）
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景色: string = '#2F5FD0';

  // 同系列应用 + 本应用包名（用于跳转应用市场详情页）
  private static readonly 包名_记得卡片: string = 'com.jide.kapian';
  private static readonly 包名_记得魔方: string = 'com.jide.cube';
  private static readonly 包名_记得舒尔特: string = 'com.example.schultetable';
  // AnkiWeb 共享牌组页面（点击「获取牌组」Section 的蓝色链接时跳转）
  private static readonly 网址_获取牌组: string = 'https://ankiweb.net/shared/decks/';
  // 官方 QQ 群号（方式 2 获取牌组渠道，长按可选中复制）
  private static readonly QQ群号: string = '726837065';

  build() {
    Stack() {
      // 遮罩 + 磨砂玻璃（点击空白处关闭）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.是否深色 ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))
        .onClick(() => this.onClose())

      // 内容卡（居中，最大宽度 380）
      Column() {
        // 标题栏：标题居中 + × 右上角
        Stack({ alignContent: Alignment.End }) {
          Text($r('app.string.welcome_title'))
            .fontSize(应用尺寸.字号_分区标题)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Center)
          Text('×')
            .fontSize(应用尺寸.字号_卡片标题)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 8, top: 4, right: 4, bottom: 4 })
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 20, bottom: 12 })

        Divider().color($r('app.color.surface_card')).strokeWidth(1)

        // Section 1：此次更新改动
        Column({ space: 4 }) {
          Text($r('app.string.welcome_section1_title'))
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.welcome_section1_body'))
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })

        Divider().color($r('app.color.surface_card')).strokeWidth(1)

        // Section 2：获取牌组（方式1 ankiweb 链接 + 方式2 QQ 群号可长按选中复制）
        Column({ space: 6 }) {
          Text($r('app.string.welcome_section2_title'))
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          // 方式 1：ankiweb.net 链接可点击跳转浏览器
          Text() {
            Span($r('app.string.welcome_section2_way1_label'))
            Span('ankiweb.net/shared/decks')
              .fontColor($r('app.color.action_primary'))
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.跳转网页(欢迎弹窗.网址_获取牌组))
            Span($r('app.string.welcome_section2_body'))
          }
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          // 方式 2：QQ 群号可长按选中复制（copyOption On 启用整段文本选择）
          Text() {
            Span($r('app.string.welcome_section2_way2_label'))
            Span($r('app.string.welcome_section2_qq_prefix'))
            Span(欢迎弹窗.QQ群号)
              .fontColor($r('app.color.action_primary'))
              .fontWeight(FontWeight.Bold)
            Span($r('app.string.welcome_section2_qq_suffix'))
          }
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .copyOption(CopyOptions.LocalDevice)
          .width('100%')
          // 提示：获取牌组方式可在设置-关于中再次查看
          Text($r('app.string.welcome_section2_hint'))
            .fontSize(应用尺寸.字号_正文_中)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })

        Divider().color($r('app.color.surface_card')).strokeWidth(1)

        // Section 3：作者的话（含可点击的同系列应用名 + 「评论」入口，点击跳转应用市场详情页）
        Column({ space: 4 }) {
          Text($r('app.string.welcome_section3_title'))
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text() {
            Span('同系列的')
            Span('【记得魔方】')
              .fontColor($r('app.color.action_primary'))
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.跳转应用(欢迎弹窗.包名_记得魔方))
            Span('、【记得舒尔特】')
              .fontColor($r('app.color.action_primary'))
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.跳转应用(欢迎弹窗.包名_记得舒尔特))
            Span('，同样是无广无会员的纯净软件，同样欢迎大家下载使用。目前用户不到百来人，每一份好评与建议反馈都是对开发者最好的礼物。有任何建议可以在应用市场直接')
            Span('评论')
              .fontColor($r('app.color.action_primary'))
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.跳转应用(欢迎弹窗.包名_记得卡片))
          }
          .fontSize(应用尺寸.字号_正文_中)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 14, bottom: 18 })

        // 底部「开始体验」按钮
        Row() {
          Button($r('app.string.welcome_btn_start'))
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.主色按钮背景色)
            .fontColor($r('app.color.action_on_primary'))
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 4, bottom: 20 })
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, maxHeight: '88%' })
      .backgroundColor($r('app.color.surface_page'))
      .borderRadius(应用尺寸.圆角_卡片)
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }),
        TransitionEffect.opacity(0)
          .animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() })
      ))
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  // 跳转应用市场详情页：用 store:// scheme 隐式拉起应用市场；失败静默忽略
  private 跳转应用(包名: string): void {
    try {
      const 上下文 = getContext(this) as common.UIAbilityContext;
      上下文.startAbility({
        uri: `store://appgallery.huawei.com/app/detail?id=${包名}`
      }).catch((_错误: BusinessError) => {
        // 应用市场不可用或未上架时静默忽略，不阻塞用户体验
      });
    } catch (_错误) {
      // startAbility 同步抛出时静默忽略
    }
  }

  // 跳转网页：用 ohos.want.action.viewData 隐式拉起浏览器；失败静默忽略
  private 跳转网页(url: string): void {
    try {
      const 上下文 = getContext(this) as common.UIAbilityContext;
      上下文.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      }).catch((_错误: BusinessError) => {
        // 无浏览器可用时静默忽略，不阻塞用户体验
      });
    } catch (_错误) {
      // startAbility 同步抛出时静默忽略
    }
  }
}
