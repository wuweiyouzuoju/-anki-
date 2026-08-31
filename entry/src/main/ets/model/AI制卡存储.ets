// SPDX-License-Identifier: AGPL-3.0-or-later

// 旧 AI 制卡页兼容门面。非敏感选项进 Preferences，API Key 进 Asset Store；
// 读取到旧版明文 key 时先完成安全写入，再删除旧键。

import {
  AgentSettings,
  clearLegacyAgentSecret,
  loadAgentSettings,
  loadLegacyAIConfiguration,
  saveAgentSettings
} from '../backend/agent/AgentSettingsStore';
import {
  loadAgentSecret,
  saveAgentSecret
} from '../backend/agent/AgentSecretStore';
import type { ProviderId } from './agent/AgentTypes';
import { DEEPSEEK_PROVIDER, OPENAI_PROVIDER } from './agent/ProviderCatalog';

/** 新用户默认 DeepSeek；旧页面仍显示实际选中供应商的地址/模型。 */
export const 默认AI接口地址: string = DEEPSEEK_PROVIDER.baseUrl;
export const 默认AI模型名: string = DEEPSEEK_PROVIDER.defaultModel;

/** AI 服务配置（用户在 AI 制卡页填写并保存）。 */
export interface AI制卡配置 {
  apiKey: string;
  baseUrl: string;
  model: string;
}

function providerForBaseUrl(baseUrl: string): ProviderId {
  const normalized: string = baseUrl.trim().replace(/\/+$/, '');
  if (normalized === OPENAI_PROVIDER.baseUrl) {
    return 'openai';
  }
  if (normalized === DEEPSEEK_PROVIDER.baseUrl) {
    return 'deepseek';
  }
  return normalized.length > 0 ? 'custom' : 'deepseek';
}

function coordinatesOf(settings: AgentSettings): AI制卡配置 {
  if (settings.selectedProvider === 'openai') {
    return { apiKey: '', baseUrl: OPENAI_PROVIDER.baseUrl, model: settings.openaiModel };
  }
  if (settings.selectedProvider === 'custom') {
    return { apiKey: '', baseUrl: settings.customBaseUrl, model: settings.customModel };
  }
  return { apiKey: '', baseUrl: DEEPSEEK_PROVIDER.baseUrl, model: settings.deepseekModel };
}

async function 迁移旧版明文密钥(): Promise<void> {
  const 旧配置 = await loadLegacyAIConfiguration();
  if (旧配置.apiKey.length === 0) {
    return;
  }
  const providerId: ProviderId = providerForBaseUrl(旧配置.baseUrl);
  const settings: AgentSettings = await loadAgentSettings();
  settings.selectedProvider = providerId;
  if (providerId === 'openai' && 旧配置.model.length > 0) {
    settings.openaiModel = 旧配置.model;
  } else if (providerId === 'deepseek' && 旧配置.model.length > 0) {
    settings.deepseekModel = 旧配置.model;
  } else if (providerId === 'custom') {
    settings.customBaseUrl = 旧配置.baseUrl;
    settings.customModel = 旧配置.model;
  }
  await saveAgentSecret(providerId, 旧配置.apiKey);
  await saveAgentSettings(settings);
  await clearLegacyAgentSecret();
}

/**
 * 读取 AI 配置；三项均带默认值回退。baseUrl/model 为空时视为未配置，
 * 由调用方（AI 制卡页）用默认值渲染输入框。
 */
export async function 加载AI制卡配置(): Promise<AI制卡配置> {
  try {
    await 迁移旧版明文密钥();
    const settings: AgentSettings = await loadAgentSettings();
    const config: AI制卡配置 = coordinatesOf(settings);
    config.apiKey = await loadAgentSecret(settings.selectedProvider);
    return config;
  } catch (错误) {
    return { apiKey: '', baseUrl: 默认AI接口地址, model: 默认AI模型名 };
  }
}

/** 保存 AI 配置并 flush 落盘；失败静默（下次进入会读回旧值/默认值）。 */
export async function 保存AI制卡配置(配置: AI制卡配置): Promise<void> {
  try {
    const providerId: ProviderId = providerForBaseUrl(配置.baseUrl);
    const settings: AgentSettings = await loadAgentSettings();
    settings.selectedProvider = providerId;
    if (providerId === 'openai') {
      settings.openaiModel = 配置.model.trim();
    } else if (providerId === 'deepseek') {
      settings.deepseekModel = 配置.model.trim();
    } else {
      settings.customBaseUrl = 配置.baseUrl.trim();
      settings.customModel = 配置.model.trim();
    }
    await saveAgentSecret(providerId, 配置.apiKey);
    await saveAgentSettings(settings);
  } catch (错误) {
    // 写盘失败不中断流程；保存结果由 UI 提示
  }
}
