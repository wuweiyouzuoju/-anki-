// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderId, SearchMode } from '../../model/agent/AgentTypes';
import { common } from '@kit.AbilityKit';
import { DEEPSEEK_PROVIDER, OPENAI_PROVIDER } from '../../model/agent/ProviderCatalog';
import {
  AgentSettings,
  defaultAgentSettings,
  loadAgentSettings,
  saveAgentSettings
} from '../../backend/agent/AgentSettingsStore';
import { loadAgentSecret, saveAgentSecret } from '../../backend/agent/AgentSecretStore';
import { 应用尺寸 } from '../../utils/应用尺寸';
import { 设置分组卡片 } from './设置分组卡片';

interface SelectItem { value: string; }

@Component
export struct AIAgent设置分组 {
  @Prop 是否深色: boolean = false;
  @Prop 已展开: boolean = false;
  切换展开回调: () => void = (): void => {};

  @State private provider: ProviderId = 'deepseek';
  @State private deepseekModel: string = DEEPSEEK_PROVIDER.defaultModel;
  @State private openaiModel: string = OPENAI_PROVIDER.defaultModel;
  @State private customBaseUrl: string = '';
  @State private customModel: string = '';
  @State private searchMode: SearchMode = 'auto';
  @State private batchLimit: number = 100;
  @State private secret: string = '';
  @State private saving: boolean = false;
  @State private message: string = '';

  async aboutToAppear(): Promise<void> {
    const settings: AgentSettings = await loadAgentSettings();
    this.provider = settings.selectedProvider;
    this.deepseekModel = settings.deepseekModel;
    this.openaiModel = settings.openaiModel;
    this.customBaseUrl = settings.customBaseUrl;
    this.customModel = settings.customModel;
    this.searchMode = settings.searchMode;
    this.batchLimit = settings.batchLimit;
    this.secret = await loadAgentSecret(this.provider);
  }

  private getString(resource: Resource): string {
    const context: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (context === undefined) { return ''; }
    try { return context.resourceManager.getStringSync(resource.id); } catch (error) { return ''; }
  }

  private providerIndex(): number { return this.provider === 'deepseek' ? 0 : (this.provider === 'openai' ? 1 : 2); }
  private modelIndex(): number {
    const models: string[] = this.provider === 'deepseek' ? DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
    const current: string = this.provider === 'deepseek' ? this.deepseekModel : this.openaiModel;
    const index: number = models.indexOf(current);
    return index < 0 ? 0 : index;
  }
  private modelOptions(): SelectItem[] {
    const models: string[] = this.provider === 'deepseek' ? DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
    return models.map((value: string): SelectItem => ({ value: value }));
  }
  private async switchProvider(index: number): Promise<void> {
    this.provider = index === 0 ? 'deepseek' : (index === 1 ? 'openai' : 'custom');
    this.secret = await loadAgentSecret(this.provider);
    this.message = '';
  }
  private async save(): Promise<void> {
    if (this.saving) { return; }
    if (this.provider === 'custom' && (!this.customBaseUrl.trim().startsWith('https://') || this.customModel.trim() === '')) {
      this.message = this.getString($r('app.string.ai_agent_custom_invalid'));
      return;
    }
    this.saving = true;
    try {
      const settings: AgentSettings = defaultAgentSettings();
      settings.selectedProvider = this.provider;
      settings.deepseekModel = this.deepseekModel;
      settings.openaiModel = this.openaiModel;
      settings.customBaseUrl = this.customBaseUrl;
      settings.customModel = this.customModel;
      settings.searchMode = this.searchMode;
      settings.batchLimit = this.batchLimit;
      await saveAgentSettings(settings);
      await saveAgentSecret(this.provider, this.secret);
      this.message = this.getString($r('app.string.ai_agent_saved_securely'));
    } catch (error) {
      this.message = this.getString($r('app.string.ai_card_save_failed'));
    }
    this.saving = false;
  }

  build() {
    设置分组卡片({
      标题: $r('app.string.ai_agent_settings_title'),
      是否深色: this.是否深色,
      是否展开: this.已展开,
      切换展开回调: this.切换展开回调
    }) {
      Column({ space: 应用尺寸.间距_10 }) {
          Row() {
            Text($r('app.string.ai_agent_provider')).layoutWeight(1)
            Select([{ value: 'DeepSeek' }, { value: 'OpenAI' },
              { value: this.getString($r('app.string.ai_agent_provider_custom')) }])
              .selected(this.providerIndex()).value(this.provider === 'deepseek' ? 'DeepSeek' :
                (this.provider === 'openai' ? 'OpenAI' :
                  this.getString($r('app.string.ai_agent_provider_custom'))))
              .onSelect((index: number): void => { this.switchProvider(index); })
          }.width('100%')
          if (this.provider !== 'custom') {
            Row() {
              Text($r('app.string.ai_card_model')).layoutWeight(1)
              Select(this.modelOptions()).selected(this.modelIndex())
                .value(this.provider === 'deepseek' ? this.deepseekModel : this.openaiModel)
                .onSelect((index: number): void => {
                  const models: string[] = this.provider === 'deepseek' ? DEEPSEEK_PROVIDER.models : OPENAI_PROVIDER.models;
                  if (this.provider === 'deepseek') { this.deepseekModel = models[index]; }
                  else { this.openaiModel = models[index]; }
                })
            }.width('100%')
          } else {
            TextInput({ placeholder: $r('app.string.ai_agent_custom_url_hint'), text: this.customBaseUrl })
              .width('100%').height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文).fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
              .borderRadius(应用尺寸.圆角_面板)
              .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
              .onChange((value: string): void => { this.customBaseUrl = value; })
            TextInput({ placeholder: $r('app.string.ai_card_model_hint'), text: this.customModel })
              .width('100%').height(应用尺寸.按钮高度)
              .fontSize(应用尺寸.字号_正文).fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.surface_card'))
              .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
              .borderRadius(应用尺寸.圆角_面板)
              .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
              .onChange((value: string): void => { this.customModel = value; })
          }
          TextInput({ placeholder: $r('app.string.ai_card_api_key'), text: this.secret })
            .type(InputType.Password)
            .width('100%').height(应用尺寸.按钮高度)
            .fontSize(应用尺寸.字号_正文).fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.surface_card'))
            .border({ width: 应用尺寸.卡片边框, color: $r('app.color.border_input') })
            .borderRadius(应用尺寸.圆角_面板)
            .padding({ left: 应用尺寸.间距_10, right: 应用尺寸.间距_10 })
            .onChange((value: string): void => { this.secret = value; })
          Row() {
            Text($r('app.string.ai_agent_search_mode')).layoutWeight(1)
            Select([{ value: this.getString($r('app.string.ai_agent_search_auto')) },
              { value: this.getString($r('app.string.ai_agent_search_always')) },
              { value: this.getString($r('app.string.ai_agent_search_off')) }])
              .selected(this.searchMode === 'auto' ? 0 : (this.searchMode === 'always' ? 1 : 2))
              .onSelect((index: number): void => { this.searchMode = index === 0 ? 'auto' : (index === 1 ? 'always' : 'off'); })
          }.width('100%')
          Row() {
            Text($r('app.string.ai_agent_batch_limit')).layoutWeight(1)
            Select([{ value: '100' }, { value: '250' }, { value: '500' }, { value: '1000' }])
              .selected(this.batchLimit === 100 ? 0 : (this.batchLimit === 250 ? 1 : (this.batchLimit === 500 ? 2 : 3)))
              .onSelect((index: number): void => { this.batchLimit = [100, 250, 500, 1000][index]; })
          }.width('100%')
          Button(this.saving ? $r('app.string.ai_card_generating') : $r('app.string.ai_card_save_config'))
            .width('100%').enabled(!this.saving).onClick((): void => { this.save(); })
          if (this.message !== '') { Text(this.message).fontSize(12).fontColor($r('app.color.text_secondary')) }
      }
      .padding({ bottom: 应用尺寸.间距_12 }).width('100%')
    }
  }
}
