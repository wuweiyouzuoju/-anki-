// SPDX-License-Identifier: AGPL-3.0-or-later
import assert from 'node:assert/strict';
import test from 'node:test';
import { register } from 'node:module';

// 使用真实历史读写模块，只替换 HarmonyOS Preferences IO。
const stub = `export const state = { value: '[]' };
export const common = {};
export const preferences = { async getPreferences() { return {
 async get() { return state.value; }, async put(_key, value) { state.value = value; }, async flush() {}
}; } };`;
const stubUrl = 'data:text/javascript;base64,' + Buffer.from(stub).toString('base64');
register('data:text/javascript;base64,' + Buffer.from(`export function resolve(s,c,next) {
 if (s === '@kit.AbilityKit' || s === '@kit.ArkData') return {url:${JSON.stringify(stubUrl)},shortCircuit:true};
 return next(s,c); }`).toString('base64'), import.meta.url);
globalThis.AppStorage = { get: () => ({}) };
const { state } = await import(stubUrl);
const { saveAgentConversation, loadAgentConversations } = await import('../../entry/src/main/ets/model/agent/AgentConversationStore.ets');

const message = (id, text, reasoning = '') => ({ id, role: 'assistant', text, reasoning,
  reasoningIsSummary: false, kind: 'normal', clarification: null, expanded: false });
const audit = (messageId, name) => ({ messageId, callId: `call-${messageId}`, toolName: name,
  status: 'completed', providerRound: 1, sequence: 1, argumentsJson: '{}', outputJson: '{}',
  errorCode: '', errorPath: '', errorMessage: '', receivedKeys: [], allowedKeys: [], validTemplateJson: '',
  repeatCount: 0, argumentsTruncated: false, outputTruncated: false, diagnosticTruncated: false,
  expanded: false, legacySummary: '' });
const conversation = (messages, audits = []) => ({ id: 'history-test', mode: 'create', title: 'test', updatedAt: 1,
  setup: { mode: 'create', deckId: 1, deckName: 'Deck', notetypeId: 2, notetypeName: 'Type',
    fieldNames: ['Front'], noteTypeKind: 0, clozeFieldOrds: [], expanded: true },
  messages, audits, sources: [], results: [] });

test('history round trip retains actual reasoning, summary type and individual tool owners', async () => {
  state.value = '[]';
  const first = message(10, '', 'Need to clarify the topic.');
  const second = message(12, 'Next reply', 'Provider summary');
  second.reasoningIsSummary = true;
  await saveAgentConversation(conversation([first, second], [audit(10, 'request_clarification'), audit(12, 'search_notes')]));
  const [restored] = await loadAgentConversations();
  assert.equal(restored.messages[0].reasoning, first.reasoning);
  assert.equal(restored.messages[0].text, '');
  assert.equal(restored.messages[1].reasoningIsSummary, true);
  assert.deepEqual(restored.audits.map(a => a.messageId), [10, 12]);
  assert.deepEqual(restored.audits.map(a => a.toolName), ['request_clarification', 'search_notes']);
});

test('legacy history does not invent missing reasoning or tool ownership', async () => {
  const oldMessage = message(1, 'old reply');
  delete oldMessage.id;
  delete oldMessage.reasoning;
  const oldAudit = audit(1, 'search_notes');
  delete oldAudit.messageId;
  state.value = JSON.stringify([conversation([oldMessage], [oldAudit])]);
  const [restored] = await loadAgentConversations();
  assert.equal(restored.messages[0].reasoning, '');
  assert.equal(restored.messages[0].id, undefined);
  assert.equal(restored.audits[0].messageId, undefined);
});

test('reasoning history is bounded and redacted while retaining truncation disclosure', async () => {
  state.value = '[]';
  await saveAgentConversation(conversation([message(1, 'reply', 'Bearer abc-secret sk-abcdefghijk data:image/png;base64,aaaa'),
    ...Array.from({ length: 12 }, (_, i) => message(i + 2, 'reply', 'x'.repeat(25000)))]));
  const [restored] = await loadAgentConversations();
  assert.doesNotMatch(restored.messages[0].reasoning, /abc-secret|sk-abcdefghijk|base64/);
  assert.ok(restored.messages.reduce((n, m) => n + m.reasoning.length, 0) <= 200000);
  assert.equal(restored.messages[1].reasoningTruncated, true);
  await saveAgentConversation(restored);
  assert.equal((await loadAgentConversations())[0].messages[1].reasoningTruncated, true);
});
