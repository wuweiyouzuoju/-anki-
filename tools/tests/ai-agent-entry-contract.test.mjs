// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

test('home exposes separate create and edit entries using one shared page', () => {
  const panel = read('entry/src/main/ets/components/主页操作面板.ets');
  const home = read('entry/src/main/ets/pages/首页.ets');
  assert.match(panel, /AI制卡回调/);
  assert.match(panel, /AI改卡回调/);
  assert.match(home, /打开AI制卡/);
  assert.match(home, /打开AI改卡/);
  assert.match(home, /mode:\s*'create'/);
  assert.match(home, /mode:\s*'edit'/);
});

test('shared Agent page has explicit mode and sends no provider request while appearing', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /mode\?:\s*AgentMode/);
  assert.match(page, /pageMode:\s*AgentMode/);
  assert.match(page, /AgentRunner/);
  assert.match(page, /run\(/);
  const appear = page.match(/async aboutToAppear\(\): Promise<void> \{([\s\S]*?)\n  \}/)?.[1] ?? '';
  assert.doesNotMatch(appear, /\.run\(|请求AI生成卡片/);
  assert.doesNotMatch(page, /请求AI生成卡片/);
  assert.match(page, /ai_agent_edit_search_welcome/);
});

test('shared Agent page keeps the Select option type used by provider models', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /interface AI制卡下拉选项\s*\{\s*value:\s*string;/);
  assert.match(page, /页面模型选项\(\): AI制卡下拉选项\[\]/);
});

test('study current-card entry passes stable context and rerenders only that card on return', () => {
  const study = read('entry/src/main/ets/pages/学习页.ets');
  assert.match(study, /ai_card_edit/);
  assert.match(study, /cardIds:\s*\[this\.当前卡片\.cardId\]/);
  assert.match(study, /noteIds:\s*\[this\.当前卡片\.noteId\]/);
  assert.match(study, /templateIdx:\s*this\.当前卡片\.templateIdx/);
  assert.match(study, /刷新AI改卡后当前卡/);
  const refresh = study.match(/private async 刷新AI改卡后当前卡\(\): Promise<void> \{([\s\S]*?)\n  \}/)?.[1] ?? '';
  assert.match(refresh, /渲染既有卡片/);
  assert.doesNotMatch(refresh, /获取队首卡片|回答卡片|埋藏|暂停/);
});

test('browser edit entry passes selected IDs and preserves the active search', () => {
  const browser = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(browser, /打开AI改卡/);
  assert.match(browser, /mode:\s*'edit'/);
  assert.match(browser, /this\.浏览模式值 === 'cards'/);
  assert.match(browser, /cardIds/);
  assert.match(browser, /noteIds/);
  assert.match(browser, /onPop:[\s\S]*this\.执行搜索\(\)/);
});

test('shared page rebuilds stable ID scope and batch policy for every user turn', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /private 重建本轮AgentScope\(\)/);
  assert.match(page, /runAgentTurn[\s\S]*this\.重建本轮AgentScope\(\)/);
  assert.match(page, /this\.agentScope\.reset\(\)/);
  assert.match(page, /configureBatchLimit\(this\.agentSettings\.batchLimit\)/);
  assert.match(page, /agentFunctionTools\(this\.agentSettings\.batchLimit, this\.pageMode\)/);
});

test('create mode exposes only create tools while edit mode enables edit and high-risk proposals', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const catalog = read('entry/src/main/ets/model/agent/AgentToolCatalog.ts');
  assert.match(page, /register\(registry, this\.pageMode\)/);
  assert.match(page, /if \(this\.pageMode === 'edit'\)[\s\S]*HighRiskAgentTools/);
  assert.match(catalog, /mode:\s*AgentMode/);
  assert.match(catalog, /mode === 'edit'/);
});

test('reasoning is visibly labelled and HTTP failures keep their status code', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /ai_agent_reasoning_process/);
  assert.match(page, /AgentTransportError/);
  assert.match(page, /ai_agent_http_error/);
  assert.match(page, /statusCode/);
  assert.match(page, /getStringSync\(资源\.id, \.\.\.参数\)/);
  assert.doesNotMatch(page, /\.replace\('%s'/);
  assert.match(page, /message\.正文\.length > 0\s*\? `\$\{message\.正文\}\\n\\n\$\{错误文案\}`\s*:\s*错误文案/,
    'a failure after partial model text must remain visible instead of only tinting the bubble red');
  assert.doesNotMatch(page, /message\.正文\s*\+=\s*event\.errorCode/,
    'raw provider codes must not be duplicated before the localized catch message');
});

test('AI configuration is localized and has no acknowledgement gate or explanatory banner', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const settings = read('entry/src/main/ets/components/settings/AIAgent设置分组.ets');
  assert.match(page + settings, /ai_agent_provider_custom/);
  assert.doesNotMatch(page + settings,
    /ai_agent_privacy_notice|ai_agent_privacy_accept|privacyAccepted|隐私已确认|ai_card_config_hint/);

  const zh = JSON.parse(read('entry/src/main/resources/base/element/string.json')).string
    .reduce((map, item) => ({ ...map, [item.name]: item.value }), {});
  const en = JSON.parse(read('entry/src/main/resources/en_US/element/string.json')).string
    .reduce((map, item) => ({ ...map, [item.name]: item.value }), {});
  assert.equal(zh.ai_card_config, '配置');
  assert.equal(zh.ai_agent_provider_custom, '自定义');
  assert.equal(en.ai_agent_provider_custom, 'Custom');
});

test('AI page title uses equal side regions around the screen midpoint', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const top = page.match(/private 顶部条\(\)[\s\S]*?@Builder\s+private 配置区/)?.[0] ?? '';
  assert.equal((top.match(/\.width\('35%'\)/g) ?? []).length, 2);
  assert.match(top, /\.width\('30%'\)[\s\S]*\.textAlign\(TextAlign\.Center\)/);
  assert.match(top, /\.justifyContent\(FlexAlign\.End\)/);
});

test('API key, custom endpoint and custom model inputs share one visual style', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const settings = read('entry/src/main/ets/components/settings/AIAgent设置分组.ets');
  const pageConfig = page.match(/private 配置区\(\)[\s\S]*?@Builder\s+private/)?.[0] ?? '';
  assert.ok((pageConfig.match(/backgroundColor\(\$r\('app\.color\.surface_card'\)\)/g) ?? []).length >= 3);
  assert.ok((pageConfig.match(/app\.color\.border_input/g) ?? []).length >= 3);
  assert.ok((settings.match(/backgroundColor\(\$r\('app\.color\.surface_card'\)\)/g) ?? []).length >= 3);
  assert.ok((settings.match(/app\.color\.border_input/g) ?? []).length >= 3);
});

test('an in-flight Agent turn is cancellable from the send button and exposes localized failures', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /private 取消当前请求\(\): void/);
  assert.match(page, /this\.agentRunner\.cancel\(\)/);
  assert.match(page, /this\.处理中\s*\?\s*\$r\('app\.string\.ai_agent_cancel'\)/);
  assert.match(page, /if \(this\.处理中\) \{ this\.取消当前请求\(\); \}/);
  assert.match(page, /ai_agent_web_search_unsupported/);
  assert.match(page, /ai_agent_turn_cancelled/);
});

test('all successful and failed tool calls use one typed detail view collapsed by default', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /工具过程:\s*AgentToolTrace\[\]/);
  assert.match(page, /event\.toolTrace/);
  assert.match(page, /callId/);
  assert.match(page, /private 工具过程项/);
  assert.match(page, /argumentsJson/);
  assert.match(page, /outputJson/);
  assert.match(page, /errorPath/);
  assert.match(page, /allowedKeys/);
  assert.match(page, /validTemplateJson/);
  assert.match(page, /repeatCount/);
  assert.match(page, /expanded/);
  assert.doesNotMatch(page, /工具过程:\s*string\[\]/);
  assert.doesNotMatch(page, /item\.indexOf\(':'\)/);

  const bubble = page.match(/private AI气泡\(消息索引: number\)[\s\S]*?@Builder\s+private 消息流/)?.[0] ?? '';
  const reasoningIndex = bubble.indexOf("ai_agent_reasoning_process");
  const toolsIndex = bubble.indexOf("ai_agent_tool_process");
  const sourcesIndex = bubble.indexOf("来源列表.length > 0");
  const cardsIndex = bubble.indexOf("卡片列表.length > 0");
  const draftsIndex = bubble.indexOf("变更草稿列表.length > 0");
  assert.ok(reasoningIndex >= 0 && toolsIndex > reasoningIndex && sourcesIndex > toolsIndex);
  assert.ok(cardsIndex > sourcesIndex, 'card drafts must render after reasoning, tools, and sources');
  assert.ok(draftsIndex > sourcesIndex, 'change drafts must render after reasoning, tools, and sources');

  const disclosure = read('entry/src/main/ets/components/agent/AgentDisclosureCard.ets');
  assert.match(disclosure, /Text\('▼'\)/);
  assert.match(disclosure, /expanded\s*\?\s*0\s*:\s*-90/);
  assert.doesNotMatch(page, /切换工具详情[\s\S]*?animateTo\(/);
  assert.match(page,
    /trace\.expanded\s*=\s*message\.工具过程\[existingIndex\]\.expanded[\s\S]*?message\.工具过程\[existingIndex\]\s*=\s*trace/,
    'completion events must preserve a user-expanded running trace');

  const zh = JSON.parse(read('entry/src/main/resources/base/element/string.json')).string
    .reduce((map, item) => ({ ...map, [item.name]: item.value }), {});
  const en = JSON.parse(read('entry/src/main/resources/en_US/element/string.json')).string
    .reduce((map, item) => ({ ...map, [item.name]: item.value }), {});
  for (const key of [
    'ai_agent_tool_round', 'ai_agent_tool_arguments', 'ai_agent_tool_output',
    'ai_agent_tool_error_path', 'ai_agent_tool_allowed_keys', 'ai_agent_tool_template',
    'ai_agent_tool_repeat_count', 'ai_agent_tool_truncated', 'ai_agent_repeated_tool_failure',
  ]) {
    assert.equal(typeof zh[key], 'string', key);
    assert.equal(typeof en[key], 'string', key);
  }
});
