// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

function read(relativePath) {
  return readFileSync(new URL(`../../${relativePath}`, import.meta.url), 'utf8');
}

test('C ABI header exposes only opaque handle operations and owned buffers', () => {
  const header = read('native/rsharmony/include/rsharmony.h');

  assert.match(header, /anki_backend_open\s*\(/);
  assert.match(header, /anki_backend_call\s*\(/);
  assert.match(header, /anki_backend_close\s*\(/);
  assert.match(header, /anki_buffer_free\s*\(/);
  assert.doesNotMatch(header, /Backend\s*\*/);
});

test('ArkTS native module surface remains narrow and asynchronous', () => {
  const declarations = read('native/napi_bridge/index.d.ts');

  assert.match(declarations, /openBackend\(init: Uint8Array\): number/);
  assert.match(declarations, /runMethodRaw[\s\S]*Promise<Uint8Array>/);
  assert.match(declarations, /closeBackend\(handle: number\): void/);
});

test('entry packages the authoritative native bridge declarations', () => {
  const localPackage = 'entry/src/main/cpp/types/libjidecards/oh-package.json5';
  const localTypes = 'entry/src/main/cpp/types/libjidecards/index.d.ts';

  assert.equal(
    existsSync(new URL(`../../${localPackage}`, import.meta.url)),
    true,
    `${localPackage} must exist for ohpm install`,
  );
  assert.equal(
    existsSync(new URL(`../../${localTypes}`, import.meta.url)),
    true,
    `${localTypes} must exist for ArkTS type checking`,
  );
  assert.equal(read(localPackage), read('native/napi_bridge/oh-package.json5'));
  assert.equal(read(localTypes), read('native/napi_bridge/index.d.ts'));
});

test('Harmony product targets API 23 with API 21 floor set by ibest-ui dependency', () => {
  const profile = read('build-profile.json5');

  // @ibestservices/ibest-ui 要求依赖方 compatibleSdkVersion >= 21，12 会导致 MergeProfile 00306004 构建失败
  assert.match(profile, /compatibleSdkVersion:\s*['"]6\.0\.1\(21\)['"]/);
  assert.match(profile, /targetSdkVersion:\s*['"]6\.1\.0\(23\)['"]/);
});
