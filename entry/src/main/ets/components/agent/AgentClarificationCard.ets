// SPDX-License-Identifier: AGPL-3.0-or-later

import type { AgentClarificationOption, AgentClarificationView } from '../../model/agent/AgentClarification';
import { canAnswerClarification } from '../../model/agent/AgentClarification';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 颜色键 } from '../../model/颜色主题';
import { AgentDisclosureCard } from './AgentDisclosureCard';

@Component
export struct AgentClarificationCard {
  @Prop clarification: AgentClarificationView;
  @Prop statusText: ResourceStr = '';
  @StorageProp(颜色键.主色按钮背景) private primaryBackground: string = '#2F5FD0';
  onOptionSelected: (id: string) => void = (_id: string): void => {};
  onSupplementChanged: (value: string) => void = (_value: string): void => {};
  onContinue: () => void = (): void => {};
  onToggle: () => void = (): void => {};

  private isEditable(): boolean {
    return this.clarification.state === 'pending' ||
      this.clarification.state === 'submit_failed';
  }

  @Builder
  private clarificationContent(): void {
    Text(this.clarification.request.question)
      .fontSize(应用尺寸.字号_正文)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
    ForEach(this.clarification.request.options, (option: AgentClarificationOption) => {
      Row({ space: 应用尺寸.间距_5 }) {
        Button(option.label)
          .enabled(this.isEditable())
          .backgroundColor(option.id === this.clarification.selectedOptionId ?
            this.primaryBackground : $r('app.color.surface_card'))
          .fontColor(option.id === this.clarification.selectedOptionId ?
            $r('app.color.action_on_primary') : $r('app.color.text_primary'))
          .onClick((): void => { this.onOptionSelected(option.id); })
        if (option.id === this.clarification.request.recommendedOptionId) {
          Text($r('app.string.ai_agent_clarification_recommended'))
            .fontSize(应用尺寸.字号_正文_小)
            .fontColor($r('app.color.text_secondary'))
        }
      }.width('100%')
      if (option.description.length > 0) {
        Text(option.description)
          .fontSize(应用尺寸.字号_正文_小)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
    }, (option: AgentClarificationOption): string => option.id)
    if (this.clarification.request.allowFreeText) {
      TextArea({
        text: this.clarification.supplementalText,
        placeholder: $r('app.string.ai_agent_clarification_supplement_hint')
      })
        .enabled(this.isEditable())
        .onChange((value: string): void => { this.onSupplementChanged(value); })
    }
    if (this.clarification.state === 'submit_failed') {
      Text($r('app.string.ai_agent_clarification_submit_failed'))
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.error_text'))
        .width('100%')
    }
    if (this.isEditable()) {
      Button($r('app.string.ai_agent_clarification_continue'))
        .width('100%')
        .enabled(canAnswerClarification(this.clarification))
        .height(应用尺寸.按钮高度).fontSize(应用尺寸.字号_按钮)
        .backgroundColor(this.primaryBackground).fontColor($r('app.color.action_on_primary'))
        .borderRadius(应用尺寸.圆角_胶囊)
        .onClick((): void => { this.onContinue(); })
    }
  }

  build() {
    AgentDisclosureCard({
      messageSurface: true,
      title: this.clarification.state === 'resolved' ?
        $r('app.string.ai_agent_clarification_resolved') :
        $r('app.string.ai_agent_clarification_title'),
      status: this.statusText,
      showStatus: true,
      expanded: this.clarification.expanded,
      toggleLocked: this.clarification.state === 'pending' ||
        this.clarification.state === 'submitting' ||
        this.clarification.state === 'submit_failed',
      onToggle: this.onToggle,
      content: (): void => { this.clarificationContent(); }
    })
  }
}
