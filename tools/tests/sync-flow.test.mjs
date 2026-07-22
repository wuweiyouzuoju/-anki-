// SyncFlow 纯决策逻辑单测（M10-T14）：node:test + assert/strict。
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SYNC_COLLECTION_REQUIRED,
  SYNC_STATUS_REQUIRED
} from '../../entry/src/main/ets/proto/messages/SyncMessages.ts';
import {
  applyNewEndpoint,
  classifySyncError,
  decideCollectionOutcome,
  decideSyncAction,
  extractNewEndpoint
} from '../../entry/src/main/ets/model/SyncFlow.ts';

// ---- decideSyncAction ----

test('decideSyncAction NO_CHANGES -> none', () => {
  assert.equal(decideSyncAction({ required: SYNC_STATUS_REQUIRED.NO_CHANGES, newEndpoint: '' }), 'none');
});

test('decideSyncAction NORMAL_SYNC -> normal', () => {
  assert.equal(decideSyncAction({ required: SYNC_STATUS_REQUIRED.NORMAL_SYNC, newEndpoint: '' }), 'normal');
});

test('decideSyncAction FULL_SYNC -> fullSync', () => {
  assert.equal(decideSyncAction({ required: SYNC_STATUS_REQUIRED.FULL_SYNC, newEndpoint: '' }), 'fullSync');
});

test('decideSyncAction unknown required -> fullSync (conservative fallback)', () => {
  assert.equal(decideSyncAction({ required: 99, newEndpoint: '' }), 'fullSync');
});

// ---- decideCollectionOutcome ----

function collectionResp(required) {
  return { hostNumber: 0, serverMessage: '', required, newEndpoint: '', serverMediaUsn: 0 };
}

test('decideCollectionOutcome NO_CHANGES -> done', () => {
  assert.equal(decideCollectionOutcome(collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES)), 'done');
});

test('decideCollectionOutcome NORMAL_SYNC -> done', () => {
  assert.equal(decideCollectionOutcome(collectionResp(SYNC_COLLECTION_REQUIRED.NORMAL_SYNC)), 'done');
});

test('decideCollectionOutcome FULL_SYNC -> fullSync', () => {
  assert.equal(decideCollectionOutcome(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_SYNC)), 'fullSync');
});

test('decideCollectionOutcome FULL_DOWNLOAD -> fullDownload', () => {
  assert.equal(decideCollectionOutcome(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_DOWNLOAD)), 'fullDownload');
});

test('decideCollectionOutcome FULL_UPLOAD -> fullUpload', () => {
  assert.equal(decideCollectionOutcome(collectionResp(SYNC_COLLECTION_REQUIRED.FULL_UPLOAD)), 'fullUpload');
});

test('decideCollectionOutcome unknown required -> fullSync (conservative fallback)', () => {
  assert.equal(decideCollectionOutcome(collectionResp(42)), 'fullSync');
});

// ---- extractNewEndpoint ----

test('extractNewEndpoint reads endpoint from SyncStatusResponse', () => {
  assert.equal(
    extractNewEndpoint({ required: SYNC_STATUS_REQUIRED.NORMAL_SYNC, newEndpoint: 'https://sync2.example.com' }),
    'https://sync2.example.com'
  );
});

test('extractNewEndpoint returns empty string when SyncStatusResponse has none', () => {
  assert.equal(extractNewEndpoint({ required: SYNC_STATUS_REQUIRED.NO_CHANGES, newEndpoint: '' }), '');
});

test('extractNewEndpoint reads endpoint from SyncCollectionResponse', () => {
  const resp = collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES);
  resp.newEndpoint = 'https://sync3.example.com';
  assert.equal(extractNewEndpoint(resp), 'https://sync3.example.com');
});

test('extractNewEndpoint returns empty string when SyncCollectionResponse has none', () => {
  assert.equal(extractNewEndpoint(collectionResp(SYNC_COLLECTION_REQUIRED.NO_CHANGES)), '');
});

// ---- applyNewEndpoint ----

test('applyNewEndpoint returns new object with updated endpoint, original untouched', () => {
  const auth = { hkey: 'hk', endpoint: 'https://old.example.com', ioTimeoutSecs: 60 };
  const updated = applyNewEndpoint(auth, 'https://new.example.com');
  assert.notEqual(updated, auth);
  assert.deepEqual(updated, { hkey: 'hk', endpoint: 'https://new.example.com', ioTimeoutSecs: 60 });
  // 原对象不可变
  assert.equal(auth.endpoint, 'https://old.example.com');
});

test('applyNewEndpoint preserves hkey and ioTimeoutSecs', () => {
  const auth = { hkey: 'session-key', endpoint: '', ioTimeoutSecs: 30 };
  const updated = applyNewEndpoint(auth, 'https://new.example.com');
  assert.equal(updated.hkey, 'session-key');
  assert.equal(updated.ioTimeoutSecs, 30);
});

test('applyNewEndpoint with empty endpoint returns the same object as-is', () => {
  const auth = { hkey: 'hk', endpoint: 'https://keep.example.com', ioTimeoutSecs: 0 };
  assert.equal(applyNewEndpoint(auth, ''), auth);
});

// ---- classifySyncError ----

test("classifySyncError 'HTTP 401' -> auth", () => {
  assert.equal(classifySyncError(new Error('HTTP 401')), 'auth');
});

test("classifySyncError 'authentication failed' -> auth", () => {
  assert.equal(classifySyncError(new Error('authentication failed')), 'auth');
});

test("classifySyncError 'network timeout' -> network", () => {
  assert.equal(classifySyncError(new Error('network timeout')), 'network');
});

test("classifySyncError 'connection refused' -> network", () => {
  assert.equal(classifySyncError(new Error('connection refused')), 'network');
});

test("classifySyncError 'some random error' -> other", () => {
  assert.equal(classifySyncError(new Error('some random error')), 'other');
});

// ---- classifySyncError with BackendError.kind（优先于正则） ----
// 后端返回的 message 是中文本地化文案（如"网络错误..."），英文正则无法匹配；
// 用 BackendError.kind 数字（来自 protobuf Kind 枚举）分类与文案语言无关。

test("classifySyncError kind=6 (NETWORK_ERROR) -> network, even if message is Chinese", () => {
  assert.equal(classifySyncError(new Error('网络错误，请检查网络后重试'), 6), 'network');
});

test("classifySyncError kind=7 (SYNC_AUTH_ERROR) -> auth, even if message has no 'auth' keyword", () => {
  assert.equal(classifySyncError(new Error('用户名或密码错误'), 7), 'auth');
});

test("classifySyncError kind=8 (SYNC_OTHER_ERROR) -> other", () => {
  assert.equal(classifySyncError(new Error('sync other'), 8), 'other');
});

test("classifySyncError kind=23 (SYNC_SERVER_MESSAGE) -> other", () => {
  assert.equal(classifySyncError(new Error('server message'), 23), 'other');
});

test("classifySyncError kind=undefined falls back to regex matching", () => {
  assert.equal(classifySyncError(new Error('connection refused'), undefined), 'network');
});

test("classifySyncError kind=0 (INVALID_INPUT) falls back to regex when message has 'network' keyword", () => {
  // kind=0 不在已知同步错误枚举里，fallback 到正则，正则命中 'network' -> 'network'
  assert.equal(classifySyncError(new Error('network unreachable'), 0), 'network');
});
