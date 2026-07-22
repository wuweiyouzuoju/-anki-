// 检查数据库链路契约测试（T5）：
// - CollectionService 只经 BackendSession 走 BACKEND_COLLECTION(3) 的 CHECK_DATABASE(6)；
// - CheckDatabaseResponse 解码器字段符合 collection.proto（repeated string problems = 1）；
// - SettingsPanel「检查数据库」入口真实调用 checkDatabase()，busy 防重入，
//   结果（通过/问题列表）与错误透传均走面板内状态行。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { COLLECTION_METHOD, SERVICE } from '../../entry/src/main/ets/backend/ServiceIds.ts';
import { decodeCheckDatabaseResponse } from '../../entry/src/main/ets/proto/messages/CollectionMessages.ts';
import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const COLLECTION_SERVICE = 'entry/src/main/ets/backend/CollectionService.ts';
const SETTINGS_PANEL = 'entry/src/main/ets/components/SettingsPanel.ets';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('check database uses collection service id 3 and method index 6', () => {
  assert.equal(SERVICE.BACKEND_COLLECTION, 3, 'collection service id');
  assert.equal(COLLECTION_METHOD.CHECK_DATABASE, 6, 'CheckDatabase method index');
});

test('collection service wraps checkDatabase through BackendSession only', () => {
  const service = read(COLLECTION_SERVICE);

  assert.match(service, /BackendSession\.getInstance\(\)/);
  assert.doesNotMatch(service, /new BackendClient/, 'must go through BackendSession');

  assert.match(service, /async checkDatabase\(\): Promise<string\[\]>/);
  assert.match(service, /SERVICE\.BACKEND_COLLECTION, COLLECTION_METHOD\.CHECK_DATABASE, new Uint8Array\(0\)/,
    'empty request body, generic.Empty');
  assert.match(service, /decodeCheckDatabaseResponse\(response\)/);
});

test('check database decoder reads repeated problems, empty wire means pass', () => {
  const w = new ProtoWriter();
  w.writeString(1, '卡片表存在孤儿行');
  w.writeString(1, '复习日志时间戳异常');
  assert.deepEqual(decodeCheckDatabaseResponse(w.toBytes()), ['卡片表存在孤儿行', '复习日志时间戳异常']);

  assert.deepEqual(decodeCheckDatabaseResponse(new Uint8Array(0)), [],
    'no problems on the wire means the check passed');
});

test('settings panel wires check database entry to the service with busy guard', () => {
  const panel = read(SETTINGS_PANEL);

  assert.match(panel, /import \{ CollectionService \} from '\.\.\/backend\/CollectionService'/);
  assert.match(panel, /await this\.collectionService\.checkDatabase\(\)/,
    'entry really calls the service');
  assert.match(panel, /this\.runCheckDatabase\(\);/, 'row taps into the handler');

  assert.match(panel, /if \(this\.checkDbBusy\) \{[\s\S]*?return;/, 'reentrancy guard in handler');
  assert.match(panel, /\.enabled\(!this\.checkDbBusy\)/, 'row disabled while busy');
  assert.match(panel, /this\.checkDbBusy \? \$r\('app\.string\.check_db_running'\)/,
    'busy state visible on the row');
});

test('settings panel renders pass, problems and error outcomes', () => {
  const panel = read(SETTINGS_PANEL);

  assert.match(panel, /if \(this\.checkDbError !== ''\)/, 'error branch first');
  assert.match(panel, /Text\(this\.checkDbError\)/, 'error message passed through');
  const handler = panel.match(/runCheckDatabase\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(handler, null);
  assert.match(handler[0], /this\.checkDbError = error instanceof Error \? error\.message : `\$\{error\}`;/,
    'failure surfaces raw backend message');
  assert.match(handler[0], /finally \{\s*this\.checkDbBusy = false;/, 'busy always released');

  assert.match(panel, /this\.checkDbProblems\.length === 0/);
  assert.match(panel, /\$r\('app\.string\.check_db_passed'\)/, 'empty problems means pass');
  assert.match(panel, /\$r\('app\.string\.check_db_problems', this\.checkDbProblems\.length\)/,
    'problem count listed');
  assert.match(panel, /ForEach\(this\.checkDbProblems\.slice\(0, 3\)/,
    'problem content summary capped at first entries');
});

test('check database strings are resourced', () => {
  const strings = read(STRINGS);
  for (const name of ['check_db_title', 'check_db_hint', 'check_db_running',
    'check_db_passed', 'check_db_problems', 'check_db_failed']) {
    assert.match(strings, new RegExp(`"name": "${name}"`), `missing string ${name}`);
  }
});
