// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SYNC_COLLECTION_REQUIRED,
  SYNC_STATUS_REQUIRED,
  decodeBoolResponse,
  decodeMediaSyncStatusResponse,
  decodeSyncAuth,
  decodeSyncCollectionResponse,
  decodeSyncStatusResponse,
  encodeEmptyRequest,
  encodeFullUploadOrDownloadRequest,
  encodeMediaSyncProgress,
  encodeStringRequest,
  encodeSyncAuth,
  encodeSyncCollectionRequest,
  encodeSyncLoginRequest
} from '../../entry/src/main/ets/proto/messages/SyncMessages.ts';

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(' ');
}

test('encodeSyncLoginRequest writes username + password golden bytes', () => {
  const bytes = encodeSyncLoginRequest({ username: 'u@x.com', password: 'pw', endpoint: '' });
  assert.equal(hex(bytes), '0a 07 75 40 78 2e 63 6f 6d 12 02 70 77');
});

test('encodeSyncLoginRequest writes optional endpoint as field 3', () => {
  const bytes = encodeSyncLoginRequest({ username: '', password: '', endpoint: 'https://sync.example.com' });
  assert.equal(bytes[0], 0x1a);
  assert.equal(bytes[1], 24);
  assert.equal(bytes.length, 2 + 24);
});

test('encodeSyncLoginRequest omits all default values -> empty bytes', () => {
  const bytes = encodeSyncLoginRequest({ username: '', password: '', endpoint: '' });
  assert.equal(bytes.length, 0);
});

test('SyncAuth roundtrip with all fields', () => {
  const auth = { hkey: 'abc123', endpoint: 'https://sync.example.com', ioTimeoutSecs: 60 };
  const decoded = decodeSyncAuth(encodeSyncAuth(auth));
  assert.deepEqual(decoded, auth);
});

test('SyncAuth roundtrip with optional fields absent', () => {
  const auth = { hkey: 'key', endpoint: '', ioTimeoutSecs: 0 };
  const decoded = decodeSyncAuth(encodeSyncAuth(auth));
  assert.deepEqual(decoded, auth);
});

test('encodeSyncLoginRequest golden bytes with endpoint', () => {
  const req = { username: 'user', password: 'pass', endpoint: 'ep' };
  const bytes = encodeSyncLoginRequest(req);
  assert.equal(hex(bytes), '0a 04 75 73 65 72 12 04 70 61 73 73 1a 02 65 70');
});

test('decodeSyncStatusResponse reads field1 required + field4 new_endpoint', () => {
  const prefix = new Uint8Array([0x08, 0x01, 0x22, 11]);
  const suffix = new TextEncoder().encode('https://new');
  const bytes = new Uint8Array(prefix.length + suffix.length);
  bytes.set(prefix, 0);
  bytes.set(suffix, prefix.length);
  const resp = decodeSyncStatusResponse(bytes);
  assert.equal(resp.required, SYNC_STATUS_REQUIRED.NORMAL_SYNC);
  assert.equal(resp.newEndpoint, 'https://new');
});

test('decodeSyncStatusResponse empty bytes -> defaults', () => {
  const resp = decodeSyncStatusResponse(new Uint8Array(0));
  assert.equal(resp.required, SYNC_STATUS_REQUIRED.NO_CHANGES);
  assert.equal(resp.newEndpoint, '');
});

test('decodeSyncStatusResponse skips legacy unknown fields 2 and 3', () => {
  const bytes = new Uint8Array([0x10, 0x63, 0x1a, 0x01, 0x78, 0x08, 0x02]);
  const resp = decodeSyncStatusResponse(bytes);
  assert.equal(resp.required, SYNC_STATUS_REQUIRED.FULL_SYNC);
  assert.equal(resp.newEndpoint, '');
});

test('SyncCollectionRequest roundtrip via encode + decodeSyncAuth on nested field', () => {
  const req = {
    auth: { hkey: 'hk', endpoint: '', ioTimeoutSecs: 0 },
    syncMedia: true
  };
  const bytes = encodeSyncCollectionRequest(req);
  assert.equal(hex(bytes), '0a 04 0a 02 68 6b 10 01');
});

test('decodeSyncCollectionResponse reads all fields', () => {
  const bytes = new Uint8Array([
    0x08, 0x07,
    0x12, 0x02, 0x6f, 0x6b,
    0x18, 0x03,
    0x22, 0x02, 0x65, 0x70,
    0x28, 0x2a
  ]);
  const resp = decodeSyncCollectionResponse(bytes);
  assert.equal(resp.hostNumber, 7);
  assert.equal(resp.serverMessage, 'ok');
  assert.equal(resp.required, SYNC_COLLECTION_REQUIRED.FULL_DOWNLOAD);
  assert.equal(resp.newEndpoint, 'ep');
  assert.equal(resp.serverMediaUsn, 42);
});

test('decodeSyncCollectionResponse reads negative server_media_usn (10-byte sign-extend varint)', () => {
  const bytes = new Uint8Array([0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]);
  const resp = decodeSyncCollectionResponse(bytes);
  assert.equal(resp.serverMediaUsn, -1);
});

test('encodeFullUploadOrDownloadRequest negative serverUsn produces 10-byte sign-extend varint', () => {
  const bytes = encodeFullUploadOrDownloadRequest({
    auth: { hkey: '', endpoint: '', ioTimeoutSecs: 0 },
    upload: false,
    serverUsn: -1
  });
  assert.equal(hex(bytes), '18 ff ff ff ff ff ff ff ff ff 01');
});

test('encodeFullUploadOrDownloadRequest positive serverUsn is plain varint', () => {
  const bytes = encodeFullUploadOrDownloadRequest({
    auth: { hkey: '', endpoint: '', ioTimeoutSecs: 0 },
    upload: false,
    serverUsn: 300
  });
  assert.equal(hex(bytes), '18 ac 02');
});

test('encodeFullUploadOrDownloadRequest null serverUsn omits field 3', () => {
  const bytes = encodeFullUploadOrDownloadRequest({
    auth: { hkey: '', endpoint: '', ioTimeoutSecs: 0 },
    upload: true,
    serverUsn: null
  });
  assert.equal(hex(bytes), '10 01');
});

test('MediaSyncStatusResponse nested progress roundtrip', () => {
  const progress = { checked: '1/2', added: '+3', removed: '-0' };
  const progressBytes = encodeMediaSyncProgress(progress);
  const prefix = new Uint8Array([0x08, 0x01, 0x12, progressBytes.length]);
  const bytes = new Uint8Array(prefix.length + progressBytes.length);
  bytes.set(prefix, 0);
  bytes.set(progressBytes, prefix.length);
  const resp = decodeMediaSyncStatusResponse(bytes);
  assert.equal(resp.active, true);
  assert.deepEqual(resp.progress, progress);
});

test('MediaSyncStatusResponse empty bytes -> defaults with empty progress strings', () => {
  const resp = decodeMediaSyncStatusResponse(new Uint8Array(0));
  assert.equal(resp.active, false);
  assert.deepEqual(resp.progress, { checked: '', added: '', removed: '' });
});

test('encodeEmptyRequest returns empty bytes', () => {
  assert.equal(encodeEmptyRequest().length, 0);
});

test('encodeStringRequest writes field 1 string', () => {
  const bytes = encodeStringRequest('cert-pem');
  assert.equal(hex(bytes), '0a 08 63 65 72 74 2d 70 65 6d');
});

test('decodeBoolResponse reads field 1 bool', () => {
  assert.equal(decodeBoolResponse(new Uint8Array([0x08, 0x01])), true);
  assert.equal(decodeBoolResponse(new Uint8Array([0x08, 0x00])), false);
  assert.equal(decodeBoolResponse(new Uint8Array(0)), false);
});
