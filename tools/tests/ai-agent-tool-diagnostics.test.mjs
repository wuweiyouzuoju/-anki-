// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AgentToolFailureTracker,
  buildAgentToolFailureFingerprint,
  createStartedAgentToolTrace,
  sanitizeAgentToolJson,
} from '../../entry/src/main/ets/model/agent/AgentToolDiagnostics.ts';

const diagnostic = {
  code: 'unexpected_property',
  path: 'notes[0].reason',
  message: 'reason is only allowed at the top level',
  receivedKeys: ['fields', 'reason'],
  allowedKeys: ['fields'],
  validTemplateJson: '{"notes":[{"fields":["<field>"]}],"reason":"<batch reason>"}',
};

test('tool failure fingerprints ignore JSON object key order but retain meaningful differences', () => {
  const first = buildAgentToolFailureFingerprint(
    'propose_create_notes', '{"targetDeckId":1,"notes":[{"fields":["x"],"reason":"r"}]}', diagnostic,
  );
  const reordered = buildAgentToolFailureFingerprint(
    'propose_create_notes', '{"notes":[{"reason":"r","fields":["x"]}],"targetDeckId":1}', diagnostic,
  );
  assert.equal(first, reordered);
  assert.notEqual(first, buildAgentToolFailureFingerprint(
    'propose_create_notes', '{"targetDeckId":2,"notes":[{"fields":["x"],"reason":"r"}]}', diagnostic,
  ));
  assert.notEqual(first, buildAgentToolFailureFingerprint(
    'propose_update_notes', '{"targetDeckId":1,"notes":[{"fields":["x"],"reason":"r"}]}', diagnostic,
  ));
  assert.notEqual(first, buildAgentToolFailureFingerprint(
    'propose_create_notes', '{"targetDeckId":1,"notes":[{"fields":["x"],"reason":"r"}]}',
    { ...diagnostic, path: 'notes[1].reason' },
  ));
});

test('identical failures escalate on the second attempt and abort on the third', () => {
  const tracker = new AgentToolFailureTracker();
  const first = tracker.record('propose_create_notes', '{"a":1,"b":2}', diagnostic);
  const second = tracker.record('propose_create_notes', '{"b":2,"a":1}', diagnostic);
  const third = tracker.record('propose_create_notes', '{"a":1,"b":2}', diagnostic);
  assert.deepEqual(first, { count: 1, requireCorrection: false, shouldAbort: false });
  assert.deepEqual(second, { count: 2, requireCorrection: true, shouldAbort: false });
  assert.deepEqual(third, { count: 3, requireCorrection: true, shouldAbort: true });
  assert.deepEqual(
    tracker.record('propose_create_notes', '{"a":2,"b":2}', diagnostic),
    { count: 1, requireCorrection: false, shouldAbort: false },
  );
});

test('tool JSON sanitizer redacts nested secrets and media before truncating', () => {
  const safe = sanitizeAgentToolJson(JSON.stringify({
    apiKey: 'sk-top-secret',
    nested: {
      authorization: 'Bearer hidden-value',
      token: 'token-value',
      harmless: 'visible',
      media: 'data:image/png;base64,AAAA',
    },
  }), 4096);
  assert.equal(safe.truncated, false);
  assert.doesNotMatch(safe.text, /top-secret|hidden-value|token-value|base64,AAAA/);
  assert.match(safe.text, /\[REDACTED\]/);
  assert.match(safe.text, /\[MEDIA OMITTED\]/);
  assert.match(safe.text, /visible/);

  const clipped = sanitizeAgentToolJson(JSON.stringify({ value: 'x'.repeat(500) }), 120);
  assert.equal(clipped.truncated, true);
  assert.match(clipped.text, /truncated=true/);
  assert.ok(clipped.text.length <= 120);
});

test('malformed model JSON remains safely visible instead of crashing diagnostics', () => {
  const safe = sanitizeAgentToolJson('{"token":"secret", bad data:image/png;base64,AAAA', 4096);
  assert.doesNotMatch(safe.text, /secret|base64,AAAA/);
  assert.match(safe.text, /\[REDACTED\]|token/);
  assert.match(safe.text, /\[MEDIA OMITTED\]/);
});

test('a new tool trace has a fixed layout and is collapsed by default', () => {
  const trace = createStartedAgentToolTrace({
    id: 'call-1', name: 'list_decks', argumentsJson: '{"query":"中国","limit":20}',
  }, 2, 3);
  assert.deepEqual(trace, {
    callId: 'call-1',
    toolName: 'list_decks',
    status: 'started',
    providerRound: 2,
    sequence: 3,
    argumentsJson: '{"query":"中国","limit":20}',
    outputJson: '',
    errorCode: '',
    errorPath: '',
    errorMessage: '',
    receivedKeys: [],
    allowedKeys: [],
    validTemplateJson: '',
    repeatCount: 0,
    argumentsTruncated: false,
    outputTruncated: false,
    diagnosticTruncated: false,
    expanded: false,
    legacySummary: '',
  });
});
