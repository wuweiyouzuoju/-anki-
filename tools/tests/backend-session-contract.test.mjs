// M3 契约测试：锁定服务/方法索引表（Anki 26.05 构建产物同源）与错误映射行为。
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CARD_RENDERING_METHOD,
  COLLECTION_METHOD,
  DECK_CONFIG_METHOD,
  DECKS_METHOD,
  IMPORT_EXPORT_METHOD,
  NATIVE_STATUS,
  SCHEDULER_METHOD,
  SERVICE
} from '../../entry/src/main/ets/backend/ServiceIds.ts';
import { BackendError, mapNativeError } from '../../entry/src/main/ets/backend/errors.ts';
import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';

// 索引与 target/**​/build/anki-*​/out/backend.rs（Anki 26.05）match 分支一一对应；
// 修改本表必须同时更新来源注释与升级 SOP 文档。
test('service ids match the generated backend.rs dispatch table', () => {
  assert.equal(SERVICE.BACKEND_COLLECTION, 3);
  assert.equal(SERVICE.BACKEND_DECKS, 7);
  assert.equal(SERVICE.BACKEND_DECK_CONFIG, 11);
  assert.equal(SERVICE.BACKEND_SCHEDULER, 13);
  assert.equal(SERVICE.BACKEND_CARD_RENDERING, 27);
  assert.equal(SERVICE.BACKEND_IMPORT_EXPORT, 39);
});

test('method ids match the generated backend.rs dispatch table', () => {
  assert.deepEqual({ ...COLLECTION_METHOD }, {
    OPEN: 0, CLOSE: 1, CREATE_BACKUP: 2, AWAIT_BACKUP_COMPLETION: 3,
    LATEST_PROGRESS: 4, SET_WANTS_ABORT: 5,
    CHECK_DATABASE: 6, GET_UNDO_STATUS: 7, UNDO: 8, REDO: 9
  });
  assert.deepEqual({ ...DECKS_METHOD }, {
    NEW_DECK: 0, ADD_DECK: 1, DECK_TREE: 4, GET_DECK_NAMES: 13,
    REMOVE_DECKS: 16, RENAME_DECK: 18, SET_CURRENT_DECK: 22, GET_CURRENT_DECK: 23
  });
  assert.deepEqual({ ...DECK_CONFIG_METHOD }, {
    GET_DECK_CONFIG: 1, GET_DECK_CONFIGS_FOR_UPDATE: 6, UPDATE_DECK_CONFIGS: 7
  });
  assert.deepEqual({ ...SCHEDULER_METHOD }, {
    GET_QUEUED_CARDS: 3, ANSWER_CARD: 4, SCHED_TIMING_TODAY: 5,
    COUNTS_FOR_DECK_TODAY: 10, CONGRATS_INFO: 11,
    RESTORE_BURIED_AND_SUSPENDED: 12, UNBURY_DECK: 13, BURY_OR_SUSPEND: 14,
    DESCRIBE_NEXT_STATES: 24
  });
  assert.deepEqual({ ...CARD_RENDERING_METHOD }, { EXTRACT_AV_TAGS: 3, RENDER_EXISTING_CARD: 6 });
  assert.deepEqual({ ...IMPORT_EXPORT_METHOD }, {
    IMPORT_COLLECTION_PACKAGE: 0, EXPORT_COLLECTION_PACKAGE: 1,
    IMPORT_ANKI_PACKAGE: 2, EXPORT_ANKI_PACKAGE: 4
  });
});

test('native status codes mirror rsharmony.h', () => {
  assert.deepEqual({ ...NATIVE_STATUS }, {
    OK: 0, INVALID_ARGUMENT: 1, HANDLE_NOT_FOUND: 2, BACKEND_ERROR: 3, NATIVE_FATAL: 4
  });
});

test('mapNativeError decodes BackendError protobuf details', () => {
  const w = new ProtoWriter();
  w.writeString(1, 'collection is already open');
  w.writeVarint(2, 5); // DB_ERROR
  w.writeString(4, 'openCollection');

  const err = mapNativeError({
    nativeStatus: NATIVE_STATUS.BACKEND_ERROR,
    details: w.toBytes(),
    message: 'Anki backend rejected the request'
  });
  assert.ok(err instanceof BackendError);
  assert.equal(err.message, 'collection is already open');
  assert.equal(err.kind, 5);
  assert.equal(err.context, 'openCollection');
  assert.equal(err.nativeStatus, NATIVE_STATUS.BACKEND_ERROR);
});

test('mapNativeError falls back to native message for non-backend failures', () => {
  const err = mapNativeError({ nativeStatus: NATIVE_STATUS.HANDLE_NOT_FOUND, message: 'backend handle not found' });
  assert.equal(err.message, 'backend handle not found');
  assert.equal(err.kind, 0);
  assert.equal(err.nativeStatus, NATIVE_STATUS.HANDLE_NOT_FOUND);

  const unknown = mapNativeError(new Error('boom'));
  assert.equal(unknown.nativeStatus, NATIVE_STATUS.NATIVE_FATAL);

  const corrupt = mapNativeError({ nativeStatus: NATIVE_STATUS.BACKEND_ERROR, details: new Uint8Array([0xff]), message: 'm' });
  assert.equal(corrupt.message, 'm');
});
