// SPDX-License-Identifier: AGPL-3.0-or-later

import { 应用尺寸 } from '../utils/应用尺寸';
import { 颜色键 } from '../model/颜色主题';
import { 牌组配置表单 } from '../model/牌组配置表单';
import { 牌组选项编辑 } from '../model/牌组选项编辑';
import { 字段帮助面板 } from './字段帮助面板';
import { 高级牌组选项面板 } from './高级牌组选项面板';
import type { 校验问题 } from '../model/牌组配置表单';

interface 牌组枚举选项 { value: Resource; numericValue: number; }

@Component
export struct 牌组选项面板 {
  @Prop isDark: boolean = false;
  @Prop deckName: string = '';
  @ObjectLink form: 牌组配置表单;
  @ObjectLink options: 牌组选项编辑;
  @Prop busy: boolean = false;
  @Prop errorMessage: string = '';
  onCancel: () => void = (): void => {};
  onSave: (form: 牌组配置表单, options: 牌组选项编辑) => void = (_form: 牌组配置表单, _options: 牌组选项编辑): void => {};

  @State private showAdvanced: boolean = false;
  @State private showHelp: boolean = false;
  @State private helpTitle: Resource = $r('app.string.deck_learn_steps');
  @State private helpBody: Resource = $r('app.string.deck_learn_steps_help');
  @State private submitError: string = '';
  @StorageProp(颜色键.动作主色) private 动作主色: string = '#2F5FD0';
  @StorageProp(颜色键.动作主色按下) private 动作主色按下: string = '#1E4FB8';
  @StorageProp(颜色键.主色按钮背景) private 主色按钮背景: string = '#2F5FD0';
  @StorageProp(颜色键.主色按钮按下) private 主色按钮按下: string = '#1E4FB8';
  @State private savePressed: boolean = false;
  @State private selectedReviewOrder: number = 0;

  aboutToAppear(): void {
    if (this.form !== null) {
      this.selectedReviewOrder = this.form.取配置().reviewOrder;
    }
  }

  private openHelp(title: Resource, body: Resource): void { this.helpTitle = title; this.helpBody = body; this.showHelp = true; }

  private canSubmit(): boolean { return !this.busy && this.form.校验().length === 0 && this.options.校验().length === 0; }

  private submit(): void {
    const 问题列表: 校验问题[] = this.form.校验().concat(this.options.校验());
    if (问题列表.length > 0) {
      this.submitError = this.字段错误文本(问题列表[0]);
      return;
    }
    this.submitError = '';
    this.onSave(this.form, this.options);
  }

  private 字段错误文本(issue: 校验问题): string {
    let resource: Resource = $r('app.string.deck_invalid_number_validation_error');
    switch (issue.消息键) {
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
    return this.getUIContext().getHostContext()!.resourceManager.getStringSync(resource.id);
  }

  private fieldKey(label: Resource): string { if (label.id === $r('app.string.deck_newPerDay_label').id) return 'newPerDay'; if (label.id === $r('app.string.deck_reviewsPerDay_label').id) return 'reviewsPerDay'; if (label.id === $r('app.string.deck_learnSteps_label').id) return 'learnSteps'; if (label.id === $r('app.string.deck_relearnSteps_label').id) return 'relearnSteps'; if (label.id === $r('app.string.deck_newPerDayMinimum_label').id) return 'newPerDayMinimum'; if (label.id === $r('app.string.deck_graduatingIntervalGood_label').id) return 'graduatingIntervalGood'; if (label.id === $r('app.string.deck_graduatingIntervalEasy_label').id) return 'graduatingIntervalEasy'; if (label.id === $r('app.string.deck_newCardInsertOrder_label').id) return 'newCardInsertOrder'; if (label.id === $r('app.string.deck_newCardGatherPriority_label').id) return 'newCardGatherPriority'; if (label.id === $r('app.string.deck_newCardSortOrder_label').id) return 'newCardSortOrder'; if (label.id === $r('app.string.deck_newMix_label').id) return 'newMix'; if (label.id === $r('app.string.deck_interdayLearningMix_label').id) return 'interdayLearningMix'; if (label.id === $r('app.string.deck_minimumLapseInterval_label').id) return 'minimumLapseInterval'; if (label.id === $r('app.string.deck_leechThreshold_label').id) return 'leechThreshold'; if (label.id === $r('app.string.deck_leechAction_label').id) return 'leechAction'; if (label.id === $r('app.string.deck_reviewOrder_label').id) return 'reviewOrder'; if (label.id === $r('app.string.deck_buryNew_label').id) return 'buryNew'; if (label.id === $r('app.string.deck_buryReviews_label').id) return 'buryReviews'; if (label.id === $r('app.string.deck_buryInterdayLearning_label').id) return 'buryInterdayLearning'; if (label.id === $r('app.string.deck_disableAutoplay_label').id) return 'disableAutoplay'; if (label.id === $r('app.string.deck_skipQuestionWhenReplayingAnswer_label').id) return 'skipQuestionWhenReplayingAnswer'; if (label.id === $r('app.string.deck_waitForAudio_label').id) return 'waitForAudio'; if (label.id === $r('app.string.deck_capAnswerTimeToSecs_label').id) return 'capAnswerTimeToSecs'; if (label.id === $r('app.string.deck_showTimer_label').id) return 'showTimer'; if (label.id === $r('app.string.deck_stopTimerOnAnswer_label').id) return 'stopTimerOnAnswer'; if (label.id === $r('app.string.deck_secondsToShowQuestion_label').id) return 'secondsToShowQuestion'; if (label.id === $r('app.string.deck_secondsToShowAnswer_label').id) return 'secondsToShowAnswer'; if (label.id === $r('app.string.deck_questionAction_label').id) return 'questionAction'; if (label.id === $r('app.string.deck_answerAction_label').id) return 'answerAction'; if (label.id === $r('app.string.deck_desiredRetention_label').id) return 'desiredRetention'; if (label.id === $r('app.string.deck_fsrsParams4_label').id) return 'fsrsParams4'; if (label.id === $r('app.string.deck_easyDaysPercentages_label').id) return 'easyDaysPercentages'; if (label.id === $r('app.string.deck_fsrsParams5_label').id) return 'fsrsParams5'; if (label.id === $r('app.string.deck_fsrsParams6_label').id) return 'fsrsParams6'; if (label.id === $r('app.string.deck_historicalRetention_label').id) return 'historicalRetention'; if (label.id === $r('app.string.deck_initialEase_label').id) return 'initialEase'; if (label.id === $r('app.string.deck_easyMultiplier_label').id) return 'easyMultiplier'; if (label.id === $r('app.string.deck_hardMultiplier_label').id) return 'hardMultiplier'; if (label.id === $r('app.string.deck_lapseMultiplier_label').id) return 'lapseMultiplier'; if (label.id === $r('app.string.deck_intervalMultiplier_label').id) return 'intervalMultiplier'; if (label.id === $r('app.string.deck_maximumReviewInterval_label').id) return 'maximumReviewInterval'; if (label.id === $r('app.string.deck_ignoreRevlogsBeforeDate_label').id) return 'ignoreRevlogsBeforeDate'; if (label.id === $r('app.string.deck_reviewLimit_label').id) return 'reviewLimit'; if (label.id === $r('app.string.deck_newLimit_label').id) return 'newLimit'; if (label.id === $r('app.string.deck_reviewToday_label').id) return 'reviewToday'; if (label.id === $r('app.string.deck_newToday_label').id) return 'newToday'; if (label.id === $r('app.string.deck_desiredRetentionOverride_label').id) return 'desiredRetentionOverride'; return ''; }

  private 校验问题列表(): 校验问题[] { const 输出: 校验问题[] = []; if (this.form !== null) 输出.push(...this.form.校验()); if (this.options !== null) 输出.push(...this.options.校验()); return 输出; }
  private 是否有字段错误(key: string): boolean { return this.校验问题列表().some((issue: 校验问题): boolean => issue.字段键 === key); }
  private 字段错误资源(key: string): Resource { const issue: 校验问题 | undefined = this.校验问题列表().find((item: 校验问题): boolean => item.字段键 === key); if (issue === undefined) return $r('app.string.deck_invalid_number_validation_error'); switch (issue.消息键) { case 'deck_learn_steps_validation_error': return $r('app.string.deck_learn_steps_validation_error'); case 'deck_relearn_steps_validation_error': return $r('app.string.deck_relearn_steps_validation_error'); case 'deck_limit_validation_error': return $r('app.string.deck_limit_validation_error'); case 'deck_retention_validation_error': return $r('app.string.deck_retention_validation_error'); case 'deck_range_validation_error': return $r('app.string.deck_range_validation_error'); case 'deck_fsrs_parameters_validation_error': return $r('app.string.deck_fsrs_parameters_validation_error'); case 'deck_easy_days_validation_error': return $r('app.string.deck_easy_days_validation_error'); case 'deck_enum_validation_error': return $r('app.string.deck_enum_validation_error'); case 'deck_date_validation_error': return $r('app.string.deck_date_validation_error'); default: return $r('app.string.deck_invalid_number_validation_error'); } }

  private reviewOrderOptions(): 牌组枚举选项[] {
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
  private resolveText(resource: Resource): string { return this.getUIContext().getHostContext()!.resourceManager.getStringSync(resource.id); }
  private reviewOrderLabelString(value: number): string {
    const 选项 = this.reviewOrderOptions();
    for (let i = 0; i < 选项.length; i++) {
      if (选项[i].numericValue === value) return this.resolveText(选项[i].value);
    }
    return 选项.length > 0 ? this.resolveText(选项[0].value) : '';
  }

  @Builder
  private labeledInput(label: Resource, text: string, onChange: (value: string) => void, info: Resource) {
    Column({ space: 应用尺寸.间距_5 }) {
      Row() {
        Text(label).fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button($r('app.string.field_help_button')).type(ButtonType.Normal).backgroundColor(Color.Transparent).fontColor(this.动作主色).onClick(() => this.openHelp(label, info))
      }.width('100%')
      TextInput({ text }).width('100%').height(应用尺寸.按钮高度).fontSize(应用尺寸.字号_正文)
        .backgroundColor($r('app.color.surface_card')).border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') }).borderRadius(应用尺寸.圆角_面板).enabled(!this.busy).onChange(onChange)
      if (this.是否有字段错误(this.fieldKey(label))) Text(this.resolveText(this.字段错误资源(this.fieldKey(label)))).fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.error_text')).width('100%')
    }.width('100%')
  }

  @Builder
  private reviewOrderSelector(label: Resource, selected: number, help: Resource) {
    Column({ space: 应用尺寸.间距_5 }) {
      Row() {
        Text(label)
          .fontSize(应用尺寸.字号_按钮)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Select(this.reviewOrderOptions().map((项: 牌组枚举选项): SelectOption => ({ value: 项.value })))
          .selected(this.reviewOrderOptionIndex(selected))
          .value(this.reviewOrderLabelString(selected))
          .controlSize(ControlSize.SMALL)
          .enabled(!this.busy)
          .onSelect((index: number) => {
            const 选项 = this.reviewOrderOptions();
            if (index >= 0 && index < 选项.length) {
              this.selectedReviewOrder = 选项[index].numericValue;
              if (this.form !== null) this.form.设置数值字段('reviewOrder', this.selectedReviewOrder.toString());
            }
          })
        Button($r('app.string.field_help_button'))
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor(this.动作主色)
          .enabled(!this.busy)
          .onClick(() => this.openHelp(label, help))
      }.width('100%')
      if (this.是否有字段错误(this.fieldKey(label)))
        Text(this.resolveText(this.字段错误资源(this.fieldKey(label))))
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.error_text'))
          .width('100%')
    }.width('100%')
  }

  private reviewOrderOptionIndex(value: number): number {
    const 选项 = this.reviewOrderOptions();
    for (let i = 0; i < 选项.length; i++) {
      if (选项[i].numericValue === value) return i;
    }
    return 0;
  }

  @Builder
  private advancedHubEntry() {
    Row() {
      Text($r('app.string.deck_group_advanced_hub'))
        .fontSize(应用尺寸.字号_正文_中)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text('›')
        .fontSize(应用尺寸.字号_正文)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(应用尺寸.按钮高度)
    .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
    .backgroundColor($r('app.color.surface_page'))
    .borderRadius(应用尺寸.圆角_面板)
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
        .backgroundBlurStyle(BlurStyle.Thin, {
          colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
          adaptiveColor: AdaptiveColor.DEFAULT
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onClick(() => { if (!this.busy) this.onCancel(); })
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.EaseOut, duration: 200 }))

      Column({ space: 应用尺寸.间距_12 }) {
        Text($r('app.string.deck_options_title')).fontSize(应用尺寸.字号_面板标题).fontWeight(FontWeight.Bold).width('100%')
        Text(this.deckName).fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.text_secondary')).width('100%')
        Scroll() {
          Column({ space: 应用尺寸.间距_12 }) {
            if (this.form !== null) {
              this.labeledInput($r('app.string.deck_newPerDay_label'), this.form.每日新卡数文本, (value: string) => { if (this.form !== null) this.form.每日新卡数文本 = value; }, $r('app.string.deck_newPerDay_help'))
              this.labeledInput($r('app.string.deck_reviewsPerDay_label'), this.form.每日复习数文本, (value: string) => { if (this.form !== null) this.form.每日复习数文本 = value; }, $r('app.string.deck_reviewsPerDay_help'))
              this.labeledInput($r('app.string.deck_learnSteps_label'), this.form.学习步骤文本, (value: string) => { if (this.form !== null) this.form.学习步骤文本 = value; }, $r('app.string.deck_learnSteps_help'))
              this.reviewOrderSelector($r('app.string.deck_reviewOrder_label'), this.selectedReviewOrder, $r('app.string.deck_reviewOrder_help'))
            }
            this.advancedHubEntry()
          }.width('100%')
        }.constraintSize({ maxHeight: '60%' }).width('100%').scrollBar(BarState.Auto)

        if (this.errorMessage !== '' || this.submitError !== '') Text(this.errorMessage !== '' ? this.errorMessage : this.submitError).fontSize(应用尺寸.字号_正文_小).fontColor($r('app.color.error_text')).width('100%')

        Row({ space: 应用尺寸.间距_10 }) {
          Button($r('app.string.create_deck_cancel'))
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.surface_page'))
            .borderRadius(应用尺寸.圆角_胶囊)
            .enabled(!this.busy)
            .onClick(() => this.onCancel())
          Button(this.busy ? $r('app.string.deck_options_saving') : $r('app.string.deck_options_save'))
            .layoutWeight(1)
            .height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_按钮)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action_on_primary'))
            .backgroundColor(this.savePressed ? this.主色按钮按下 : this.主色按钮背景)
            .borderRadius(应用尺寸.圆角_胶囊)
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
      .padding(应用尺寸.卡片内边距)
      .backgroundColor($r('app.color.surface_card'))
      .borderRadius(应用尺寸.圆角_卡片)
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

      if (this.showAdvanced) {
        高级牌组选项面板({
          isDark: this.isDark,
          form: this.form,
          options: this.options,
          busy: this.busy,
          onClose: (): void => { this.showAdvanced = false; }
        })
      }
      if (this.showHelp) 字段帮助面板({ 标题: this.helpTitle, 正文: this.helpBody, onClose: () => { this.showHelp = false; } })
    }
    .width('100%')
    .height('100%')
  }
}
