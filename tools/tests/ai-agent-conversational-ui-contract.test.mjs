// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

test('one disclosure component owns the conversation arrow and animation', () => {
  const disclosure = read('entry/src/main/ets/components/agent/AgentDisclosureCard.ets');
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(disclosure, /Text\('▼'\)/);
  assert.match(disclosure, /expanded\s*\?\s*0\s*:\s*-90/);
  assert.match(disclosure, /duration:\s*150/);
  assert.match(disclosure, /Curve\.EaseOut/);
  assert.doesNotMatch(disclosure, /animateTo\(/);
  assert.match(page, /AgentDisclosureCard/);
  assert.doesNotMatch(page, /private 切换工具详情[\s\S]*animateTo\(/);
});

test('create setup is an assistant-side local card instead of a fixed top form', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const setup = read('entry/src/main/ets/components/agent/AgentSetupCard.ets');
  assert.match(page, /AgentSetupCard/);
  assert.doesNotMatch(page, /private 选择区\(\)/);
  assert.doesNotMatch(page, /this\.选择区\(\)/);
  assert.match(page, /evaluateAgentReadiness/);
  assert.match(page, /buildAgentTaskProviderText/);
  assert.match(page, /buildAgentTaskVisibleText/);
  assert.match(setup, /AgentDisclosureCard/);
});

test('local setup is excluded while the task snapshot is sent', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /buildAgentTaskProviderText\(snapshot\)/);
  assert.match(page, /message\.kind === 'normal'|message\.kind === 'clarification'/);
  assert.doesNotMatch(page, /role:\s*'assistant'.*local_setup/);
});

test('clarification is a separate assistant bubble with explicit continuation', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  const card = read('entry/src/main/ets/components/agent/AgentClarificationCard.ets');
  assert.match(page, /result\.status === 'awaiting_clarification'/);
  assert.match(page, /appendClarificationMessage/);
  assert.match(page, /continueClarification/);
  assert.match(page, /buildClarificationAnswerText/);
  assert.match(page, /state = 'submitting'/);
  assert.match(page, /state = 'resolved'/);
  assert.match(page, /state = 'submit_failed'/);
  assert.match(page, /expanded = false/);
  assert.match(card, /AgentDisclosureCard/);
  assert.match(card, /ai_agent_clarification_continue/);
});

test('composer readiness and clarification lifecycle remain controlled by the page', () => {
  const page = read('entry/src/main/ets/pages/AI制卡页.ets');
  assert.match(page, /\.enabled\(this\.处理中 \|\| this\.readinessReason\(\) === 'ready'\)/);
  assert.match(page, /hasPendingClarification\(\)/);
  assert.match(page, /answerMessageId/);
  assert.match(page, /existingUserMessageId/);
  assert.match(page, /updateClarificationState/);
});
