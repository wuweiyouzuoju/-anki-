// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';

import { agentFunctionTools } from '../../entry/src/main/ets/model/agent/AgentToolCatalog.ts';
import { buildResponsesPayload } from '../../entry/src/main/ets/model/agent/ProviderProtocol.ts';

test('every Agent tool exposes one parseable schema, template and forbidden-rules contract', () => {
  const tools = agentFunctionTools(25, 'edit');
  assert.ok(tools.length >= 10);
  for (const tool of tools) {
    const schema = JSON.parse(tool.parametersJson);
    const example = JSON.parse(tool.exampleArgumentsJson);
    assert.equal(schema.type, 'object', tool.name);
    assert.equal(typeof tool.rules, 'string', tool.name);
    assert.ok(tool.rules.length > 0, tool.name);
    assert.deepEqual(
      Object.keys(example).filter((key) => !(key in schema.properties)),
      [],
      `${tool.name} template contains undeclared properties`,
    );
    for (const required of schema.required) {
      assert.ok(required in example, `${tool.name} template misses required ${required}`);
    }
  }
});

test('create-note template makes the only valid reason placement unambiguous', () => {
  const tool = agentFunctionTools(5, 'create').find((item) => item.name === 'propose_create_notes');
  assert.ok(tool);
  const example = JSON.parse(tool.exampleArgumentsJson);
  assert.equal(typeof example.reason, 'string');
  assert.deepEqual(Object.keys(example.notes[0]), ['fields']);
  assert.match(tool.rules, /reason.*top level/i);
  assert.match(tool.rules, /notes\[\].*fields/i);
});

test('provider sends schema plus the standard template and rules without unsupported strict mode', () => {
  const functionTools = agentFunctionTools(5, 'create');
  const payload = JSON.parse(buildResponsesPayload({
    apiKey: 'not-serialized', baseUrl: 'https://api.deepseek.com', model: 'deepseek-v4-flash',
    instructions: 'test', input: [], functionTools, searchMode: 'off',
    requiresSearchEvidence: false, requiresDraft: true, expectedDraftCount: 5,
    reasoningEffort: 'low', maxOutputTokens: 1000,
  }));
  for (const sent of payload.tools) {
    const source = functionTools.find((item) => item.name === sent.name);
    assert.ok(source);
    assert.match(sent.description, /Standard arguments template:/);
    assert.match(sent.description, /Rules:/);
    assert.equal(sent.description.split(source.exampleArgumentsJson).length - 1, 1);
    assert.equal('strict' in sent, false);
  }
});
