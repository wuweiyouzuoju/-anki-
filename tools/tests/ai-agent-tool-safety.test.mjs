// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AgentToolSchemaError,
  decodeAgentToolArguments,
} from '../../entry/src/main/ets/model/agent/AgentToolSchemas.ts';
import {
  AgentScope,
  AgentScopeError,
} from '../../entry/src/main/ets/backend/agent/AgentScope.ets';
import { AgentToolRegistry } from '../../entry/src/main/ets/backend/agent/AgentToolRegistry.ets';

test('semantic tool arguments reject unknown and raw backend fields', () => {
  for (const json of [
    '{"noteIds":[1],"service":25}',
    '{"noteIds":[1],"method":7}',
    '{"noteIds":[1],"protobuf":"AAE="}',
    '{"noteIds":[1],"database":"collection.anki2"}',
    '{"noteIds":[1],"unexpected":true}',
  ]) {
    assert.throws(
      () => decodeAgentToolArguments('propose_delete_notes', json),
      (error) => error instanceof AgentToolSchemaError && error.code === 'unexpected_property',
    );
  }
});

test('tool arguments reject malformed JSON, invalid IDs and oversized arrays', () => {
  assert.throws(() => decodeAgentToolArguments('get_note_context', '{bad'), /invalid_tool_arguments/);
  assert.throws(() => decodeAgentToolArguments('get_note_context', '{"noteIds":[0]}'), /invalid_tool_arguments/);
  assert.throws(() => decodeAgentToolArguments(
    'propose_delete_cards',
    JSON.stringify({ cardIds: Array.from({ length: 1001 }, (_, index) => index + 1) }),
  ), /tool_batch_too_large/);
});

test('create-note schema reports the exact nested property and a valid correction template', () => {
  const valid = decodeAgentToolArguments('propose_create_notes', JSON.stringify({
    targetDeckId: 1,
    targetNotetypeId: 2,
    notes: [{ fields: ['front', 'back'] }],
    draftId: 'draft-1',
    reason: 'batch reason',
  }));
  assert.equal(valid.reason, 'batch reason');

  assert.throws(
    () => decodeAgentToolArguments('propose_create_notes', JSON.stringify({
      targetDeckId: 1,
      targetNotetypeId: 2,
      notes: [{ fields: ['front', 'back'], reason: 'wrong level' }],
      draftId: 'draft-1',
      reason: 'batch reason',
    })),
    (error) => {
      assert.equal(error instanceof AgentToolSchemaError, true);
      assert.equal(error.code, 'unexpected_property');
      assert.equal(error.path, 'notes[0].reason');
      assert.deepEqual(error.receivedKeys, ['fields', 'reason']);
      assert.deepEqual(error.allowedKeys, ['fields']);
      const template = JSON.parse(error.validTemplateJson);
      assert.deepEqual(Object.keys(template.notes[0]), ['fields']);
      assert.equal(typeof template.reason, 'string');
      return true;
    },
  );
});

test('schema diagnostics retain precise root, array and scalar paths', () => {
  const cases = [
    ['{bad', 'invalid_json', '$'],
    ['[]', 'invalid_type', '$'],
    ['{"noteIds":[1],"service":25}', 'unexpected_property', 'service'],
    ['{"noteIds":[0]}', 'invalid_value', 'noteIds[0]'],
  ];
  for (const [json, code, path] of cases) {
    assert.throws(
      () => decodeAgentToolArguments('get_note_context', json),
      (error) => error instanceof AgentToolSchemaError && error.code === code && error.path === path,
    );
  }
});

test('scope accepts only stable positive IDs registered in the current turn', () => {
  const scope = new AgentScope();
  scope.registerCardIds([10, 11]);
  scope.registerNoteIds([20]);
  scope.registerDeckIds([30]);
  scope.registerNotetypeIds([40]);

  assert.doesNotThrow(() => scope.assertCardIdsInScope([11]));
  assert.doesNotThrow(() => scope.assertNoteIdsInScope([20]));
  assert.throws(
    () => scope.assertCardIdsInScope([12]),
    (error) => error instanceof AgentScopeError && error.code === 'id_out_of_scope',
  );
  assert.throws(() => scope.registerNoteIds([0]), /invalid_stable_id/);
});

test('draft IDs can be registered only once per turn', () => {
  const scope = new AgentScope();
  assert.equal(scope.registerDraftId('draft-1'), true);
  assert.equal(scope.registerDraftId('draft-1'), false);
  assert.equal(scope.registerDraftId(''), false);
  scope.reset();
  assert.equal(scope.registerDraftId('draft-1'), true);
});

test('high-risk proposal schemas accept only their declared semantic fields', () => {
  const args = decodeAgentToolArguments(
    'propose_change_note_type',
    '{"noteIds":[7],"targetNotetypeId":9,"fieldMappingJson":"[0,1]","templateMappingJson":"[0]","draftId":"d7"}',
  );
  assert.deepEqual(args.noteIds, [7]);
  assert.equal(args.targetNotetypeId, 9);
  assert.equal(args.draftId, 'd7');
  assert.throws(
    () => decodeAgentToolArguments('propose_update_note_type_templates', '{"notetypeIds":[9],"url":"file:///x"}'),
    /invalid_tool_arguments/,
  );
});

test('high-risk registry handlers can only return drafts and expose no commit API', async () => {
  const registry = new AgentToolRegistry();
  registry.registerHighRiskDraft('propose_delete_notes', {
    async propose() {
      return {
        id: 'danger-1', risk: 'high_risk', summary: 'delete one note',
        affectedNoteIds: [7], affectedCardIds: [70], operations: [],
      };
    },
  });
  const result = await registry.execute({
    id: 'call-1', name: 'propose_delete_notes', argumentsJson: '{"noteIds":[7]}',
  });
  assert.equal(result.draft.risk, 'high_risk');
  assert.equal(typeof registry.commit, 'undefined');
  assert.equal(typeof registry.executeDraft, 'undefined');
});
