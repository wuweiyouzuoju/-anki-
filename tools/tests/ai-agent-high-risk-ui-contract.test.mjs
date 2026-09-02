// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

test('draft UI shows exact impact and uses separate high-risk confirmation events', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /affectedNoteIds/);
  assert.match(page, /affectedCardIds/);
  assert.match(page, /affectedDeckIds/);
  assert.match(page, /affectedNotetypeIds/);
  assert.match(page, /准备执行草稿/);
  assert.match(page, /打开高风险最终确认/);
  assert.match(page, /authorizeHighRisk/);
  assert.match(page, /executeHighRisk/);
  assert.match(page, /executeOrdinary/);
  assert.match(page, /永久/);
});

test('provider settings use dropdowns, remember provider/models and keep keys in Asset Store', () => {
  const settings = read('entry/src/main/ets/components/settings/AIAgent设置分组.ets');
  assert.match(settings, /Select\(/);
  assert.match(settings, /DeepSeek/);
  // OpenAI 选项按产品要求在 UI 上隐藏（2026-09-02）；存档层仍保留 openai 模型记忆。
  assert.doesNotMatch(settings, /'OpenAI'/);
  assert.match(settings, /OPENAI_PROVIDER/);
  assert.match(settings, /openaiModel/);
  assert.match(settings, /ai_agent_provider_custom/);
  assert.match(settings, /loadAgentSettings/);
  assert.match(settings, /saveAgentSettings/);
  assert.match(settings, /loadAgentSecret/);
  assert.match(settings, /saveAgentSecret/);
  assert.match(settings, /customBaseUrl/);
  assert.match(settings, /customModel/);
  assert.doesNotMatch(settings, /preferences.*apiKey|apiKey.*preferences/si);
});

test('shared page renders real streaming, tool and source events', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /text_delta/);
  assert.match(page, /reasoning_delta|reasoning_summary/);
  assert.match(page, /tool_started/);
  assert.match(page, /search_source/);
  assert.match(page, /来源/);
});
