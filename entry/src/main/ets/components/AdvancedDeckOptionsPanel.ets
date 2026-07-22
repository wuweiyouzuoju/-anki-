// SPDX-License-Identifier: AGPL-3.0-or-later

import { AppDimens } from '../utils/AppDimens';
import { COLOR_KEYS } from '../model/ColorTheme';
import { DeckConfigForm } from '../model/DeckConfigForm';
import { DeckOptionsEdit } from '../model/DeckOptionsEdit';
import { FieldHelpPanel } from './FieldHelpPanel';
import type { ValidationIssue } from '../model/DeckConfigForm';

interface DeckEnumOption { value: Resource; numericValue: number; }
interface DeckSelectOption { value: string; }

/**
 * 高级设置 section 折叠标题：独立子组件（非 @Builder），expanded 用 @Prop 保证响应式，
 * animateTo 才能捕获 rotate 属性变化触发旋转动画。
 */
@Component
struct SectionHeader {
  @Prop title: Resource;
  @Prop expanded: boolean = false;
  onToggle: () => void = (): void => {};

  build() {
    Column({ space: AppDimens.SPACE_8 }) {
      Row() {
        Text(this.title).fontSize(AppDimens.FONT_BODY_M).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text('▼')
          .fontSize(AppDimens.FONT_BODY)
          .fontColor($r('app.color.text_secondary'))
          .rotate({ angle: this.expanded ? 0 : -90 })
      }.width('100%').onClick(() => {
        animateTo({ duration: 150, curve: Curve.EaseOut }, () => { this.onToggle(); });
      })
    }.width('100%').padding(AppDimens.SPACE_10).backgroundColor($r('app.color.surface_page')).borderRadius(AppDimens.RADIUS_PANEL)
  }
}

/**
 * 高级设置全屏磨砂玻璃覆盖层（嵌套在 DeckOptionsPanel 之上）。
 * 与 SettingsPanel 同款全屏磨砂遮罩 + 88% 卡片。编辑引用与 DeckOptionsPanel
 * 共享（form/options），关闭后回到牌组选项页统一保存——本面板不单独落盘。
 */
@Component
export struct AdvancedDeckOptionsPanel {
  @Prop isDark: boolean = false;
  @ObjectLink form: DeckConfigForm;
  @ObjectLink options: DeckOptionsEdit;
  @Prop busy: boolean = false;
  onClose: () => void = (): void => {};

  @State private newExpanded: boolean = false;
  @State private lapsesExpanded: boolean = false;
  @State private buryingExpanded: boolean = false;
  @State private audioExpanded: boolean = false;
  @State private timerExpanded: boolean = false;
  @State private fsrsExpanded: boolean = false;
  @State private advancedExpanded: boolean = false;
  @State private deckLimitsExpanded: boolean = false;
  @State private todayLimitsExpanded: boolean = false;
  @State private showHelp: boolean = false;
  @State private helpTitle: Resource = $r('app.string.deck_learn_steps');
  @State private helpBody: Resource = $r('app.string.deck_learn_steps_help');
  @StorageProp(COLOR_KEYS.actionPrimary) private actionPrimaryColor: string = '#2F5FD0';
  @StorageProp(COLOR_KEYS.actionPrimaryActive) private actionPrimaryActiveColor: string = '#1E4FB8';
  @State private donePressed: boolean = false;

  private openHelp(title: Resource, body: Resource): void { this.helpTitle = title; this.helpBody = body; this.showHelp = true; }
  private fieldKey(label: Resource): string { if (label.id === $r('app.string.deck_newPerDay_label').id) return 'newPerDay'; if (label.id === $r('app.string.deck_reviewsPerDay_label').id) return 'reviewsPerDay'; if (label.id === $r('app.string.deck_learnSteps_label').id) return 'learnSteps'; if (label.id === $r('app.string.deck_relearnSteps_label').id) return 'relearnSteps'; if (label.id === $r('app.string.deck_newPerDayMinimum_label').id) return 'newPerDayMinimum'; if (label.id === $r('app.string.deck_graduatingIntervalGood_label').id) return 'graduatingIntervalGood'; if (label.id === $r('app.string.deck_graduatingIntervalEasy_label').id) return 'graduatingIntervalEasy'; if (label.id === $r('app.string.deck_newCardInsertOrder_label').id) return 'newCardInsertOrder'; if (label.id === $r('app.string.deck_newCardGatherPriority_label').id) return 'newCardGatherPriority'; if (label.id === $r('app.string.deck_newCardSortOrder_label').id) return 'newCardSortOrder'; if (label.id === $r('app.string.deck_newMix_label').id) return 'newMix'; if (label.id === $r('app.string.deck_interdayLearningMix_label').id) return 'interdayLearningMix'; if (label.id === $r('app.string.deck_minimumLapseInterval_label').id) return 'minimumLapseInterval'; if (label.id === $r('app.string.deck_leechThreshold_label').id) return 'leechThreshold'; if (label.id === $r('app.string.deck_leechAction_label').id) return 'leechAction'; if (label.id === $r('app.string.deck_reviewOrder_label').id) return 'reviewOrder'; if (label.id === $r('app.string.deck_buryNew_label').id) return 'buryNew'; if (label.id === $r('app.string.deck_buryReviews_label').id) return 'buryReviews'; if (label.id === $r('app.string.deck_buryInterdayLearning_label').id) return 'buryInterdayLearning'; if (label.id === $r('app.string.deck_disableAutoplay_label').id) return 'disableAutoplay'; if (label.id === $r('app.string.deck_skipQuestionWhenReplayingAnswer_label').id) return 'skipQuestionWhenReplayingAnswer'; if (label.id === $r('app.string.deck_waitForAudio_label').id) return 'waitForAudio'; if (label.id === $r('app.string.deck_capAnswerTimeToSecs_label').id) return 'capAnswerTimeToSecs'; if (label.id === $r('app.string.deck_showTimer_label').id) return 'showTimer'; if (label.id === $r('app.string.deck_stopTimerOnAnswer_label').id) return 'stopTimerOnAnswer'; if (label.id === $r('app.string.deck_secondsToShowQuestion_label').id) return 'secondsToShowQuestion'; if (label.id === $r('app.string.deck_secondsToShowAnswer_label').id) return 'secondsToShowAnswer'; if (label.id === $r('app.string.deck_questionAction_label').id) return 'questionAction'; if (label.id === $r('app.string.deck_answerAction_label').id) return 'answerAction'; if (label.id === $r('app.string.deck_desiredRetention_label').id) return 'desiredRetention'; if (label.id === $r('app.string.deck_fsrsParams4_label').id) return 'fsrsParams4'; if (label.id === $r('app.string.deck_easyDaysPercentages_label').id) return 'easyDaysPercentages'; if (label.id === $r('app.string.deck_fsrsParams5_label').id) return 'fsrsParams5'; if (label.id === $r('app.string.deck_fsrsParams6_label').id) return 'fsrsParams6'; if (label.id === $r('app.string.deck_historicalRetention_label').id) return 'historicalRetention'; if (label.id === $r('app.string.deck_initialEase_label').id) return 'initialEase'; if (label.id === $r('app.string.deck_easyMultiplier_label').id) return 'easyMultiplier'; if (label.id === $r('app.string.deck_hardMultiplier_label').id) return 'hardMultiplier'; if (label.id === $r('app.string.deck_lapseMultiplier_label').id) return 'lapseMultiplier'; if (label.id === $r('app.string.deck_intervalMultiplier_label').id) return 'intervalMultiplier'; if (label.id === $r('app.string.deck_maximumReviewInterval_label').id) return 'maximumReviewInterval'; if (label.id === $r('app.string.deck_ignoreRevlogsBeforeDate_label').id) return 'ignoreRevlogsBeforeDate'; if (label.id === $r('app.string.deck_reviewLimit_label').id) return 'reviewLimit'; if (label.id === $r('app.string.deck_newLimit_label').id) return 'newLimit'; if (label.id === $r('app.string.deck_reviewToday_label').id) return 'reviewToday'; if (label.id === $r('app.string.deck_newToday_label').id) return 'newToday'; if (label.id === $r('app.string.deck_desiredRetentionOverride_label').id) return 'desiredRetentionOverride'; return ''; }
  private issues(): ValidationIssue[] { const out: ValidationIssue[] = []; if (this.form !== null) out.push(...this.form.validate()); if (this.options !== null) out.push(...this.options.validate()); return out; }
  private hasFieldError(key: string): boolean { return this.issues().some((issue: ValidationIssue): boolean => issue.key === key); }
  private fieldError(key: string): Resource { const issue: ValidationIssue | undefined = this.issues().find((item: ValidationIssue): boolean => item.key === key); if (issue === undefined) return $r('app.string.deck_invalid_number_validation_error'); switch (issue.messageKey) { case 'deck_learn_steps_validation_error': return $r('app.string.deck_learn_steps_validation_error'); case 'deck_relearn_steps_validation_error': return $r('app.string.deck_relearn_steps_validation_error'); case 'deck_limit_validation_error': return $r('app.string.deck_limit_validation_error'); case 'deck_retention_validation_error': return $r('app.string.deck_retention_validation_error'); case 'deck_range_validation_error': return $r('app.string.deck_range_validation_error'); case 'deck_fsrs_parameters_validation_error': return $r('app.string.deck_fsrs_parameters_validation_error'); case 'deck_easy_days_validation_error': return $r('app.string.deck_easy_days_validation_error'); case 'deck_enum_validation_error': return $r('app.string.deck_enum_validation_error'); case 'deck_date_validation_error': return $r('app.string.deck_date_validation_error'); default: return $r('app.string.deck_invalid_number_validation_error'); } }
  // 官方 Select 文档：selected 仅控制菜单初始高亮，按钮文本需由 value 提供，否则框内空白。
  // value 必须传 string：传 Resource 时按钮文本不显示（AddNotePanel 用 string 正常，旧版 AdvancedDeckOptionsPanel 用 Resource 全空白）。
  // 项目已有此 Resource→string 模式：DeckOptionsPanel.fieldErrorText L59。
  private resolveText(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource.id); }
  private enumOptions(values: DeckEnumOption[]): DeckSelectOption[] { const out: DeckSelectOption[] = []; for (let i = 0; i < values.length; i++) { const item: DeckSelectOption = { value: this.resolveText(values[i].value) }; out.push(item); } return out; }
  private enumIndex(values: DeckEnumOption[], numericValue: number): number { for (let i = 0; i < values.length; i++) if (values[i].numericValue === numericValue) return i; return 0; }
  private enumLabel(values: DeckEnumOption[], numericValue: number): string { for (let i = 0; i < values.length; i++) if (values[i].numericValue === numericValue) return this.resolveText(values[i].value); return values.length > 0 ? this.resolveText(values[0].value) : this.resolveText($r('app.string.deck_opt_mix')); }
  private mixOptions(): DeckEnumOption[] { return [{ value: $r('app.string.deck_opt_mix'), numericValue: 0 }, { value: $r('app.string.deck_opt_after_reviews'), numericValue: 1 }, { value: $r('app.string.deck_opt_before_reviews'), numericValue: 2 }]; }

  @Builder
  private enumSelector(label: Resource, selected: number, values: DeckEnumOption[], onChange: (numericValue: number) => void, help: Resource) {
    Column({ space: AppDimens.SPACE_5 }) {
      Row() { Text(label).fontSize(AppDimens.FONT_BODY_S).layoutWeight(1); Button($r('app.string.field_help_button')).type(ButtonType.Normal).backgroundColor(Color.Transparent).onClick(() => this.openHelp(label, help)) }.width('100%')
      Select(this.enumOptions(values))
        .selected(this.enumIndex(values, selected))
        .value(this.enumLabel(values, selected))
        .width('100%')
        .enabled(!this.busy)
        .onSelect((index: number) => onChange(values[index].numericValue))
      if (this.hasFieldError(this.fieldKey(label))) Text(this.fieldError(this.fieldKey(label))).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.error_text')).width('100%')
    }.width('100%')
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

  @Builder
  private toggleRow(label: Resource, value: boolean, onChange: (value: boolean) => void, help: Resource) {
    Column({ space: AppDimens.SPACE_5 }) { Row() { Text(label).fontSize(AppDimens.FONT_BODY_S).layoutWeight(1); Button($r('app.string.field_help_button')).type(ButtonType.Normal).backgroundColor(Color.Transparent).onClick(() => this.openHelp(label, help)); Toggle({ type: ToggleType.Switch, isOn: value }).enabled(!this.busy).onChange(onChange) }.width('100%'); if (this.hasFieldError(this.fieldKey(label))) Text(this.fieldError(this.fieldKey(label))).fontSize(AppDimens.FONT_BODY_S).fontColor($r('app.color.error_text')).width('100%') }.width('100%')
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
        .onClick(() => { if (!this.busy) this.onClose(); })
        // 过渡仅动 opacity 合成属性，不触发布局（思路参考：华为官方 TransitionEffect 示例）
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: AppDimens.SPACE_12 }) {
        Text($r('app.string.deck_group_advanced_hub'))
          .fontSize(AppDimens.FONT_PANEL_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')

        Scroll() {
          Column({ space: AppDimens.SPACE_8 }) {
            // 顶部「每日上限」6 字段拆成两组 section（用户决策 2026-07-22）：本牌组上限 + 今日上限
            SectionHeader({ title: $r('app.string.deck_group_deck_limits'), expanded: this.deckLimitsExpanded, onToggle: () => { this.deckLimitsExpanded = !this.deckLimitsExpanded; } })
            if (this.deckLimitsExpanded && this.options !== null && this.form !== null) {
              this.labeledInput($r('app.string.deck_reviewLimit_label'), this.options.reviewLimit, (value: string) => { if (this.options !== null) this.options.reviewLimit = value; }, $r('app.string.deck_reviewLimit_help'))
              this.labeledInput($r('app.string.deck_newLimit_label'), this.options.newLimit, (value: string) => { if (this.options !== null) this.options.newLimit = value; }, $r('app.string.deck_newLimit_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_today_limits'), expanded: this.todayLimitsExpanded, onToggle: () => { this.todayLimitsExpanded = !this.todayLimitsExpanded; } })
            if (this.todayLimitsExpanded && this.options !== null && this.form !== null) {
              this.labeledInput($r('app.string.deck_reviewToday_label'), this.options.reviewToday, (value: string) => { if (this.options !== null) this.options.reviewToday = value; }, $r('app.string.deck_reviewToday_help'))
              this.toggleRow($r('app.string.deck_reviewTodayActive_label'), this.options.reviewTodayActive, (value: boolean) => { if (this.options !== null) this.options.reviewTodayActive = value; }, $r('app.string.deck_reviewTodayActive_help'))
              this.labeledInput($r('app.string.deck_newToday_label'), this.options.newToday, (value: string) => { if (this.options !== null) this.options.newToday = value; }, $r('app.string.deck_newToday_help'))
              this.toggleRow($r('app.string.deck_newTodayActive_label'), this.options.newTodayActive, (value: boolean) => { if (this.options !== null) this.options.newTodayActive = value; }, $r('app.string.deck_newTodayActive_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_new'), expanded: this.newExpanded, onToggle: () => { this.newExpanded = !this.newExpanded; } })
            if (this.newExpanded && this.form !== null) {
              this.labeledInput($r('app.string.deck_newPerDayMinimum_label'), this.form.valueText('newPerDayMinimum'), (value: string) => { if (this.form !== null) this.form.setNumber('newPerDayMinimum', value); }, $r('app.string.deck_newPerDayMinimum_help'))
              this.labeledInput($r('app.string.deck_graduatingIntervalGood_label'), this.form.valueText('graduatingIntervalGood'), (value: string) => { if (this.form !== null) this.form.setNumber('graduatingIntervalGood', value); }, $r('app.string.deck_graduatingIntervalGood_help'))
              this.labeledInput($r('app.string.deck_graduatingIntervalEasy_label'), this.form.valueText('graduatingIntervalEasy'), (value: string) => { if (this.form !== null) this.form.setNumber('graduatingIntervalEasy', value); }, $r('app.string.deck_graduatingIntervalEasy_help'))
              this.enumSelector($r('app.string.deck_newCardInsertOrder_label'), this.form.settings().newCardInsertOrder, [{ value: $r('app.string.deck_opt_due'), numericValue: 0 }, { value: $r('app.string.deck_opt_random'), numericValue: 1 }], (value: number) => { if (this.form !== null) this.form.setNumber('newCardInsertOrder', value.toString()); }, $r('app.string.deck_newCardInsertOrder_help'))
              this.enumSelector($r('app.string.deck_newCardGatherPriority_label'), this.form.settings().newCardGatherPriority, [{ value: $r('app.string.deck_opt_deck'), numericValue: 0 }, { value: $r('app.string.deck_opt_lowest_position'), numericValue: 1 }, { value: $r('app.string.deck_opt_highest_position'), numericValue: 2 }, { value: $r('app.string.deck_opt_random_notes'), numericValue: 3 }, { value: $r('app.string.deck_opt_random_cards'), numericValue: 4 }, { value: $r('app.string.deck_opt_deck_random_notes'), numericValue: 5 }], (value: number) => { if (this.form !== null) this.form.setNumber('newCardGatherPriority', value.toString()); }, $r('app.string.deck_newCardGatherPriority_help'))
              this.enumSelector($r('app.string.deck_newCardSortOrder_label'), this.form.settings().newCardSortOrder, [{ value: $r('app.string.deck_opt_template'), numericValue: 0 }, { value: $r('app.string.deck_opt_no_sort'), numericValue: 1 }, { value: $r('app.string.deck_opt_template_random'), numericValue: 2 }, { value: $r('app.string.deck_opt_random_note_template'), numericValue: 3 }, { value: $r('app.string.deck_opt_random_cards'), numericValue: 4 }], (value: number) => { if (this.form !== null) this.form.setNumber('newCardSortOrder', value.toString()); }, $r('app.string.deck_newCardSortOrder_help'))
              this.enumSelector($r('app.string.deck_newMix_label'), this.form.settings().newMix, this.mixOptions(), (value: number) => { if (this.form !== null) this.form.setNumber('newMix', value.toString()); }, $r('app.string.deck_newMix_help'))
              this.enumSelector($r('app.string.deck_interdayLearningMix_label'), this.form.settings().interdayLearningMix, this.mixOptions(), (value: number) => { if (this.form !== null) this.form.setNumber('interdayLearningMix', value.toString()); }, $r('app.string.deck_interdayLearningMix_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_lapses'), expanded: this.lapsesExpanded, onToggle: () => { this.lapsesExpanded = !this.lapsesExpanded; } })
            if (this.lapsesExpanded && this.form !== null) {
              this.labeledInput($r('app.string.deck_relearnSteps_label'), this.form.relearnSteps, (value: string) => { if (this.form !== null) this.form.relearnSteps = value; }, $r('app.string.deck_relearnSteps_help'))
              this.labeledInput($r('app.string.deck_minimumLapseInterval_label'), this.form.valueText('minimumLapseInterval'), (value: string) => { if (this.form !== null) this.form.setNumber('minimumLapseInterval', value); }, $r('app.string.deck_minimumLapseInterval_help'))
              this.labeledInput($r('app.string.deck_leechThreshold_label'), this.form.valueText('leechThreshold'), (value: string) => { if (this.form !== null) this.form.setNumber('leechThreshold', value); }, $r('app.string.deck_leechThreshold_help'))
              this.enumSelector($r('app.string.deck_leechAction_label'), this.form.settings().leechAction, [{ value: $r('app.string.deck_opt_suspend'), numericValue: 0 }, { value: $r('app.string.deck_opt_tag_only'), numericValue: 1 }], (value: number) => { if (this.form !== null) this.form.setNumber('leechAction', value.toString()); }, $r('app.string.deck_leechAction_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_burying'), expanded: this.buryingExpanded, onToggle: () => { this.buryingExpanded = !this.buryingExpanded; } })
            if (this.buryingExpanded && this.form !== null) { this.toggleRow($r('app.string.deck_buryNew_label'), this.form.settings().buryNew, (value: boolean) => { if (this.form !== null) this.form.setBoolean('buryNew', value); }, $r('app.string.deck_buryNew_help')); this.toggleRow($r('app.string.deck_buryReviews_label'), this.form.settings().buryReviews, (value: boolean) => { if (this.form !== null) this.form.setBoolean('buryReviews', value); }, $r('app.string.deck_buryReviews_help')); this.toggleRow($r('app.string.deck_buryInterdayLearning_label'), this.form.settings().buryInterdayLearning, (value: boolean) => { if (this.form !== null) this.form.setBoolean('buryInterdayLearning', value); }, $r('app.string.deck_buryInterdayLearning_help')); }
            SectionHeader({ title: $r('app.string.deck_group_audio'), expanded: this.audioExpanded, onToggle: () => { this.audioExpanded = !this.audioExpanded; } })
            if (this.audioExpanded && this.form !== null) { this.toggleRow($r('app.string.deck_disableAutoplay_label'), this.form.settings().disableAutoplay, (value: boolean) => { if (this.form !== null) this.form.setBoolean('disableAutoplay', value); }, $r('app.string.deck_disableAutoplay_help')); this.toggleRow($r('app.string.deck_skipQuestionWhenReplayingAnswer_label'), this.form.settings().skipQuestionWhenReplayingAnswer, (value: boolean) => { if (this.form !== null) this.form.setBoolean('skipQuestionWhenReplayingAnswer', value); }, $r('app.string.deck_skipQuestionWhenReplayingAnswer_help')); this.toggleRow($r('app.string.deck_waitForAudio_label'), this.form.settings().waitForAudio, (value: boolean) => { if (this.form !== null) this.form.setBoolean('waitForAudio', value); }, $r('app.string.deck_waitForAudio_help')); }
            SectionHeader({ title: $r('app.string.deck_group_timer'), expanded: this.timerExpanded, onToggle: () => { this.timerExpanded = !this.timerExpanded; } })
            if (this.timerExpanded && this.form !== null) {
              this.labeledInput($r('app.string.deck_capAnswerTimeToSecs_label'), this.form.valueText('capAnswerTimeToSecs'), (value: string) => { if (this.form !== null) this.form.setNumber('capAnswerTimeToSecs', value); }, $r('app.string.deck_capAnswerTimeToSecs_help'))
              this.toggleRow($r('app.string.deck_showTimer_label'), this.form.settings().showTimer, (value: boolean) => { if (this.form !== null) this.form.setBoolean('showTimer', value); }, $r('app.string.deck_showTimer_help'))
              this.toggleRow($r('app.string.deck_stopTimerOnAnswer_label'), this.form.settings().stopTimerOnAnswer, (value: boolean) => { if (this.form !== null) this.form.setBoolean('stopTimerOnAnswer', value); }, $r('app.string.deck_stopTimerOnAnswer_help'))
              this.labeledInput($r('app.string.deck_secondsToShowQuestion_label'), this.form.valueText('secondsToShowQuestion'), (value: string) => { if (this.form !== null) this.form.setNumber('secondsToShowQuestion', value); }, $r('app.string.deck_secondsToShowQuestion_help'))
              this.labeledInput($r('app.string.deck_secondsToShowAnswer_label'), this.form.valueText('secondsToShowAnswer'), (value: string) => { if (this.form !== null) this.form.setNumber('secondsToShowAnswer', value); }, $r('app.string.deck_secondsToShowAnswer_help'))
              this.enumSelector($r('app.string.deck_questionAction_label'), this.form.settings().questionAction, [{ value: $r('app.string.deck_opt_show_answer'), numericValue: 0 }, { value: $r('app.string.deck_opt_show_reminder'), numericValue: 1 }], (value: number) => { if (this.form !== null) this.form.setNumber('questionAction', value.toString()); }, $r('app.string.deck_questionAction_help'))
              this.enumSelector($r('app.string.deck_answerAction_label'), this.form.settings().answerAction, [{ value: $r('app.string.deck_opt_bury_card'), numericValue: 0 }, { value: $r('app.string.deck_opt_answer_again'), numericValue: 1 }, { value: $r('app.string.deck_opt_answer_good'), numericValue: 2 }, { value: $r('app.string.deck_opt_answer_hard'), numericValue: 3 }, { value: $r('app.string.deck_opt_show_reminder'), numericValue: 4 }], (value: number) => { if (this.form !== null) this.form.setNumber('answerAction', value.toString()); }, $r('app.string.deck_answerAction_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_fsrs'), expanded: this.fsrsExpanded, onToggle: () => { this.fsrsExpanded = !this.fsrsExpanded; } })
            if (this.fsrsExpanded && this.form !== null) {
              // 目标记忆保持率放在 FSRS 组顶部（与 FSRS 语义最贴近）
              this.labeledInput($r('app.string.deck_desiredRetention_label'), this.form.desiredRetention, (value: string) => { if (this.form !== null) this.form.desiredRetention = value; }, $r('app.string.deck_desiredRetention_help'))
              if (this.options !== null) { this.labeledInput($r('app.string.deck_desiredRetentionOverride_label'), this.options.desiredRetentionOverride, (value: string) => { if (this.options !== null) this.options.desiredRetentionOverride = value; }, $r('app.string.deck_desiredRetentionOverride_help')); this.toggleRow($r('app.string.deck_fsrsEnabled_label'), this.options.fsrs, (value: boolean) => { if (this.options !== null) this.options.fsrs = value; }, $r('app.string.deck_fsrsEnabled_help')); this.toggleRow($r('app.string.deck_fsrsReschedule_label'), this.options.fsrsReschedule, (value: boolean) => { if (this.options !== null) this.options.fsrsReschedule = value; }, $r('app.string.deck_fsrsReschedule_help')); this.toggleRow($r('app.string.deck_fsrsHealthCheck_label'), this.options.fsrsHealthCheck, (value: boolean) => { if (this.options !== null) this.options.fsrsHealthCheck = value; }, $r('app.string.deck_fsrsHealthCheck_help')); }
              this.labeledInput($r('app.string.deck_fsrsParams4_label'), this.form.floatArrayText('fsrsParams4'), (value: string) => { if (this.form !== null) this.form.setFloatArray('fsrsParams4', value); }, $r('app.string.deck_fsrsParams4_help')); this.labeledInput($r('app.string.deck_easyDaysPercentages_label'), this.form.floatArrayText('easyDaysPercentages'), (value: string) => { if (this.form !== null) this.form.setFloatArray('easyDaysPercentages', value); }, $r('app.string.deck_easyDaysPercentages_help')); this.labeledInput($r('app.string.deck_fsrsParams5_label'), this.form.floatArrayText('fsrsParams5'), (value: string) => { if (this.form !== null) this.form.setFloatArray('fsrsParams5', value); }, $r('app.string.deck_fsrsParams5_help')); this.labeledInput($r('app.string.deck_fsrsParams6_label'), this.form.floatArrayText('fsrsParams6'), (value: string) => { if (this.form !== null) this.form.setFloatArray('fsrsParams6', value); }, $r('app.string.deck_fsrsParams6_help')); this.labeledInput($r('app.string.deck_historicalRetention_label'), this.form.valueText('historicalRetention'), (value: string) => { if (this.form !== null) this.form.setNumber('historicalRetention', value); }, $r('app.string.deck_historicalRetention_help')); this.labeledInput($r('app.string.deck_paramSearch_label'), this.form.settings().paramSearch, (value: string) => { if (this.form !== null) this.form.setText('paramSearch', value); }, $r('app.string.deck_paramSearch_help'))
            }
            SectionHeader({ title: $r('app.string.deck_group_advanced'), expanded: this.advancedExpanded, onToggle: () => { this.advancedExpanded = !this.advancedExpanded; } })
            if (this.advancedExpanded && this.form !== null) { if (this.options !== null) { this.toggleRow($r('app.string.deck_newCardsIgnoreReviewLimit_label'), this.options.newCardsIgnoreReviewLimit, (value: boolean) => { if (this.options !== null) this.options.newCardsIgnoreReviewLimit = value; }, $r('app.string.deck_newCardsIgnoreReviewLimit_help')); this.toggleRow($r('app.string.deck_applyAllParentLimits_label'), this.options.applyAllParentLimits, (value: boolean) => { if (this.options !== null) this.options.applyAllParentLimits = value; }, $r('app.string.deck_applyAllParentLimits_help')); } this.labeledInput($r('app.string.deck_initialEase_label'), this.form.valueText('initialEase'), (value: string) => { if (this.form !== null) this.form.setNumber('initialEase', value); }, $r('app.string.deck_initialEase_help')); this.labeledInput($r('app.string.deck_easyMultiplier_label'), this.form.valueText('easyMultiplier'), (value: string) => { if (this.form !== null) this.form.setNumber('easyMultiplier', value); }, $r('app.string.deck_easyMultiplier_help')); this.labeledInput($r('app.string.deck_hardMultiplier_label'), this.form.valueText('hardMultiplier'), (value: string) => { if (this.form !== null) this.form.setNumber('hardMultiplier', value); }, $r('app.string.deck_hardMultiplier_help')); this.labeledInput($r('app.string.deck_lapseMultiplier_label'), this.form.valueText('lapseMultiplier'), (value: string) => { if (this.form !== null) this.form.setNumber('lapseMultiplier', value); }, $r('app.string.deck_lapseMultiplier_help')); this.labeledInput($r('app.string.deck_intervalMultiplier_label'), this.form.valueText('intervalMultiplier'), (value: string) => { if (this.form !== null) this.form.setNumber('intervalMultiplier', value); }, $r('app.string.deck_intervalMultiplier_help')); this.labeledInput($r('app.string.deck_maximumReviewInterval_label'), this.form.valueText('maximumReviewInterval'), (value: string) => { if (this.form !== null) this.form.setNumber('maximumReviewInterval', value); }, $r('app.string.deck_maximumReviewInterval_help')); this.labeledInput($r('app.string.deck_ignoreRevlogsBeforeDate_label'), this.form.settings().ignoreRevlogsBeforeDate, (value: string) => { if (this.form !== null) this.form.setText('ignoreRevlogsBeforeDate', value); }, $r('app.string.deck_ignoreRevlogsBeforeDate_help')); }
          }.width('100%')
        }.constraintSize({ maxHeight: '60%' }).width('100%').scrollBar(BarState.Auto)

        Button($r('app.string.done'))
          .width('100%')
          .height(AppDimens.BUTTON_HEIGHT)
          .fontSize(AppDimens.FONT_BUTTON)
          .fontColor($r('app.color.action_on_primary'))
          .backgroundColor(this.donePressed ? this.actionPrimaryActiveColor : this.actionPrimaryColor)
          .borderRadius(AppDimens.RADIUS_PILL)
          .animation({ duration: 80, curve: Curve.EaseOut })
          .enabled(!this.busy)
          .onTouch((event: TouchEvent): void => {
            if (event.type === TouchType.Down) {
              this.donePressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.donePressed = false;
            }
          })
          .onClick(() => this.onClose())
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

      if (this.showHelp) FieldHelpPanel({ title: this.helpTitle, body: this.helpBody, onClose: () => { this.showHelp = false; } })
    }
    .width('100%')
    .height('100%')
  }
}
