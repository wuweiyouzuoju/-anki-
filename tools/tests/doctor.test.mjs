import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluateEnvironment, projectToolchainCommands } from '../doctor.mjs';

test('resolves the workspace-local Rust toolchain without changing global PATH', () => {
  const commands = projectToolchainCommands('C:/workspace/work/toolchains');
  const exe = process.platform === 'win32' ? '\\.exe' : '';

  assert.match(commands.rustc, new RegExp(`work[\\\\/]toolchains[\\\\/]cargo[\\\\/]bin[\\\\/]rustc${exe}$`));
  assert.match(commands.cargo, new RegExp(`work[\\\\/]toolchains[\\\\/]cargo[\\\\/]bin[\\\\/]cargo${exe}$`));
});

test('reports required and optional toolchain gaps separately', () => {
  const result = evaluateEnvironment({
    node: '22.0.0',
    git: '2.50.0',
    devEcoRoot: 'C:/DevEco',
    harmonyApi: 23,
    java: '21.0.0',
    rustc: null,
    cargo: null,
    ohosClang: 'C:/DevEco/clang.exe',
    cmake: 'C:/DevEco/cmake.exe',
    ninja: 'C:/DevEco/ninja.exe',
    hvigor: 'C:/DevEco/hvigorw.bat'
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.missingRequired, ['rustc', 'cargo']);
  assert.deepEqual(result.missingOptional, []);
});

test('rejects a compile SDK below the locked API 23 baseline', () => {
  const result = evaluateEnvironment({
    node: '22.0.0',
    git: '2.50.0',
    devEcoRoot: 'C:/DevEco',
    harmonyApi: 18,
    java: '21.0.0',
    rustc: '1.92.0',
    cargo: '1.92.0',
    ohosClang: 'clang',
    cmake: 'cmake',
    ninja: 'ninja',
    hvigor: 'hvigor'
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /compile SDK API 23/);
});

test('accepts the fully pinned toolchain', () => {
  const result = evaluateEnvironment({
    node: '22.0.0',
    git: '2.50.0',
    devEcoRoot: 'C:/DevEco',
    harmonyApi: 23,
    java: '21.0.0',
    rustc: '1.92.0',
    cargo: '1.92.0',
    ohosClang: 'clang',
    cmake: 'cmake',
    ninja: 'ninja',
    hvigor: 'hvigor'
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.problems, []);
});

test('requires the bundled Java runtime used to package HAP files', () => {
  const result = evaluateEnvironment({
    node: '22.0.0',
    git: '2.50.0',
    devEcoRoot: 'C:/DevEco',
    harmonyApi: 23,
    java: null,
    rustc: '1.92.0',
    cargo: '1.92.0',
    ohosClang: 'clang',
    cmake: 'cmake',
    ninja: 'ninja',
    hvigor: 'hvigor'
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.missingRequired, ['java']);
});
