import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';

// 开始学习主按钮：主屏窄屏底部与详情pane共用。
// B 方案（2026-07-22）：按下时用 actionPrimaryActive（深一档）给出视觉反馈。
// 渐变方案（2026-07-22）：默认状态用 linearGradient 从 primary（顶部）到 primaryActive（底部），
// 让主操作按钮有"立体凸起"质感；按下时整体切到 primaryActive 纯色（linearGradient 两端同色 = 纯色），
// 视觉上按钮"被按下凹陷"。渐变方向 180°（从上到下）模拟自然光源。
@Component
export struct StartStudyButton {
  @Prop pendingCount: number = 0;
  onStart: () => void = (): void => {
  };
  // 跟随用户选择的颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @State private pressed: boolean = false;

  build() {
    Button() {
      Row() {
        Text($r('app.string.start_study'))
          .fontSize(AppDimens.FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.action_on_primary'))
        Blank()
        Text($r('app.string.card_pending_short', this.pendingCount))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.action_on_primary'))
      }
      .width('100%')
      .padding({ left: AppDimens.SPACE_8, right: AppDimens.SPACE_8 })
    }
    .width('100%')
    .height(AppDimens.CTA_HEIGHT)
    .padding({ left: AppDimens.CARD_PADDING, right: AppDimens.CARD_PADDING })
    .linearGradient({
      angle: 180,
      colors: this.pressed
        ? [[this.actionPrimaryActiveColor as ResourceColor, 0.0], [this.actionPrimaryActiveColor as ResourceColor, 1.0]]
        : [[this.actionPrimaryColor as ResourceColor, 0.0], [this.actionPrimaryActiveColor as ResourceColor, 1.0]]
    })
    .borderRadius(AppDimens.RADIUS_CTA)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      // 按下时整体切到 active 色（深一档）模拟"凹陷"，抬起/取消回到 primary→active 渐变模拟"凸起"
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      this.onStart();
    })
  }
}
