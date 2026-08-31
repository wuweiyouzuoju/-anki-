// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderCapabilities, ProviderId } from './AgentTypes';

export interface ProviderCatalogEntry {
  id: ProviderId;
  displayName: string;
  baseUrl: string;
  models: string[];
  defaultModel: string;
  isDefault: boolean;
  baseUrlEditable: boolean;
  modelEditable: boolean;
  capabilities: ProviderCapabilities;
}

export const DEEPSEEK_PROVIDER: ProviderCatalogEntry = {
  id: 'deepseek',
  displayName: 'DeepSeek',
  baseUrl: 'https://api.deepseek.com',
  models: [
    'deepseek-v4-flash',
    'deepseek-v4-pro',
    'deepseek-v4-flash-vision-exp'
  ],
  defaultModel: 'deepseek-v4-flash',
  isDefault: true,
  baseUrlEditable: false,
  modelEditable: false,
  capabilities: {
    text: true,
    image: false,
    audio: false,
    streaming: true,
    toolCalls: true,
    reasoning: true,
    webSearch: true
  }
};

export const OPENAI_PROVIDER: ProviderCatalogEntry = {
  id: 'openai',
  displayName: 'OpenAI',
  baseUrl: 'https://api.openai.com/v1',
  models: ['gpt-5.6-luna', 'gpt-5.6-terra', 'gpt-5.6-sol'],
  defaultModel: 'gpt-5.6-luna',
  isDefault: false,
  baseUrlEditable: false,
  modelEditable: false,
  capabilities: {
    text: true,
    image: true,
    audio: false,
    streaming: true,
    toolCalls: true,
    reasoning: true,
    webSearch: true
  }
};

export function customProviderDefaults(): ProviderCatalogEntry {
  return {
    id: 'custom',
    displayName: 'Custom',
    baseUrl: '',
    models: [],
    defaultModel: '',
    isDefault: false,
    baseUrlEditable: true,
    modelEditable: true,
    capabilities: {
      text: true,
      image: false,
      audio: false,
      streaming: true,
      toolCalls: true,
      reasoning: false,
      webSearch: false
    }
  };
}

export function builtInProviders(): ProviderCatalogEntry[] {
  return [DEEPSEEK_PROVIDER, OPENAI_PROVIDER];
}
