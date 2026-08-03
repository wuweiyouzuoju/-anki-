// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @名称 好评引导对话框
//
// @作用
// 用户完成一份牌组学习回到主页后弹出的好评引导弹窗（首次完成学习后展示一次，
// 由 首页.显示好评引导一次 触发，频率由 好评引导存储 控制为「只弹一次」）。
// 用自定义 Panel 而非 AlertDialog：
//   - 三按钮设计：去好评（主）/ 意见反馈（次）/ 稀后（次）
//   - 「去好评」调 打开应用内好评（commentManager + DeepLink 降级）
//   - 「意见反馈」复制作者邮箱到剪贴板 + toast 反馈
//   - 「稀后」仅关闭弹窗
//   - 遮罩点击不关闭：强制用户点按钮确认，避免误触跳过引导
// 样式与 AnkiWeb引导对话框 / 创建牌组面板 等弹窗一致：磨砂遮罩 + surface_card 卡片。
//
// @输入
// isDark: 是否深色主题（控制遮罩色与磨砂风格）
//
// @输出
// onClose: 用户点任一按钮时回调（点遮罩不触发）
//
// @业务规则
// 任一按钮点击都触发 onClose，由 首页 负责标记已展示（参考 AnkiWeb引导对话框 模式）。
// 反馈邮箱复用现有 feedback_email 资源（wuweiyouzuoju@proton.me）。
// 包名 com.jide.kapian 与 设置面板.本应用包名 同款字面量，作为 DeepLink 协议字段保留英文。
// pasteboard / commentManager 为 HarmonyOS 系统能力 API，保留英文。
//
// @副作用
// 点「去好评」调 startAbility（系统级副作用）；
// 点「意见反馈」调用 pasteboard 系统剪贴板（系统级副作用），失败静默。
// ========================================================

import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { 打开应用内好评 } from '../utils/好评引导';
import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { 取全屏转场时长, 取全屏转场曲线 } from '../utils/转场时长';

@Component
export struct 好评引导对话框 {
  isDark: boolean = false;
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  onClose: () => void = (): void => {};
  // 本应用 bundleName，用于拼接应用市场 DeepLink（与 设置面板.本应用包名 同款字面量）
  private readonly 本应用包名: string = 'com.jide.kapian';
  // 反馈邮箱（与 设置面板 关于分组反馈子项同款字面量，资源 key 复用 feedback_email）
  private readonly 反馈邮箱: string = 'wuweiyouzuoju@proton.me';

  private 取能力上下文(): common.UIAbilityContext | null {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    return 上下文 === undefined ? null : 上下文;
  }

  // ========================================================
  // @名称 去好评
  //
  // @作用
  // 点「去好评」按钮：调 打开应用内好评 走 DeepLink 跳华为应用市场详情页。随后关闭引导弹窗。
  //
  // @副作用
  // 调 startAbility（DeepLink 拉起应用市场）；触发 onClose。
  // ========================================================
  private 去好评(): void {
    const 上下文: common.UIAbilityContext | null = this.取能力上下文();
    if (上下文 !== null) {
      打开应用内好评(上下文, this.本应用包名);
    }
    this.onClose();
  }

  // ========================================================
  // @名称 复制反馈邮箱
  //
  // @作用
  // 点「意见反馈」按钮：把作者邮箱写入系统剪贴板 + toast 反馈，随后关闭引导弹窗。
  // 复制失败静默；用户仍可长按邮箱文本手动选中复制（本弹窗未显示邮箱，故失败时 toast 提示）。
  //
  // @副作用
  // 调 pasteboard 系统剪贴板；触发 onClose。
  // ========================================================
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
      // 复制失败时仍 toast 提示邮箱地址，用户可手动抄录
      this.getUIContext().getPromptAction().showToast({
        message: $r('app.string.feedback_email')
      });
    }
    this.onClose();
  }

  build() {
    Stack() {
      // 遮罩 + 磨砂（与 AnkiWeb引导对话框 等弹窗一致）
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
          // 点遮罩不关闭：强制用户点按钮确认，避免误触跳过引导
        })
        .transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))

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

        // 三按钮设计：去好评（主）/ 意见反馈（次）/ 稀后（次）
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
