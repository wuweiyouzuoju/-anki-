// SPDX-License-Identifier: AGPL-3.0-or-later

import type { AgentMode } from '../../model/agent/AgentTypes';
import type { AgentTaskSetup } from '../../model/agent/AgentTaskContext';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { AgentDisclosureCard } from './AgentDisclosureCard';

export interface AgentSetupChoice {
  id: number;
  name: string;
}

interface AgentSelectOption { value: string; }

@Component
export struct AgentSetupCard {
  @Prop mode: AgentMode = 'create';
  @Prop setup: AgentTaskSetup;
  @Prop deckOptions: AgentSetupChoice[] = [];
  @Prop notetypeOptions: AgentSetupChoice[] = [];
  @Prop readinessText: ResourceStr = '';
  @Prop editContext: string = '';
  @Prop disabled: boolean = false;
  onDeckSelected: (id: number) => void = (_id: number): void => {};
  onNotetypeSelected: (id: number) => void = (_id: number): void => {};
  onToggle: () => void = (): void => {};

  @Builder
  private setupContent(): void {
    if (this.mode === 'create') {
      Row() {
        Text($r('app.string.ai_card_target_deck')).layoutWeight(1)
        Select(this.deckOptions.map((item: AgentSetupChoice): AgentSelectOption => ({ value: item.name })))
          .selected(this.deckOptions.findIndex((item: AgentSetupChoice): boolean =>
            item.id === this.setup.deckId))
          .enabled(!this.disabled)
          .onSelect((index: number): void => {
            if (index >= 0 && index < this.deckOptions.length) {
              this.onDeckSelected(this.deckOptions[index].id);
            }
          })
      }.width('100%')
      Row() {
        Text($r('app.string.add_note_notetype')).layoutWeight(1)
        Select(this.notetypeOptions.map((item: AgentSetupChoice): AgentSelectOption => ({ value: item.name })))
          .selected(this.notetypeOptions.findIndex((item: AgentSetupChoice): boolean =>
            item.id === this.setup.notetypeId))
          .enabled(!this.disabled)
          .onSelect((index: number): void => {
            if (index >= 0 && index < this.notetypeOptions.length) {
              this.onNotetypeSelected(this.notetypeOptions[index].id);
            }
          })
      }.width('100%')
      Text($r('app.string.ai_agent_setup_instruction'))
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    } else {
      Text(this.editContext)
        .fontSize(应用尺寸.字号_正文_小)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
  }

  build() {
    AgentDisclosureCard({
      title: this.mode === 'create' ? $r('app.string.ai_agent_setup_title_create') :
        $r('app.string.ai_agent_setup_title_edit'),
      status: this.readinessText,
      showStatus: true,
      expanded: this.setup.expanded,
      toggleLocked: false,
      onToggle: this.onToggle,
      content: (): void => { this.setupContent(); }
    })
  }
}
