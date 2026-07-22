// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';
import { DeckConfigForm } from '../model/DeckConfigForm';
import { DeckOptionsEdit } from '../model/DeckOptionsEdit';
import { FieldHelpPanel } from './FieldHelpPanel';
import { AdvancedDeckOptionsPanel } from './AdvancedDeckOptionsPanel';
import type { ValidationIssue } from '../model/DeckConfigForm';

interface DeckEnumOption { value: Resource; numericValue: number; }

/**
 * 牌组选项面板：常用 4 项（每日新卡上限/每日复习上限/学习步幅/复习排序顺序）直接平铺；
 * 其余全部进入「高级设置」全屏磨砂覆盖层（AdvancedDeckOptionsPanel）。
 * form/options 为引用共享，高级设置编辑后回到本面板统一保存。
 */
@Component
export struct DeckOptionsPanel {
  @Prop isDark: boolean = false;
  @Prop deckName: string = '';
  @ObjectLink form: DeckConfigForm;
  @ObjectLink options: DeckOptionsEdit;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  onCancel: () => void = (): void => {};
  onSave: (form: DeckConfigForm, options: DeckOptionsEdit) => void = (_form: DeckConfigForm, _options: DeckOptionsEdit): void => {};

  @State private showAdvanced: boolean = false;
  @State private showHelp: boolean = false;
  @State private helpTitle: Resource = $r('app.string.deck_learn_steps');
  @State private helpBody: Resource = $r('app.string.deck_learn_steps_help');
  @State private submitError: string = '';
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @State private savePressed: boolean = false;

  private openHelp(title: Resource, body: Resource): void { this.helpTitle = title; this.helpBody = body; this.showHelp = true; }
  private canSubmit(): boolean { return !this.busy && this.form.validate().length === 0 && this.options.validate().length === 0; }
  private submit(): void {
    const issues: ValidationIssue[] = this.form.validate().concat(this.options.validate());
    if (issues.length > 0) {
      this.submitError = this.fieldErrorText(issues[0]);
      return;
    }
    this.submitError = '';
    this.onSave(this.form, this.options);
  }
  private fieldErrorText(issue: ValidationIssue): string {
    let resource: Resource = $r('app.string.deck_invalid_number_validation_error');
    switch (issue.messageKey) {
      case 'deck_learn_steps_validation_error': resource = $r('app.string.deck_learn_steps_validation_error'); break;
      case 'deck_relearn_steps_validation_error': resource = $r('app.string.deck_relearn_steps_validation_error'); break;
      case 'deck_limit_validation_error': resource = $r('app.string.deck_limit_validation_error'); break;
      case 'deck_retention_validation_error': resource = $r('app.string.deck_retention_validation_error'); break;
      case 'deck_range_validation_error': resource = $r('app.string.deck_range_validation_error'); break;
      case 'deck_fsrs_parameters_validation_error': resource = $r('app.string.deck_fsrs_parameters_validation_error'); break;
      case 'deck_easy_days_validation_error': resource = $r('app.string.deck_easy_days_validation_error'); break;
      case 'deck_enum_validation_error': resource = $r('app.string.deck_enum_validation_error'); break;
      case 'deck_date_validation_error': resource = $r('app.string.deck_date_validation_error'); break;
      default: resource = $r('app.string.deck_invalid_number_validation_error'); break;
    }
    return getContext(this).resourceManager.getStringSync(resource.id);
  }
  private fieldKey(label: Resource): string { if (label.id === $r('app.string.deck_newPerDay_label').id) return 'newPerDay'; if (label.id === $r('app.string.deck_reviewsPerDay_label').id) return 'reviewsPerDay'; if (label.id === $r('app.string.deck_learnSteps_label').id) return 'learnSteps'; if (label.id === $r('app.string.deck_relearnSteps_label').id) return 'relearnSteps'; if (label.id === $r('app.string.deck_newPerDayMinimum_label').id) return 'newPerDayMinimum'; if (label.id === $r('app.string.deck_graduatingIntervalGood_label').id) return 'graduatingIntervalGood'; if (label.id === $r('app.string.deck_graduatingIntervalEasy_label').id) return 'graduatingIntervalEasy'; if (label.id === $r('app.string.deck_newCardInsertOrder_label').id) return 'newCardInsertOrder'; if (label.id === $r('app.string.deck_newCardGatherPriority_label').id) return 'newCardGatherPriority'; if (label.id === $r('app.string.deck_newCardSortOrder_label').id) return 'newCardSortOrder'; if (label.id === $r('app.string.deck_newMix_label').id) return 'newMix'; if (label.id === $r('app.string.deck_interdayLearningMix_label').id) return 'interdayLearningMix'; if (label.id === $r('app.string.deck_minimumLapseInterval_label').id) return 'minimumLapseInterval'; if (label.id === $r('app.string.deck_leechThreshold_label').id) return 'leechThreshold'; if (label.id === $r('app.string.deck_leechAction_label').id) return 'leechAction'; if (label.id === $r('app.string.deck_reviewOrder_label').id) return 'reviewOrder'; if (label.id === $r('app.string.deck_buryNew_label').id) return 'buryNew'; if (label.id === $r('app.string.deck_buryReviews_label').id) return 'buryReviews'; if (label.id === $r('app.string.deck_buryInterdayLearning_label').id) return 'buryInterdayLearning'; if (label.id === $r('app.string.deck_disableAutoplay_label').id) return 'disableAutoplay'; if (label.id === $r('app.string.deck_skipQuestionWhenReplayingAnswer_label').id) return 'skipQuestionWhenReplayingAnswer'; if (label.id === $r('app.string.deck_waitForAudio_label').id) return 'waitForAudio'; if (label.id === $r('app.string.deck_capAnswerTimeToSecs_label').id) return 'capAnswerTimeToSecs'; if (label.id === $r('app.string.deck_showTimer_label').id) return 'showTimer'; if (label.id === $r('app.string.deck_stopTimerOnAnswer_label').id) return 'stopTimerOnAnswer'; if (label.id === $r('app.string.deck_secondsToShowQuestion_label').id) return 'secondsToShowQuestion'; if (label.id === $r('app.string.deck_secondsToShowAnswer_label').id) return 'secondsToShowAnswer'; if (label.id === $r('app.string.deck_questionAction_label').id) return 'questionAction'; if (label.id === $r('app.string.deck_answerAction_label').id) return 'answerAction'; if (label.id === $r('app.string.deck_desiredRetention_label').id) return 'desiredRetention'; if (label.id === $r('app.string.deck_fsrsParams4_label').id) return 'fsrsParams4'; if (label.id === $r('app.string.deck_easyDaysPercentages_label').id) return 'easyDaysPercentages'; if (label.id === $r('app.string.deck_fsrsParams5_label').id) return 'fsrsParams5'; if (label.id === $r('app.string.deck_fsrsParams6_label').id) return 'fsrsParams6'; if (label.id === $r('app.string.deck_historicalRetention_label').id) return 'historicalRetention'; if (label.id === $r('app.string.deck_initialEase_label').id) return 'initialEase'; if (label.id === $r('app.string.deck_easyMultiplier_label').id) return 'easyMultiplier'; if (label.id === $r('app.string.deck_hardMultiplier_label').id) return 'hardMultiplier'; if (label.id === $r('app.string.deck_lapseMultiplier_label').id) return 'lapseMultiplier'; if (label.id === $r('app.string.deck_intervalMultiplier_label').id) return 'intervalMultiplier'; if (label.id === $r('app.string.deck_maximumReviewInterval_label').id) return 'maximumReviewInterval'; if (label.id === $r('app.string.deck_ignoreRevlogsBeforeDate_label').id) return 'ignoreRevlogsBeforeDate'; if (label.id === $r('app.string.deck_reviewLimit_label').id) return 'reviewLimit'; if (label.id === $r('app.string.deck_newLimit_label').id) return 'newLimit'; if (label.id === $r('app.string.deck_reviewToday_label').id) return 'reviewToday'; if (label.id === $r('app.string.deck_newToday_label').id) return 'newToday'; if (label.id === $r('app.string.deck_desiredRetentionOverride_label').id) return 'desiredRetentionOverride'; return ''; }
  private issues(): ValidationIssue[] { const out: ValidationIssue[] = []; if (this.form !== null) out.push(...this.form.validate()); if (this.options !== null) out.push(...this.options.validate()); return out; }
  private hasFieldError(key: string): boolean { return this.issues().some((issue: ValidationIssue): boolean => issue.key === key); }
  private fieldError(key: string): Resource { const issue: ValidationIssue | undefined = this.issues().find((item: ValidationIssue): boolean => item.key === key); if (issue === undefined) return $r('app.string.deck_invalid_number_validation_error'); switch (issue.messageKey) { case 'deck_learn_steps_validation_error': return $r('app.string.deck_learn_steps_validation_error'); case 'deck_relearn_steps_validation_error': return $r('app.string.deck_relearn_steps_validation_error'); case 'deck_limit_validation_error': return $r('app.string.deck_limit_validation_error'); case 'deck_retention_validation_error': return $r('app.string.deck_retention_validation_error'); case 'deck_range_validation_error': return $r('app.string.deck_range_validation_error'); case 'deck_fsrs_parameters_validation_error': return $r('app.string.deck_fsrs_parameters_validation_error'); case 'deck_easy_days_validation_error': return $r('app.string.deck_easy_days_validation_error'); case 'deck_enum_validation_error': return $r('app.string.deck_enum_validation_error'); case 'deck_date_validation_error': return $r('app.string.deck_date_validation_error'); default: return $r('app.string.deck_invalid_number_validation_error'); } }

  // 复习排序顺序选项列表（13 项，对齐 rslib ReviewOrder 枚举）
  private reviewOrderOptions(): DeckEnumOption[] {
    return [
      { value: $r('app.string.deck_opt_day'), numericValue: 0 },
      { value: $r('app.string.deck_opt_day_deck'), numericValue: 1 },
      { value: $r('app.string.deck_opt_deck_day'), numericValue: 2 },
      { value: $r('app.string.deck_opt_interval_asc'), numericValue: 3 },
      { value: $r('app.string.deck_opt_interval_desc'), numericValue: 4 },
      { value: $r('app.string.deck_opt_ease_asc'), numericValue: 5 },
      { value: $r('app.string.deck_opt_ease_desc'), numericValue: 6 },
      { value: $r('app.string.deck_opt_retr_asc'), numericValue: 7 },
      { value: $r('app.string.deck_opt_random'), numericValue: 8 },
      { value: $r('app.string.deck_opt_added'), numericValue: 9 },
      { value: $r('app.string.deck_opt_reverse_added'), numericValue: 10 },
      { value: $r('app.string.deck_opt_retr_desc'), numericValue: 11 },
      { value: $r('app.string.deck_opt_relative'), numericValue: 12 }
    ];
  }
  // Resource 转 string：bindMenu 的 MenuElement.value 只接受 string，无法直接传 Resource
  private resolveText(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource.id); }
  private reviewOrderLabelString(value: number): string {
    const options = this.reviewOrderOptions();
    for (let i = 0; i < options.length; i++) {
      if (options[i].numericValue === value) return this.resolveText(options[i].value);
    }
    return options.length > 0 ? this.resolveText(options[0].value) : '';
  }
  // bindMenu 菜单项：当前选中项前加 ✓ 标记，让用户在弹出的菜单里能识别当前值
  private reviewOrderMenuItems(selected: number): MenuElement[] {
    const options = this.reviewOrderOptions();
    const out: MenuElement[] = [];
    for (let i = 0; i < options.length; i++) {
      const labelStr: string = this.resolveText(options[i].value);
      const numericValue: number = options[i].numericValue;
      out.push({
        value: numericValue === selected ? '✓ ' + labelStr : labelStr,
        action: (): void => {
          if (this.form !== null) {
            this.form.setNumber('reviewOrder', numericValue.toString());
          }
        }
      });
    }
    return out;
  }

  @Builder
  private labeledInput(label: Resource, text: string, onChange: (value: string) => void, info: Resource) {
    Column({ space: AppDimens.SPACE_5 }) {
      Row() {
        Text(label).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button($r('app.string.field_help_button')).type(ButtonType.Normal).backgroundColor(Color.Transparent).fontColor(this.actionPrimaryColor).onClick(() => this.openHelp(label, info))
      }.width('100%')
      TextInput({ text }).width('100%').height(AppDimens.BUTTON_HEIGHT).fontSize(AppDimens.FONT_BODY)
        .backgroundColor($r('app.color.surface_card')).borderRadius(AppDimens.RADIUS_PANEL).enabled(!this.busy).onChange(onChange)
      if (this.hasFieldError(this.fieldKey(label))) Text(this.fieldError(this.fieldKey(label))).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.error_text')).width('100%')
    }.width('100%')
  }

  // 复习排序选择器：bindMenu + Row+Text 自定义触发器
  // ArkUI Select 组件默认右侧有 ▼ 箭头且无 API 可隐藏（select.d.ts 查证），
  // 改用 bindMenu + 自定义触发器方案。触发器视觉复刻 advancedHubEntry：
  // 背景色 + 圆角 + 右侧 › 指示符，提示用户「这是个可点击展开的选择框」，无 ▼ 三角形。
  @Builder
  private reviewOrderSelector(label: Resource, selected: number, help: Resource) {
    Column({ space: AppDimens.SPACE_5 }) {
      Row() {
        Text(label).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button($r('app.string.field_help_button'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor(this.actionPrimaryColor)
          .onClick(() => this.openHelp(label, help))
      }.width('100%')
      Row() {
        Text(this.reviewOrderLabelString(selected))
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('›')
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(AppDimens.BUTTON_HEIGHT)
      .padding({ left: AppDimens.SPACE_10, right: AppDimens.SPACE_10 })
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_PANEL)
      .enabled(!this.busy)
      .bindMenu(this.reviewOrderMenuItems(selected), { placement: Placement.Bottom })
      if (this.hasFieldError(this.fieldKey(label)))
        Text(this.fieldError(this.fieldKey(label)))
          .fontSize(AppDimens.FONT_BODY_S)
          .fontColor($r('app.color.error_text'))
          .width('100%')
    }.width('100%')
  }

  // 高级设置入口：Row 行按钮，点击打开独立全屏磨砂覆盖层（不展开折叠）
  @Builder
  private advancedHubEntry() {
    Row() {
      Text($r('app.string.deck_group_advanced_hub'))
        .fontSize(AppDimens.FONT_BODY_M)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text('›')
        .fontSize(AppDimens.FONT_BODY)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(AppDimens.BUTTON_HEIGHT)
    .padding({ left: AppDimens.SPACE_10, right: AppDimens.SPACE_10 })
    .backgroundColor($r('app.color.surface_page'))
    .borderRadius(AppDimens.RADIUS_PANEL)
    .onClick(() => {
      if (!this.busy) this.showAdvanced = true;
    })
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
        .onClick(() => { if (!this.busy) this.onCancel(); })
        // 过渡仅动 opacity 合成属性，不触发布局（思路参考：华为官方 TransitionEffect 示例）
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: AppDimens.SPACE_12 }) {
        Text($r('app.string.deck_options_title')).fontSize(AppDimens.FONT_PANEL_TITLE).fontWeight(FontWeight.Bold).width('100%')
        Text(this.deckName).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.text_secondary')).width('100%')
        Scroll() {
          Column({ space: AppDimens.SPACE_8 }) {
            // 常用 4 项直接平铺（目标记忆保持率已移入高级设置的 FSRS 组）
            if (this.form !== null) {
              this.labeledInput($r('app.string.deck_newPerDay_label'), this.form.newPerDay, (value: string) => { if (this.form !== null) this.form.newPerDay = value; }, $r('app.string.deck_newPerDay_help'))
              this.labeledInput($r('app.string.deck_reviewsPerDay_label'), this.form.reviewsPerDay, (value: string) => { if (this.form !== null) this.form.reviewsPerDay = value; }, $r('app.string.deck_reviewsPerDay_help'))
              this.labeledInput($r('app.string.deck_learnSteps_label'), this.form.learnSteps, (value: string) => { if (this.form !== null) this.form.learnSteps = value; }, $r('app.string.deck_learnSteps_help'))
              this.reviewOrderSelector($r('app.string.deck_reviewOrder_label'), this.form.settings().reviewOrder, $r('app.string.deck_reviewOrder_help'))
            }
            // 高级设置入口与复习排序顺序之间拉开距离（用户要求「离远点」）
            Blank().height(AppDimens.SPACE_16)
            this.advancedHubEntry()
          }.width('100%')
        }.constraintSize({ maxHeight: '60%' }).width('100%').scrollBar(BarState.Auto)

        if (this.errorMessage !== '' || this.submitError !== '') Text(this.errorMessage !== '' ? this.errorMessage : this.submitError).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.error_text')).width('100%')

        Row({ space: AppDimens.SPACE_10 }) {
          Button($r('app.string.create_deck_cancel'))
            .layoutWeight(1)
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(AppDimens.RADIUS_PILL)
            .enabled(!this.busy)
            .onClick(() => this.onCancel())
          Button(this.busy ? $r('app.string.deck_options_saving') : $r('app.string.deck_options_save'))
            .layoutWeight(1)
            .height(AppDimens.BUTTON_HEIGHT)
            .fontSize(AppDimens.FONT_BUTTON)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.savePressed ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
            .borderRadius(AppDimens.RADIUS_PILL)
            .animation({ duration: 80, curve: Curve.EaseOut })
            .enabled(this.canSubmit())
            .onTouch((event: TouchEvent): void => {
              if (event.type === TouchType.Down) {
                this.savePressed = true;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.savePressed = false;
              }
            })
            .onClick(() => this.submit())
        }.width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 480, maxHeight: '88%' })
      .padding(AppDimens.CARD_PADDING)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(AppDimens.RADIUS_CARD)
      .onClick(() => {
        // 阻断点击穿透到遮罩
      })
      // 过渡仅动 opacity/translate/scale 合成属性，不触发布局（思路参考：华为官方 TransitionEffect 示例）
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 24 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ curve: Curve.EaseOut, duration: 240 }),
        TransitionEffect.opacity(0)
          .combine(TransitionEffect.translate({ y: 16 }))
          .animation({ curve: Curve.EaseIn, duration: 180 })
      ))

      if (this.showAdvanced) {
        AdvancedDeckOptionsPanel({
          isDark: this.isDark,
          form: this.form,
          options: this.options,
          busy: this.busy,
          onClose: (): void => { this.showAdvanced = false; }
        })
      }
      if (this.showHelp) FieldHelpPanel({ title: this.helpTitle, body: this.helpBody, onClose: () => { this.showHelp = false; } })
    }
    .width('100%')
    .height('100%')
  }
}
