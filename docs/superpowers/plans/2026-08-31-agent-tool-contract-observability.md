# Agent Tool Contract and Full Observability Implementation Plan

> **For Codex:** Execute this plan sequentially with test-driven development. Preserve unrelated dirty-worktree changes. Do not modify Anki Rust, protobuf, NAPI ABI, or the database schema. Never uninstall a HarmonyOS device; deploy only with `hdc install -r`.

**Goal:** Make every Agent tool call follow one schema-driven contract, return precise correctable diagnostics, stop identical failure loops early, and show every successful or failed call fully expanded with sanitized details.

**Architecture:** `AgentToolCatalog` is the single provider-visible source for JSON Schema, templates, and forbidden rules. `AgentToolSchemas` and the note validator produce typed diagnostics. `AgentRunner` turns each call into one evolving `AgentToolTrace`, returns the structured diagnostic to the model, and fingerprints repeated failures. The shared AI page renders and persists sanitized traces; all actual writes remain behind the existing draft and confirmation boundary.

**Tech Stack:** ArkTS/TypeScript, ArkUI, HarmonyOS Preferences, Node test runner, existing Responses adapters, existing Agent draft services.

---

## Task 1: Add the pure diagnostic and trace contract

**Files:**

- Create: `entry/src/main/ets/model/agent/AgentToolDiagnostics.ts`
- Modify: `entry/src/main/ets/model/agent/AgentTypes.ts`
- Create: `tools/tests/ai-agent-tool-diagnostics.test.mjs`

### Step 1: Write the failing pure tests

Add tests for:

- stable normalization: object key order does not change a tool-failure fingerprint;
- different path, tool name, or argument value does change the fingerprint;
- recursive sensitive-key redaction for `apiKey`, `authorization`, `bearer`, `token`, and `secret`;
- `data:` media replacement and explicit long-value truncation marker;
- safe JSON fallback when a model emits malformed JSON;
- a new trace has fixed ArkTS-friendly fields and defaults to `expanded: true`.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-tool-diagnostics.test.mjs
```

Expected: FAIL because the module and types do not exist.

### Step 2: Implement the minimum pure model

In `AgentToolDiagnostics.ts`, add:

- `AgentToolDiagnostic` with required `code`, `path`, `message`, `receivedKeys`, `allowedKeys`, and `validTemplateJson` fields;
- `AgentToolTrace` construction helpers with call ID, provider round, sequence, name, state, sanitized arguments/output, diagnostic fields, repeat count, truncation flags, and `expanded: true`;
- a single sanitizer used before UI and persistence;
- canonical JSON normalization and failure fingerprinting.

Keep all fields explicit and avoid HarmonyOS imports. Use bounded constants for individual text and complete trace sizes. Malformed JSON remains visible as sanitized raw text rather than crashing the Agent.

Extend `AgentEvent` in `AgentTypes.ts` with a required nullable `toolTrace` field while preserving `toolCall` for provider-normalizer compatibility. Update constructors across the codebase later in this plan; at this step, change the minimum pure constructors/tests needed to compile focused tests.

### Step 3: Run the focused tests

Run the same command and expect PASS.

---

## Task 2: Make the tool catalog the single model-visible contract

**Files:**

- Modify: `entry/src/main/ets/model/agent/ProviderProtocol.ts`
- Modify: `entry/src/main/ets/model/agent/AgentToolCatalog.ts`
- Modify: `tools/tests/ai-agent-provider-contract.test.mjs`
- Create: `tools/tests/ai-agent-tool-catalog-contract.test.mjs`

### Step 1: Write failing catalog contract tests

Assert that:

- every function tool has one JSON Schema, one non-empty standard template, and forbidden rules;
- each template parses and uses only top-level properties declared in its Schema;
- every template contains every required property;
- `propose_create_notes` puts `reason` only at the top level and each `notes[]` item contains only `fields`;
- the provider payload description contains the template and rules exactly once;
- no unsupported `strict` property is injected into the Responses payload.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-tool-catalog-contract.test.mjs tools/tests/ai-agent-provider-contract.test.mjs
```

Expected: FAIL because catalog metadata is absent.

### Step 2: Extend the provider tool type

Add required `exampleArgumentsJson` and `rules` fields to `ProviderFunctionTool`. Keep the actual wire tool fields unchanged: type, name, enriched description, and parameters.

### Step 3: Populate every tool from one catalog helper

Refactor `AgentToolCatalog.ts` so each tool declaration supplies:

- name and concise purpose;
- JSON Schema;
- valid example/template JSON;
- explicit forbidden rules.

For `propose_create_notes`, state in both English machine guidance and the JSON example that `reason` is top-level only, `notes[]` accepts only `fields`, and fields follow the real note-type order. Include the current batch limit in Schema and instructions, but do not hardcode a deck or note type.

### Step 4: Enrich provider-visible descriptions

`buildResponsesPayload()` should concatenate purpose, standard arguments template, and rules into one deterministic description. Do not send `strict` until the current Responses API officially supports it.

### Step 5: Run focused tests

Run the Task 2 test command and expect PASS.

---

## Task 3: Return exact schema paths and correction templates

**Files:**

- Modify: `entry/src/main/ets/model/agent/AgentToolSchemas.ts`
- Modify: `tools/tests/ai-agent-tool-safety.test.mjs`
- Modify: `tools/tests/ai-agent-tool-catalog-contract.test.mjs`

### Step 1: Write failing decoder tests

Add assertions that:

- `reason` at the `propose_create_notes` top level decodes successfully;
- `notes[0].reason` throws `AgentToolSchemaError` with `code=unexpected_property`, `path=notes[0].reason`, `receivedKeys=[fields,reason]`, `allowedKeys=[fields]`, and a valid template;
- malformed JSON, root type errors, top-level unknown keys, invalid IDs, missing note fields, invalid field types, and oversized arrays each expose a precise path and stable code;
- existing security tests still reject service/method/protobuf/database/raw RPC fields.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-tool-safety.test.mjs tools/tests/ai-agent-tool-catalog-contract.test.mjs
```

Expected: FAIL because errors currently contain only a generic code.

### Step 2: Upgrade `AgentToolSchemaError`

Give the error a required typed diagnostic and retain `.code` for existing callers. Add small helpers for missing property, unexpected property, invalid type/value, excessive batch, and note-array element paths.

Use the catalog template as `validTemplateJson`; do not copy a second handwritten template into the validator.

### Step 3: Make create-note validation path-aware

Validate root and nested keys independently. Do not rely on `Object.keys(item)` ordering. Report the first deterministic invalid path and include allowed/received keys.

Preserve all current batch, positive-ID, duplicate-ID, tag, and string constraints.

### Step 4: Run focused tests

Run the Task 3 test command and expect PASS.

---

## Task 4: Add explicit year-cloze intent and deterministic validation

**Files:**

- Modify: `entry/src/main/ets/model/agent/AgentRequestIntent.ts`
- Modify: `entry/src/main/ets/model/agent/AgentNoteValidation.ts`
- Modify: `entry/src/main/ets/backend/agent/AgentScope.ets`
- Modify: `entry/src/main/ets/backend/agent/CardAgentTools.ets`
- Modify: `entry/src/main/ets/pages/AI制卡页.ets`
- Modify: `tools/tests/ai-agent-request-intent.test.mjs`
- Modify: `tools/tests/ai-agent-card-tools-contract.test.mjs`

### Step 1: Write failing intent and note tests

Cover Chinese, English, and compact pinyin forms of “year is the blank”, and negative cases such as merely mentioning 1949 or asking a normal cloze question.

For an activated year constraint, assert every proposed note must have at least one allowed cloze answer containing a plausible four-digit year. Assert a normal cloze request remains unchanged.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-request-intent.test.mjs tools/tests/ai-agent-card-tools-contract.test.mjs
```

Expected: FAIL because the intent and constraint do not exist.

### Step 2: Implement request intent and per-turn scope constraint

Add `explicitYearClozeRequested(text)` in `AgentRequestIntent.ts`. Store the boolean as a resettable, per-turn create constraint on `AgentScope`; configure it in `AI制卡页.ets` immediately before the Runner starts.

Do not put user task state in a global or singleton.

### Step 3: Validate notes before draft registration

Extend `validateAgentNoteFields` with an explicit options value. Extract allowed cloze answers safely, then enforce a bounded plausible four-digit year only when requested. Throw a structured `AgentToolSchemaError` whose path points to the failing note/fields and whose template demonstrates a year cloze.

Keep semantic history correctness out of this validator.

### Step 4: Run focused tests

Run the Task 4 test command and expect PASS.

---

## Task 5: Emit complete traces and break identical failure loops

**Files:**

- Modify: `entry/src/main/ets/backend/agent/AgentRunner.ets`
- Modify: `entry/src/main/ets/backend/agent/AgentToolRegistry.ets`
- Modify: `entry/src/main/ets/model/agent/AgentTypes.ts`
- Modify: `tools/tests/ai-agent-runner-contract.test.mjs`
- Modify: `tools/tests/ai-agent-tool-diagnostics.test.mjs`

### Step 1: Write failing Runner contract tests

Assert source/runtime helpers guarantee:

- every accepted call emits a started trace with sanitized arguments, round and sequence;
- success emits sanitized `result.outputJson` on the same call ID;
- failure emits diagnostic path/template and the structured JSON becomes `function_call_output`;
- generic Registry errors are converted to a safe diagnostic;
- same tool + canonical args + diagnostic increments repeat count despite key order;
- second identical failure includes mandatory correction guidance;
- third identical failure emits `agent_repeated_tool_failure` and aborts before the general 8-round limit;
- changed args or a changed error path reset the identical-failure sequence;
- duplicate call IDs remain rejected and visible.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-runner-contract.test.mjs tools/tests/ai-agent-tool-diagnostics.test.mjs
```

Expected: FAIL because traces and repeat detection do not exist.

### Step 2: Replace generic error compression

In `AgentRunner.ets`:

- recognize `AgentToolSchemaError` diagnostics;
- wrap other stable errors into a generic safe diagnostic;
- return the complete sanitized diagnostic to the model;
- preserve exact raw arguments only long enough to execute the local Registry.

### Step 3: Emit one evolving trace per call

Create started/completed/failed events containing fixed-layout `AgentToolTrace` objects. Use the same call ID so UI updates one entry instead of appending three unrelated lines. Include Provider round and monotonically increasing tool sequence.

For successful draft tools, the output remains the proposal result, not a claim that data was saved.

### Step 4: Add bounded repeat detection

Keep a per-turn map of stable failure fingerprints. On repeat two, add correction text and template to the function output. On repeat three, emit the final failed trace plus error event and throw `AgentRunnerError('agent_repeated_tool_failure')`.

This early breaker is additional to, not a replacement for, provider/tool count safety limits.

### Step 5: Run focused tests

Run the Task 5 test command and expect PASS.

---

## Task 6: Persist safe typed audit details with legacy compatibility

**Files:**

- Modify: `entry/src/main/ets/model/agent/AgentConversationStore.ets`
- Modify: `tools/tests/ai-agent-history-contract.test.mjs`
- Modify: `tools/tests/ai-agent-tool-diagnostics.test.mjs`

### Step 1: Write failing history tests

Assert that:

- `AgentHistoryAudit` stores the fixed trace fields needed to reproduce the visible audit;
- save/load sanitizes arguments, output and diagnostic template again at the storage boundary;
- a bounded number and bounded total size of traces is retained;
- no API key, bearer value, token, media bytes, or hidden reasoning survives;
- legacy `{toolName,status}` audit entries load as visible legacy summaries instead of invalidating the conversation.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-history-contract.test.mjs tools/tests/ai-agent-tool-diagnostics.test.mjs
```

Expected: FAIL because history only stores two strings.

### Step 2: Upgrade and sanitize the history shape

Use a typed history audit with all fields required after normalization. `safeConversation()` must accept both the legacy and new layouts, create safe defaults, and run the shared sanitizer at persistence ingress and egress.

Keep Preferences key compatibility unless a migration is unavoidable; the safe loader should make a new key unnecessary.

### Step 3: Run focused tests

Run the Task 6 test command and expect PASS.

---

## Task 7: Render all calls fully expanded in the shared AI page

**Files:**

- Modify: `entry/src/main/ets/pages/AI制卡页.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `entry/src/main/resources/en_US/element/string.json`
- Modify: `tools/tests/ai-agent-entry-contract.test.mjs`
- Modify: `tools/tests/ai-agent-history-contract.test.mjs`

### Step 1: Write failing UI contract tests

Assert that:

- `聊天消息.工具过程` uses typed trace items rather than `string[]`;
- started events append one item, while completed/failed events update it by call ID;
- every new item has `expanded=true`;
- rendering includes round, tool, status, parameters, output, error code/path, actual keys, allowed keys, template, repeat count and truncation marker;
- successful and failed calls use the same detail component;
- the detail body is visible by default and can be manually collapsed;
- history saves/restores the typed trace without splitting strings on `:`;
- all user-facing labels exist in both Chinese and English resource files.

Run:

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-entry-contract.test.mjs tools/tests/ai-agent-history-contract.test.mjs
```

Expected: FAIL because the page renders plain status strings.

### Step 2: Replace string logs with trace state

Add ArkTS-friendly clone/update helpers. On `tool_started`, append one trace. On `tool_completed` or `tool_failed`, find the matching call ID and replace the item. Preserve event order and do not merge separate calls to the same tool.

### Step 3: Build the default-expanded detail UI

Create a page-local builder for each trace:

- header: round, sequence, localized state and tool name;
- body: argument JSON and either output or error diagnostic fields;
- visible redaction/truncation labels;
- expand/collapse affordance, with initial state expanded.

Long JSON must wrap and remain scrollable with the conversation; do not cap it to the prior single-line status display.

### Step 4: Wire typed history restoration

Remove colon splitting. Restore traces as their saved typed shape, defaulting legacy records to expanded summaries.

### Step 5: Add aligned i18n resources

Add matching base/en_US keys for every label and for `agent_repeated_tool_failure`. Keep the existing localization alignment test passing.

### Step 6: Run focused tests

Run the Task 7 test command and expect PASS.

---

## Task 8: Regression, documentation, build and device evidence

**Files:**

- Modify: `.trae/decisions.md`
- Modify: `PROJECT_CONTEXT.md`
- Modify if findings require: the focused files above only

### Step 1: Run all Agent-focused tests

```powershell
node --experimental-transform-types --import ./tools/tests/register-ts-hook.mjs --test tools/tests/ai-agent-*.test.mjs
```

Expected: all Agent tests PASS.

### Step 2: Run the full suite

```powershell
npm test
```

Expected: every test passes; record the exact count.

### Step 3: Run the production build

```powershell
npm run build:app
```

Expected: `BUILD SUCCESSFUL`; record the HAP path. Fix ArkTS type or linter errors rather than weakening the typed trace contract.

### Step 4: Update architecture decisions

Document:

- the catalog as the single tool-contract source;
- exact structured diagnostics and the three-strike identical-failure breaker;
- typed full audit visibility and privacy boundaries;
- explicit year-cloze deterministic validation;
- confirmation that Anki Rust/protobuf/NAPI/database boundaries were not changed.

Update `PROJECT_CONTEXT.md` only with stable new module/boundary facts, not transient debugging notes.

### Step 5: Install safely on available devices

List devices first, resolve the signed HAP, then use only:

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' -t <device> install -r <absolute-hap-path>
```

Never run an uninstall command. If no physical phone is connected, report simulator evidence separately and do not call it physical-device verification.

### Step 6: Perform UI and live-provider acceptance

On an available device:

1. Trigger a successful read tool and successful `propose_create_notes`; confirm one default-expanded trace per call with sanitized input/output.
2. Trigger a controlled invalid nested `reason`; confirm exact `notes[0].reason`, allowed keys and template are visible.
3. Confirm identical failure three stops early with the localized breaker message.
4. Request exactly five Chinese modern-history cloze cards with years as blanks; confirm exactly five editable drafts and every card contains a year cloze.
5. Reopen history and confirm the safe full traces remain visible.

Do not save test drafts into the user's real card collection unless the user explicitly asks; draft generation is sufficient for acceptance.

### Step 7: Final diff and verification review

Run:

```powershell
git diff --check
git status --short
```

Review the diff for unrelated edits, accidental secrets, Anki backend changes, placeholders, and missing i18n entries. Report exact tests, build, devices, remaining external blockers, and decisions made.

Do not commit or rewrite unrelated dirty-worktree changes unless the user separately requests it.
