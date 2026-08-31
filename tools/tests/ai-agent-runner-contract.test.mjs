// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import fs from 'node:fs';
import { register } from 'node:module';
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

const transportStub = `export class AgentStreamObserver {} export class AgentTransportError extends Error {} export class AgentTransportSession {}`;
const transportStubUrl = 'data:text/javascript;base64,' + Buffer.from(transportStub).toString('base64');
const adapterStub = `export class DeepSeekAdapter {} export class OpenAIAdapter {} export class CustomAdapter {}`;
const adapterStubUrl = 'data:text/javascript;base64,' + Buffer.from(adapterStub).toString('base64');
const registryStub = `export class AgentToolRegistry {} export class AgentToolResult {}`;
const registryStubUrl = 'data:text/javascript;base64,' + Buffer.from(registryStub).toString('base64');
const diagnosticsStub = `
export class AgentToolFailureRecord {}
export class AgentToolFailureTracker { record() { return { count: 1, requireCorrection: false, shouldAbort: false }; } }
export const createStartedAgentToolTrace = (call, providerCalls, sequence) => ({ callId: call.id, providerCalls, sequence, status: 'started' });
export const completeAgentToolTrace = (trace, outputJson) => ({ ...trace, status: 'completed', outputJson });
export const failAgentToolTrace = (trace, diagnostic) => ({ ...trace, status: 'failed', diagnostic });
export const sanitizeAgentToolJson = (text) => ({ text });
`;
const diagnosticsStubUrl = 'data:text/javascript;base64,' + Buffer.from(diagnosticsStub).toString('base64');
const loaderCode = `export function resolve(specifier, context, nextResolve) {
  if (specifier === './AgentTransport') return { url: ${JSON.stringify(transportStubUrl)}, shortCircuit: true };
  if (specifier === './DeepSeekAdapter' || specifier === './OpenAIAdapter' || specifier === './CustomAdapter') {
    return { url: ${JSON.stringify(adapterStubUrl)}, shortCircuit: true };
  }
  if (specifier === './AgentToolRegistry') return { url: ${JSON.stringify(registryStubUrl)}, shortCircuit: true };
  if (specifier === '../../model/agent/AgentToolDiagnostics') {
    return { url: ${JSON.stringify(diagnosticsStubUrl)}, shortCircuit: true };
  }
  return nextResolve(specifier, context);
}`;
register('data:text/javascript;base64,' + Buffer.from(loaderCode).toString('base64'), import.meta.url);
const { AgentRunner } = await import('../../entry/src/main/ets/backend/agent/AgentRunner.ets');

function providerRequest(overrides = {}) {
  return {
    apiKey: 'test-key', baseUrl: 'https://example.test/v1', model: 'test-model', instructions: '',
    input: [], functionTools: [], searchMode: 'off', requiresSearchEvidence: false,
    requiresDraft: false, expectedDraftCount: 0, reasoningEffort: '', maxOutputTokens: 1024,
    ...overrides,
  };
}

function toolCall(id, name, argumentsJson = '{}') {
  return { id, name, argumentsJson };
}

function toolCallEvent(call) {
  return { kind: 'tool_call', text: '', toolCall: call, toolTrace: null, source: null, errorCode: '' };
}

function runnerHarness(rounds, results) {
  const registry = {
    calls: [],
    async execute(call) {
      this.calls.push(call);
      return results.shift();
    },
  };
  const runner = new AgentRunner(registry);
  const requests = [];
  let roundIndex = 0;
  runner.createSession = (_provider, request, observer) => ({
    async start() {
      requests.push(request);
      const events = rounds[roundIndex] ?? [];
      roundIndex += 1;
      for (const event of events) {
        observer.onEvent(event);
      }
    },
    cancel() {},
  });
  return { runner, registry, requests };
}

function clarificationResult() {
  return {
    outputJson: JSON.stringify({ status: 'awaiting_user', clarificationId: 'scope-1' }),
    draft: null,
    clarification: {
      id: 'scope-1', question: 'Choose the card scope.',
      options: [{ id: 'one', label: 'One', description: '' }, { id: 'two', label: 'Two', description: '' }],
      recommendedOptionId: 'one', allowFreeText: true,
    },
  };
}

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

test('sole clarification pauses before create-mode draft correction with completed trace and output', async () => {
  const call = toolCall('clarify-1', 'request_clarification', '{"clarificationId":"scope-1"}');
  const { runner, registry, requests } = runnerHarness([[toolCallEvent(call)]], [clarificationResult()]);
  const events = [];

  const result = await runner.run('deepseek', providerRequest({ requiresDraft: true }), {
    onEvent(event) { events.push(event); },
  });

  assert.equal(result.status, 'awaiting_clarification');
  assert.equal(result.clarification.id, 'scope-1');
  assert.deepEqual(result.drafts, []);
  assert.equal(result.providerCalls, 1);
  assert.equal(registry.calls.length, 1);
  assert.deepEqual(events.map((event) => event.kind), ['tool_call', 'tool_started', 'tool_completed']);
  assert.deepEqual(requests[0].input.map((item) => item.kind), ['function_call', 'function_call_output']);
});

test('create mode rejects an ordinary no-tool completion without a draft', async () => {
  const { runner } = runnerHarness([[]], []);
  await assert.rejects(
    () => runner.run('deepseek', providerRequest({ requiresDraft: true }), { onEvent() {} }),
    (error) => error instanceof Error && error.message === 'agent_no_valid_draft',
  );
});

test('mixed clarification batches execute no registry calls and return protocol failures', async () => {
  const clarification = toolCall('clarify-1', 'request_clarification', '{"clarificationId":"scope-1"}');
  const ordinary = toolCall('search-1', 'search_cards', '{"query":"capital"}');
  const { runner, registry, requests } = runnerHarness(
    [[toolCallEvent(clarification), toolCallEvent(ordinary)], []], [],
  );
  const events = [];

  const result = await runner.run('deepseek', providerRequest(), { onEvent(event) { events.push(event); } });

  assert.equal(result.status, 'completed');
  assert.equal(registry.calls.length, 0);
  const failed = events.filter((event) => event.kind === 'tool_failed');
  assert.equal(failed.length, 2);
  assert.ok(failed.every((event) => event.errorCode === 'clarification_must_be_only_tool'));
  const replayedCalls = requests[0].input.filter((item) => item.kind === 'function_call');
  assert.deepEqual(replayedCalls.map((item) => item.callId), [clarification.id, ordinary.id]);
  const outputs = requests[0].input.filter((item) => item.kind === 'function_call_output');
  assert.equal(outputs.length, 2);
  for (const replayedCall of replayedCalls) {
    const index = requests[0].input.indexOf(replayedCall);
    assert.equal(requests[0].input[index + 1].kind, 'function_call_output');
    assert.equal(requests[0].input[index + 1].callId, replayedCall.callId);
    assert.equal(outputs.filter((item) => item.callId === replayedCall.callId).length, 1);
  }
  assert.ok(outputs.every((item) => {
    const output = JSON.parse(item.output);
    return output.tool_error === 'clarification_must_be_only_tool' &&
      output.correction === 'Call request_clarification alone, or finish ordinary tool work before asking the user.';
  }));
});

test('normal no-tool completion returns completed status', async () => {
  const { runner } = runnerHarness([[]], []);
  const result = await runner.run('deepseek', providerRequest(), { onEvent() {} });
  assert.deepEqual(result, {
    status: 'completed', clarification: null, drafts: [], providerCalls: 1, toolCalls: 0,
  });
});

test('cancellation triggered by a completed clarification trace wins over the pause result', async () => {
  const call = toolCall('clarify-1', 'request_clarification', '{"clarificationId":"scope-1"}');
  const { runner, requests } = runnerHarness([[toolCallEvent(call)]], [clarificationResult()]);
  const events = [];

  await assert.rejects(
    () => runner.run('deepseek', providerRequest({ requiresDraft: true }), {
      onEvent(event) {
        events.push(event);
        if (event.kind === 'tool_completed') { runner.cancel(); }
      },
    }),
    (error) => error instanceof Error && error.message === 'cancelled',
  );
  assert.equal(events.filter((event) => event.kind === 'tool_completed').length, 1);
  assert.equal(events.filter((event) => event.kind === 'tool_failed').length, 0);
  const outputs = requests[0].input.filter((item) => item.kind === 'function_call_output');
  assert.equal(outputs.length, 1);
  assert.equal(outputs[0].callId, call.id);
});
