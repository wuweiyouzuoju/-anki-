// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 复习页浮动工具栏：可拖动到屏幕侧边，松手竖向吸附到最近一边。
// 主工具栏（main）：question 阶段显示「显示答案」；answer 阶段显示 4 个评分按钮。
// 辅助工具栏（aux）：question/answer 阶段都显示「埋藏 + 暂停」。
// 拖动时为横版布局（按钮横向排列，方便手指扫过预览）；
// 松手吸附后切换为竖版布局（按钮纵向排列，像侧边栏贴在屏幕边缘）。
// 位置以 vp 为单位持久化（StudyLayoutStore），未持久化时使用默认位置（main 右侧居中、aux 左侧居中）。
// 监听 display.on('change') 自动适配屏幕尺寸变化与横竖屏切换。

import { display } from '@kit.ArkUI';
import {
  loadStudyToolbarPos,
  saveStudyToolbarPos,
  StudyToolbarId,
  ToolbarPosition
} from '../model/StudyLayoutStore';
import { AppDimens } from '../utils/AppDimens';
import {
  RATING_AGAIN,
  RATING_EASY,
  RATING_GOOD,
  RATING_HARD
} from '../proto/messages/SchedulerMessages';
import {
  EDGE_MARGIN,
  TOP_RESERVED,
  BOTTOM_RESERVED,
  toolbarWidth,
  toolbarHeight,
  ToolbarId,
  SnapSide
} from '../utils/ToolbarDimens';
import {
  StudyPhase,
  SnapResult,
  clampX,
  clampY,
  snapToSide,
  inferSnapSide
} from '../utils/SnapCalculator';
import { COLOR_KEYS } from '../model/ColorTheme';

// pressedRating 用的辅助 tag（避免与 RATING_AGAIN/HARD/GOOD/EASY 冲突）
const SHOW_ANSWER_TAG: number = 100;
const BURY_TAG: number = 101;
const SUSPEND_TAG: number = 102;

@Component
export struct StudyFloatingToolbar {
  /** 工具栏标识：main=主操作；aux=辅助操作。决定默认位置和按钮内容。 */
  @Prop toolbarId: StudyToolbarId = 'main';
  /** 复习阶段：决定主工具栏显示「显示答案」还是 4 个评分按钮。 */
  @Prop phase: StudyPhase = 'question';
  /** 评分按钮文案（DescribeNextStates 返回）；为空时用 fallback。 */
  @Prop buttonTexts: string[] = [];
  /** 评分按钮兜底文案（fallbackTexts 同长度 4）。 */
  @Prop fallbackTexts: string[] = [];
  /** 暗色模式：与 StudyPage 同步，决定浮卡底色。 */
  @Prop isDark: boolean = false;

  /** 按钮回调：与 StudyPage 同名方法一一对应。 */
  onShowAnswer: () => void = (): void => {};
  onBury: () => void = (): void => {};
  onSuspend: () => void = (): void => {};
  onRate: (rating: number) => void = (rating: number): void => {};

  /** 浮动工具栏当前位置（vp，左上角坐标）。拖动时实时更新。 */
  @State private posX: number = 0;
  @State private posY: number = 0;
  /** 位置是否已从 preferences 加载完毕；未加载完不渲染，避免位置闪一下默认值。 */
  @State private posLoaded: boolean = false;
  /** 当前是否为吸附态（竖版布局）。拖动中为 false（横版），松手后为 true（竖版）。 */
  @State private snapped: boolean = true;
  /** 吸附在哪一侧。snapped=true 时有效。 */
  @State private snapSide: SnapSide = 'right';

  /** 屏幕宽高（vp），用于松手吸附和边界夹紧。 */
  private screenWidthVp: number = 0;
  private screenHeightVp: number = 0;
  /** 拖动手势起点（手指落点 vp）和对应工具栏起点（左上角 vp），用于增量计算。 */
  private dragStartFingerX: number = 0;
  private dragStartFingerY: number = 0;
  private dragStartPosX: number = 0;
  private dragStartPosY: number = 0;

  /** display.on('change') 回调引用，用于 aboutToDisappear 时 off。 */
  private displayChangeCallback: ((id: number) => void) | null = null;

  // 跟随用户选择的颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金）
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @StorageProp(COLOR_KEYS.primaryContainer) private primaryContainerColor: string = '#E8EEFC';
  @StorageProp(COLOR_KEYS.primaryBorder) private primaryBorderColor: string = '#B8CEFA';
  // 与 StudyPage 同款单状态 pressedRating：按下记 rating，松开恢复 -1。
  // 评分按钮用 RATING_AGAIN/HARD/GOOD/EASY（0/1/2/3）；showAnswer 用 SHOW_ANSWER_TAG；aux 用 BURY_TAG/SUSPEND_TAG。
  @State private pressedRating: number = -1;

  async aboutToAppear(): Promise<void> {
    this.readScreenSize();
    await this.loadInitialPosition();
    this.registerDisplayChange();
  }

  aboutToDisappear(): void {
    this.unregisterDisplayChange();
  }

  /** 同步读屏幕尺寸：display.getDefaultDisplaySync 返回 px，转 vp 后保存。 */
  private readScreenSize(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      this.screenWidthVp = px2vp(d.width);
      this.screenHeightVp = px2vp(d.height);
    } catch (error) {
      // 取不到屏幕尺寸时用一个保守值，避免除零；后续拖动夹紧按 360×720 估。
      this.screenWidthVp = 360;
      this.screenHeightVp = 720;
    }
  }

  /** 注册屏幕变化监听：旋转、分屏、窗口缩放时重新读屏幕尺寸并夹紧位置。 */
  private registerDisplayChange(): void {
    if (this.displayChangeCallback !== null) {
      return;
    }
    const cb: (id: number) => void = (_id: number): void => {
      const oldWidth: number = this.screenWidthVp;
      const oldHeight: number = this.screenHeightVp;
      this.readScreenSize();
      // 屏幕尺寸未变化时不处理（避免无谓重夹紧）
      if (this.screenWidthVp === oldWidth && this.screenHeightVp === oldHeight) {
        return;
      }
      // 按 snapSide 重新贴到对应边
      const finalW: number = toolbarWidth(this.toolbarId, this.snapped);
      const finalH: number = toolbarHeight(this.toolbarId, this.snapped, this.phase);
      if (this.snapSide === 'left') {
        this.posX = EDGE_MARGIN;
        this.posY = clampY(this.posY, this.screenHeightVp, this.toolbarId, this.snapped, this.phase);
      } else if (this.snapSide === 'right') {
        this.posX = Math.max(EDGE_MARGIN, this.screenWidthVp - finalW - EDGE_MARGIN);
        this.posY = clampY(this.posY, this.screenHeightVp, this.toolbarId, this.snapped, this.phase);
      } else if (this.snapSide === 'top') {
        this.posX = clampX(this.posX, this.screenWidthVp, this.toolbarId, this.snapped);
        this.posY = TOP_RESERVED;
      } else {  // bottom
        this.posX = clampX(this.posX, this.screenWidthVp, this.toolbarId, this.snapped);
        this.posY = Math.max(TOP_RESERVED, this.screenHeightVp - finalH - BOTTOM_RESERVED);
      }
    };
    try {
      display.on('change', cb);
      this.displayChangeCallback = cb;
    } catch (error) {
      // 监听失败不阻塞，仅丢失自动适配能力
      this.displayChangeCallback = null;
    }
  }

  private unregisterDisplayChange(): void {
    if (this.displayChangeCallback === null) {
      return;
    }
    try {
      display.off('change', this.displayChangeCallback);
    } catch (error) {
      // ignore
    }
    this.displayChangeCallback = null;
  }

  /** 加载已保存位置；没有则用默认位置（main 右侧居中、aux 左侧居中）。
   *  推断 snapSide 时综合考虑到四边的距离，最近边作为吸附侧。 */
  private async loadInitialPosition(): Promise<void> {
    const saved: ToolbarPosition | null = await loadStudyToolbarPos(this.toolbarId);
    if (saved !== null) {
      // 推断时按竖版尺寸算（与默认吸附态一致）
      const inferred = inferSnapSide(
        saved.x, saved.y,
        this.screenWidthVp, this.screenHeightVp,
        this.toolbarId, this.phase
      );
      this.snapped = inferred.snapped;
      this.snapSide = inferred.snapSide;
      this.posX = clampX(saved.x, this.screenWidthVp, this.toolbarId, this.snapped);
      this.posY = clampY(saved.y, this.screenHeightVp, this.toolbarId, this.snapped, this.phase);
    } else {
      const def: ToolbarPosition = this.defaultPosition();
      this.posX = def.x;
      this.posY = def.y;
      this.snapSide = this.toolbarId === 'main' ? 'right' : 'left';
      this.snapped = true;
    }
    this.posLoaded = true;
  }

  /** 默认位置：main 贴右侧垂直居中、aux 贴左侧垂直居中。 */
  private defaultPosition(): ToolbarPosition {
    // 默认就是吸附态（竖版）
    const w: number = toolbarWidth(this.toolbarId, true);
    const h: number = toolbarHeight(this.toolbarId, true, this.phase);
    if (this.toolbarId === 'main') {
      const pos: ToolbarPosition = {
        x: clampX(this.screenWidthVp - w - EDGE_MARGIN, this.screenWidthVp, this.toolbarId, true),
        y: clampY((this.screenHeightVp - h) / 2, this.screenHeightVp, this.toolbarId, true, this.phase)
      };
      return pos;
    }
    const pos: ToolbarPosition = {
      x: clampX(EDGE_MARGIN, this.screenWidthVp, this.toolbarId, true),
      y: clampY((this.screenHeightVp - h) / 2, this.screenHeightVp, this.toolbarId, true, this.phase)
    };
    return pos;
  }

  /** 持久化当前位置（fire-and-forget）。 */
  private persistPosition(): void {
    saveStudyToolbarPos(this.toolbarId, this.posX, this.posY);
  }

  /** PanGesture 起点：保持当前布局（不切换），仅记录手指落点和工具栏起点。
   *  松手时根据最终位置决定切换到竖版（贴左/右）或横版（贴顶/底）。 */
  private onPanStart(event: GestureEvent): void {
    this.dragStartFingerX = event.fingerList[0].localX;
    this.dragStartFingerY = event.fingerList[0].localY;
    this.dragStartPosX = this.posX;
    this.dragStartPosY = this.posY;
  }

  /** PanGesture 移动：按手指偏移量更新工具栏位置（vp）。 */
  private onPanUpdate(event: GestureEvent): void {
    const fingerXVp: number = event.fingerList[0].localX;
    const fingerYVp: number = event.fingerList[0].localY;
    const deltaX: number = fingerXVp - this.dragStartFingerX;
    const deltaY: number = fingerYVp - this.dragStartFingerY;
    this.posX = clampX(this.dragStartPosX + deltaX, this.screenWidthVp, this.toolbarId, this.snapped);
    this.posY = clampY(this.dragStartPosY + deltaY, this.screenHeightVp, this.toolbarId, this.snapped, this.phase);
  }

  /** PanGesture 结束：吸附到最近侧边（竖版）并持久化。 */
  private onPanEnd(): void {
    const result: SnapResult = snapToSide(
      this.posX, this.posY,
      this.screenWidthVp, this.screenHeightVp,
      this.toolbarId, this.phase
    );
    this.posX = result.x;
    this.posY = result.y;
    this.snapSide = result.snapSide;
    this.snapped = result.snapped;
    this.persistPosition();
  }

  /** 取评分按钮文案：优先用后端返回的 buttonTexts，否则用 fallback。 */
  private buttonTextAt(index: number): string {
    if (index < this.buttonTexts.length && this.buttonTexts[index].length > 0) {
      return this.buttonTexts[index];
    }
    if (index < this.fallbackTexts.length) {
      return this.fallbackTexts[index];
    }
    return '';
  }

  /** 浮卡底色：暗色用深蓝灰，亮色用白。 */
  private cardBgColor(): string {
    return this.isDark ? '#1E293B' : '#FFFFFF';
  }

  /** 浮卡阴影：拖动时阴影更深，静止时浅一些，提供"被拿起"的视觉反馈。 */
  private shadowStyle(): ShadowStyle {
    return ShadowStyle.OUTER_DEFAULT_MD;
  }

  @Builder
  private showAnswerButtonHorizontal() {
    Button($r('app.string.study_show_answer'))
      .width('100%')
      .height(AppDimens.CTA_HEIGHT)
      .fontSize(AppDimens.FONT_TITLE)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(this.pressedRating === SHOW_ANSWER_TAG ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
      .borderRadius(AppDimens.RADIUS_PANEL)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.pressedRating = SHOW_ANSWER_TAG; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
      })
      .onClick(() => {
        this.onShowAnswer();
      })
  }

  @Builder
  private ratingButtonHorizontal(rating: number, textColor: ResourceColor) {
    Button(this.buttonTextAt(rating))
      .layoutWeight(1)
      .height(AppDimens.CTA_HEIGHT)
      .fontSize(AppDimens.FONT_BUTTON)
      .fontColor(textColor)
      .backgroundColor(this.pressedRating === rating ? this.primaryContainerColor : $r('app.color.surface_card'))
      .border({ width: AppDimens.CARD_BORDER, color: rating === RATING_GOOD && this.pressedRating === rating ? this.actionPrimaryColor : $r('app.color.border_subtle') })
      .borderRadius(AppDimens.RADIUS_PANEL)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.pressedRating = rating; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
      })
      .onClick(() => {
        this.onRate(rating);
      })
  }

  @Builder
  private ratingRowHorizontal() {
    Row({ space: AppDimens.SPACE_8 }) {
      this.ratingButtonHorizontal(RATING_AGAIN, $r('app.color.error_text'))
      this.ratingButtonHorizontal(RATING_HARD, $r('app.color.text_primary'))
      this.ratingButtonHorizontal(RATING_GOOD, this.actionPrimaryColor)
      this.ratingButtonHorizontal(RATING_EASY, $r('app.color.text_primary'))
    }
    .width('100%')
  }

  @Builder
  private auxButtonsHorizontal() {
    Row({ space: AppDimens.SPACE_8 }) {
      Button($r('app.string.study_bury'))
        .layoutWeight(1)
        .height(AppDimens.BUTTON_HEIGHT)
        .fontSize(AppDimens.FONT_BODY_M)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(this.pressedRating === BURY_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
        .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
        .borderRadius(AppDimens.RADIUS_PANEL)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.pressedRating = BURY_TAG; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
        })
        .onClick(() => {
          this.onBury();
        })
      Button($r('app.string.study_suspend'))
        .layoutWeight(1)
        .height(AppDimens.BUTTON_HEIGHT)
        .fontSize(AppDimens.FONT_BODY_M)
        .fontColor($r('app.color.text_secondary'))
        .backgroundColor(this.pressedRating === SUSPEND_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
        .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
        .borderRadius(AppDimens.RADIUS_PANEL)
        .animation({ duration: 80, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          if (event.type === TouchType.Down) { this.pressedRating = SUSPEND_TAG; }
          else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
        })
        .onClick(() => {
          this.onSuspend();
        })
    }
    .width('100%')
  }

  @Builder
  private showAnswerButtonVertical() {
    Button({ type: ButtonType.Normal }) {
      Text($r('app.string.study_show_answer'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
    .backgroundColor(this.pressedRating === SHOW_ANSWER_TAG ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
    .borderRadius(AppDimens.RADIUS_PANEL)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.pressedRating = SHOW_ANSWER_TAG; }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
    })
    .onClick(() => {
      this.onShowAnswer();
    })
  }

  @Builder
  private ratingButtonVertical(rating: number, textColor: ResourceColor) {
    Button({ type: ButtonType.Normal }) {
      Text(this.buttonTextAt(rating))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .fontSize(AppDimens.FONT_BUTTON)
        .fontColor(textColor)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(this.pressedRating === rating ? this.primaryContainerColor : $r('app.color.surface_card'))
    .border({ width: AppDimens.CARD_BORDER, color: rating === RATING_GOOD && this.pressedRating === rating ? this.actionPrimaryColor : $r('app.color.border_subtle') })
    .borderRadius(AppDimens.RADIUS_PANEL)
    .animation({ duration: 80, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) { this.pressedRating = rating; }
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
    })
    .onClick(() => {
      this.onRate(rating);
    })
  }

  @Builder
  private ratingColumnVertical() {
    Column({ space: AppDimens.SPACE_8 }) {
      this.ratingButtonVertical(RATING_AGAIN, $r('app.color.error_text'))
      this.ratingButtonVertical(RATING_HARD, $r('app.color.text_primary'))
      this.ratingButtonVertical(RATING_GOOD, this.actionPrimaryColor)
      this.ratingButtonVertical(RATING_EASY, $r('app.color.text_primary'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private auxButtonsVertical() {
    Column({ space: AppDimens.SPACE_8 }) {
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.study_bury'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.pressedRating === BURY_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
      .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
      .borderRadius(AppDimens.RADIUS_PANEL)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.pressedRating = BURY_TAG; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
      })
      .onClick(() => {
        this.onBury();
      })
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.study_suspend'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.pressedRating === SUSPEND_TAG ? this.primaryContainerColor : $r('app.color.surface_card'))
      .border({ width: AppDimens.CARD_BORDER, color: $r('app.color.border_subtle') })
      .borderRadius(AppDimens.RADIUS_PANEL)
      .animation({ duration: 80, curve: Curve.EaseOut })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) { this.pressedRating = SUSPEND_TAG; }
        else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.pressedRating = -1; }
      })
      .onClick(() => {
        this.onSuspend();
      })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (!this.posLoaded) {
      // 位置未加载完前不渲染，避免位置闪一下默认值
      Stack() {
      }
      .width(0)
      .height(0)
    } else {
      Stack() {
        if (this.snapped) {
          // 竖版布局（吸附态）：按钮纵向排列
          Column() {
            if (this.toolbarId === 'main') {
              if (this.phase === 'question') {
                this.showAnswerButtonVertical()
              } else if (this.phase === 'answer') {
                this.ratingColumnVertical()
              }
            } else {
              if (this.phase === 'question' || this.phase === 'answer') {
                this.auxButtonsVertical()
              }
            }
          }
          .width('100%')
          .height('100%')
          .padding(AppDimens.SPACE_8)
          .backgroundColor(this.cardBgColor())
          .borderRadius(AppDimens.RADIUS_PANEL)
          .border({ width: AppDimens.CARD_BORDER, color: this.primaryBorderColor })
          .shadow(this.shadowStyle())
        } else {
          // 横版布局（拖动中）：按钮横向排列
          Column({ space: AppDimens.SPACE_8 }) {
            if (this.toolbarId === 'main') {
              if (this.phase === 'question') {
                this.showAnswerButtonHorizontal()
              } else if (this.phase === 'answer') {
                this.ratingRowHorizontal()
              }
            } else {
              if (this.phase === 'question' || this.phase === 'answer') {
                this.auxButtonsHorizontal()
              }
            }
          }
          .width('100%')
          .height('100%')
          .padding(AppDimens.SPACE_8)
          .backgroundColor(this.cardBgColor())
          .borderRadius(AppDimens.RADIUS_PANEL)
          .border({ width: AppDimens.CARD_BORDER, color: this.primaryBorderColor })
          .shadow(this.shadowStyle())
        }
      }
      // position 是绝对定位（相对父容器左上角），Stack 作占位容器不影响布局
      .width(toolbarWidth(this.toolbarId, this.snapped))
      .height(toolbarHeight(this.toolbarId, this.snapped, this.phase))
      .position({ x: this.posX, y: this.posY })
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent): void => {
            this.onPanStart(event);
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.onPanUpdate(event);
          })
          .onActionEnd((): void => {
            this.onPanEnd();
          })
      )
    }
  }
}
