import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SYNC_COLLECTION_REQUIRED,
  SYNC_STATUS_REQUIRED
} from '../../entry/src/main/ets/proto/messages/SyncMessages.ts';
import {
  应用新端点,
  分类同步错误,
  判定集合同步走向,
  判定同步动作,
  提取新端点
} from '../../entry/src/main/ets/model/同步流程.ts';

test('判定同步动作 NO_CHANGES -> none', () => {
  assert.equal(判定同步动作({ required: SYNC_STATUS_REQUIRED.NO_CHANGES, newEndpoint: '' }), 'none');
});

test('判定同步动作 NORMAL_SYNC -> normal', () => {
  assert.equal(判定同步动作({ required: SYNC_STATUS_REQUIRED.NORMAL_SYNC, newEndpoint: '' }), 'normal');
});

test('判定同步动作 FULL_SYNC -> fullSync', () => {
  assert.equal(判定同步动作({ required: SYNC_STATUS_REQUIRED.FULL_SYNC, newEndpoint: '' }), 'fullSync');
});

test('判定同步动作 unknown required -> fullSync (conservative fallback)', () => {
  assert.equal(判定同步动作({ required: 99, newEndpoint: '' }), 'fullSync');
});

function collectionResp(required) {
  return { hostNumber: 0, serverMessage: '', required, newEndpoint: '', serverMediaUsn: 0 };
}

test('判定集合同步走向 NO_CHANGES -> done', () => {
  assert.equal(判定集合同步走向(collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES)), 'done');
});

test('判定集合同步走向 NORMAL_SYNC -> done', () => {
  assert.equal(判定集合同步走向(collectionResp(SYNC_COLLECTION_REQUIRED.NORMAL_SYNC)), 'done');
});

test('判定集合同步走向 FULL_SYNC -> fullSync', () => {
  assert.equal(判定集合同步走向(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_SYNC)), 'fullSync');
});

test('判定集合同步走向 FULL_DOWNLOAD -> fullDownload', () => {
  assert.equal(判定集合同步走向(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_DOWNLOAD)), 'fullDownload');
});

test('判定集合同步走向 FULL_UPLOAD -> fullUpload', () => {
  assert.equal(判定集合同步走向(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_UPLOAD)), 'fullUpload');
});

test('判定集合同步走向 unknown required -> fullSync (conservative fallback)', () => {
  assert.equal(判定集合同步走向(collectionResp(42)), 'fullSync');
});

test('提取新端点 reads endpoint from SyncStatusResponse', () => {
  assert.equal(
    提取新端点({ required: SYNC_STATUS_REQUIRED.NORMAL_SYNC, newEndpoint: 'https://sync2.example.com' }),
    'https://sync2.example.com'
  );
});

test('提取新端点 returns empty string when SyncStatusResponse has none', () => {
  assert.equal(提取新端点({ required: SYNC_STATUS_REQUIRED.NO_CHANGES, newEndpoint: '' }), '');
});

test('提取新端点 reads endpoint from SyncCollectionResponse', () => {
  const resp = collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES);
  resp.newEndpoint = 'https://sync3.example.com';
  assert.equal(提取新端点(resp), 'https://sync3.example.com');
});

test('提取新端点 returns empty string when SyncCollectionResponse has none', () => {
  assert.equal(提取新端点(collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES)), '');
});

test('应用新端点 returns new object with updated endpoint, original untouched', () => {
  const auth = { hkey: 'hk', endpoint: 'https://old.example.com', ioTimeoutSecs: 60 };
  const updated = 应用新端点(auth, 'https://new.example.com');
  assert.notEqual(updated, auth);
  assert.deepEqual(updated, { hkey: 'hk', endpoint: 'https://new.example.com', ioTimeoutSecs: 60 });
  assert.equal(auth.endpoint, 'https://old.example.com');
});

test('应用新端点 preserves hkey and ioTimeoutSecs', () => {
  const auth = { hkey: 'session-key', endpoint: '', ioTimeoutSecs: 30 };
  const updated = 应用新端点(auth, 'https://new.example.com');
  assert.equal(updated.hkey, 'session-key');
  assert.equal(updated.ioTimeoutSecs, 30);
});

test('应用新端点 with empty endpoint returns the same object as-is', () => {
  const auth = { hkey: 'hk', endpoint: 'https://keep.example.com', ioTimeoutSecs: 0 };
  assert.equal(应用新端点(auth, ''), auth);
});

test("分类同步错误 'HTTP 401' -> auth", () => {
  assert.equal(分类同步错误(new Error('HTTP 401')), 'auth');
});

test("分类同步错误 'authentication failed' -> auth", () => {
  assert.equal(分类同步错误(new Error('authentication failed')), 'auth');
});

test("分类同步错误 'network timeout' -> network", () => {
  assert.equal(分类同步错误(new Error('network timeout')), 'network');
});

test("分类同步错误 'connection refused' -> network", () => {
  assert.equal(分类同步错误(new Error('connection refused')), 'network');
});

test("分类同步错误 'some random error' -> other", () => {
  assert.equal(分类同步错误(new Error('some random error')), 'other');
});

test("分类同步错误 kind=6 (NETWORK_ERROR) -> network, even if message is Chinese", () => {
  assert.equal(分类同步错误(new Error('网络错误，请检查网络后重试'), 6), 'network');
});

test("分类同步错误 kind=7 (SYNC_AUTH_ERROR) -> auth, even if message has no 'auth' keyword", () => {
  assert.equal(分类同步错误(new Error('用户名或密码错误'), 7), 'auth');
});

test("分类同步错误 kind=8 (SYNC_OTHER_ERROR) -> other", () => {
  assert.equal(分类同步错误(new Error('sync other'), 8), 'other');
});

test("分类同步错误 kind=23 (SYNC_SERVER_MESSAGE) -> other", () => {
  assert.equal(分类同步错误(new Error('server message'), 23), 'other');
});

test("分类同步错误 kind=undefined falls back to regex matching", () => {
  assert.equal(分类同步错误(new Error('connection refused'), undefined), 'network');
});

test("分类同步错误 kind=0 (INVALID_INPUT) falls back to regex when message has 'network' keyword", () => {
  assert.equal(分类同步错误(new Error('network unreachable'), 0), 'network');
});
