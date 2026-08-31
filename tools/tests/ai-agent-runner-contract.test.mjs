// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { encodeCardIds } from '../../entry/src/main/ets/proto/messages/CardsMessages.ts';
import {
  decodeCardIds,
  decodeNotetypeId,
  encodeNoteIds,
} from '../../entry/src/main/ets/proto/messages/NoteMessages.ts';
import { encodeNotetypeId } from '../../entry/src/main/ets/proto/messages/NotetypeMessages.ts';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

test('note helper codecs cover CardsOfNote and GetSingleNotetypeOfNotes wire shapes', () => {
  assert.deepEqual(decodeCardIds(encodeCardIds([11, 12, 900719])), [11, 12, 900719]);
  assert.deepEqual(Array.from(encodeNoteIds([31, 32])), [10, 2, 31, 32]);
  assert.equal(decodeNotetypeId(encodeNotetypeId(77)), 77);
});

test('note service exposes method 12 and 13 as read-only wrappers', () => {
  const index = read('entry/src/main/ets/backend/服务索引.ts');
  const service = read('entry/src/main/ets/backend/笔记服务.ts');
  assert.match(index, /某笔记的卡片:\s*12/);
  assert.match(index, /笔记的唯一笔记类型:\s*13/);
  assert.match(service, /async 获取笔记的卡片\(/);
  assert.match(service, /async 获取笔记的唯一笔记类型\(/);
  assert.match(service, /decodeCardIds/);
  assert.match(service, /encodeNoteIds/);
});

test('runner is bounded, deduplicates tool ids and never executes write tools directly', () => {
  const runner = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  const registry = read('entry/src/main/ets/backend/agent/AgentToolRegistry.ets');
  assert.match(runner, /maxProviderCalls/);
  assert.match(runner, /maxToolCalls/);
  assert.match(runner, /registerToolCallId/);
  assert.match(registry, /toolRiskOf/);
  assert.match(registry, /ChangeDraft/);
  assert.doesNotMatch(registry, /remove_notes|remove_cards|arbitrary_rpc|runDBCommand/);
});

test('a rejected tool call is returned to the model as a tool failure so it can self-correct', () => {
  const runner = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(runner, /catch \(error\)/);
  assert.match(runner, /toolStatusEvent\('tool_failed'/);
  assert.match(runner, /tool_error/);
  assert.match(runner, /kind:\s*'function_call_output'/);
  assert.match(runner, /AgentToolSchemaError/);
  assert.match(runner, /validTemplateJson/);
  assert.match(runner, /errorPath/);
});

test('runner emits complete per-call traces and stops a third identical failure early', () => {
  const runner = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(runner, /createStartedAgentToolTrace/);
  assert.match(runner, /completeAgentToolTrace/);
  assert.match(runner, /failAgentToolTrace/);
  assert.match(runner, /providerCalls/);
  assert.match(runner, /sequence/);
  assert.match(runner, /requireCorrection/);
  assert.match(runner, /shouldAbort/);
  assert.match(runner, /agent_repeated_tool_failure/);
  assert.match(runner, /Standard arguments template|validTemplateJson/);
});

test('parallel DeepSeek tool calls are replayed before any tool output', () => {
  const runner = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(runner,
    /const acceptedToolCalls:[\s\S]*for \(const call of collector\.toolCalls\)[\s\S]*kind:\s*'function_call'[\s\S]*for \(const call of acceptedToolCalls\)[\s\S]*kind:\s*'function_call_output'/);
});

test('runner enforces explicit-search evidence and disables unavailable optional web search', () => {
  const source = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(source, /request\.requiresSearchEvidence\s*\|\|\s*collector\.searchStarted/);
  assert.match(source, /web_search_unsupported/);
  assert.match(source, /request\.searchMode\s*=\s*'off'/);
});

test('runner replays provider continuation items and retries only before meaningful output', () => {
  const source = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(source, /collector\.continuationItems/);
  assert.match(source, /kind:\s*'output_item'/);
  assert.match(source, /receivedOutput/);
  assert.match(source, /shouldRetryTransport/);
  assert.match(source, /transientRetries\s*<\s*2/);
  assert.match(source, /hasReasoningContinuation/);
  assert.match(source, /!collector\.hasReasoningContinuation/);
  assert.match(source, /incompleteMaxOutput/);
  assert.match(source, /Continue from the truncated response/);
});

test('create mode cannot finish by merely claiming that a draft exists in text', () => {
  const source = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(source, /request\.requiresDraft\s*&&\s*drafts\.length\s*===\s*0/);
  assert.match(source, /agent_no_valid_draft/);
  assert.match(source, /Call the appropriate propose_ tool now/);
  assert.match(source, /createDraftNoteCount/);
  assert.match(source, /createdCount\s*!==\s*request\.expectedDraftCount/);
});

test('runner returns completed status with no clarification after ordinary work', () => {
  const source = read('entry/src/main/ets/backend/agent/AgentRunner.ets');
  assert.match(source, /status:\s*'completed'/);
  assert.match(source, /clarification:\s*null/);
});
