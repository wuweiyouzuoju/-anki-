// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const historyPath = path.join(root,
  'entry/src/main/ets/model/agent/AgentConversationStore.ets');

test('local Agent history is resumable and deletable', () => {
  assert.equal(fs.existsSync(historyPath), true);
  const source = fs.readFileSync(historyPath, 'utf8');
  assert.match(source, /loadAgentConversations/);
  assert.match(source, /saveAgentConversation/);
  assert.match(source, /deleteAgentConversation/);
  assert.match(source, /preferences\.getPreferences/);
});

test('history schema keeps audit, sources and results but has no secret, reasoning or media fields', () => {
  const source = fs.readFileSync(historyPath, 'utf8');
  assert.match(source, /AgentHistoryAudit/);
  assert.match(source, /AgentHistoryResult/);
  assert.match(source, /SearchSource/);
  assert.doesNotMatch(source, /apiKey\s*:/);
  assert.doesNotMatch(source, /reasoning\s*:/i);
  assert.doesNotMatch(source, /media(Bytes|Data)\s*:/i);
  assert.match(source, /sanitizeHistoryText/);
  assert.match(source, /data:/);
  for (const field of [
    'callId', 'providerRound', 'sequence', 'argumentsJson', 'outputJson',
    'errorCode', 'errorPath', 'allowedKeys', 'validTemplateJson', 'repeatCount', 'expanded',
  ]) {
    assert.match(source, new RegExp(field));
  }
  assert.match(source, /sanitizeAgentToolJson/);
  assert.match(source, /MAX_AUDIT_TEXT_TOTAL/);
  assert.match(source, /legacySummary/);
  assert.match(source, /setup:\s*AgentTaskSetup/);
  assert.match(source, /kind:\s*string/);
  assert.match(source, /clarification:\s*AgentClarificationView\s*\|\s*null/);
  assert.match(source, /expanded:\s*boolean/);
  assert.match(source, /function safeSetup/);
  assert.match(source, /function safeClarification/);
  assert.doesNotMatch(source, /confirmationToken\s*:/);
});

test('shared page persists completed turns and provides resume/delete actions', () => {
  const page = fs.readFileSync(
    path.join(root, 'entry/src/main/ets/pages/AI制卡页.ets'), 'utf8');
  assert.match(page, /saveAgentConversation/);
  assert.match(page, /打开历史会话/);
  assert.match(page, /删除当前历史会话/);
  assert.match(page, /显示历史菜单页/);
  assert.match(page, /promptAction\.showActionMenu/);
  assert.match(page, /开始新会话/);
});

test('history saves and restores structured clarification without deleting its question', () => {
  const page = fs.readFileSync(
    path.join(root, 'entry/src/main/ets/pages/AI制卡页.ets'), 'utf8');
  assert.match(page, /kind:\s*message\.kind/);
  assert.match(page, /clarification:\s*message\.clarification/);
  assert.match(page, /message\.kind\s*=\s*item\.kind/);
  assert.match(page, /message\.clarification\s*=\s*item\.clarification/);
  assert.match(page, /message\.expanded\s*=\s*item\.expanded/);
  assert.match(page, /message\.kind\s*=\s*'clarification'/);
  assert.match(page, /空消息\('ai', request\.question, false\)/);
});
