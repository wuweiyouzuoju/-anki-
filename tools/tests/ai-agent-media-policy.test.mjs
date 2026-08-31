// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  agentContextFieldHasOmittedMedia,
  sanitizeAgentContextField,
} from '../../entry/src/main/ets/model/agent/AgentMediaPolicy.ts';

test('provider context omits unsupported Anki image/audio payloads but keeps surrounding text', () => {
  const raw = 'term <img src="data:image/png;base64,SECRET"> [sound:voice.mp3] meaning';
  const safe = sanitizeAgentContextField(raw);
  assert.equal(safe.includes('SECRET'), false);
  assert.equal(safe.includes('voice.mp3'), false);
  assert.match(safe, /term/);
  assert.match(safe, /meaning/);
  assert.equal(agentContextFieldHasOmittedMedia(raw), true);
  assert.equal(agentContextFieldHasOmittedMedia('plain text'), false);
});
