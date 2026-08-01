import assert from 'node:assert/strict';
import test from 'node:test';

import { 协议写入器 } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import {
  decodeBackendError,
  encodeBackendInit
} from '../../entry/src/main/ets/proto/messages/BackendMessages.ts';
import {
  decodeOpChangesWithCount,
  decodeOpChangesWithId,
  encodeOpenCollectionRequest
} from '../../entry/src/main/ets/proto/messages/CollectionMessages.ts';
import {
  decodeDeck,
  decodeDeckNames,
  decodeDeckTreeNode,
  encodeDeck,
  encodeDeckTreeRequest,
  encodeGetDeckNamesRequest
} from '../../entry/src/main/ets/proto/messages/DeckMessages.ts';
import {
  decodeImportResponse,
  encodeImportAnkiPackageRequest
} from '../../entry/src/main/ets/proto/messages/ImportExportMessages.ts';

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(' ');
}

test('OpenCollectionRequest encodes three paths in field order', () => {
  const bytes = encodeOpenCollectionRequest({
    collectionPath: '/c/collection.anki2',
    mediaFolderPath: '/c/media',
    mediaDbPath: '/c/media.db'
  });
  assert.equal(
    hex(bytes),
    '0a 13 2f 63 2f 63 6f 6c 6c 65 63 74 69 6f 6e 2e 61 6e 6b 69 32 ' +
      '12 08 2f 63 2f 6d 65 64 69 61 ' +
      '1a 0b 2f 63 2f 6d 65 64 69 61 2e 64 62'
  );
});

test('BackendInit encodes repeated langs, folder and server flag', () => {
  const bytes = encodeBackendInit({
    preferredLangs: ['zh-CN', 'en'],
    localeFolderPath: '/l',
    server: true
  });
  assert.equal(
    hex(bytes),
    '0a 05 7a 68 2d 43 4e 0a 02 65 6e 12 02 2f 6c 18 01'
  );
});

test('BackendError decodes message/kind/context and skips help/backtrace', () => {
  const w = new 协议写入器();
  w.写入字符串(1, 'collection is already open');
  w.写入变长整数(2, 5);
  w.写入变长整数(3, 0);
  w.写入字符串(4, 'openCollection');
  w.写入字符串(5, 'stack...');
  const info = decodeBackendError(w.转为字节());
  assert.equal(info.message, 'collection is already open');
  assert.equal(info.kind, 5);
  assert.equal(info.context, 'openCollection');
});

test('Deck roundtrips with common/normal sub-messages and reserved bytes', () => {
  const deck = {
    id: 1752902400123,
    name: '英语::四级',
    mtimeSecs: 1752902400,
    usn: 3,
    common: {
      studyCollapsed: false,
      browserCollapsed: true,
      lastDayStudied: 1024,
      newStudied: 5,
      learningStudied: 2,
      millisecondsStudied: 60000,
      other: new Uint8Array([0xde, 0xad])
    },
    normal: {
      configId: 1,
      extendNew: 0,
      extendReview: 0,
      description: 'desc',
      markdownDescription: false,
      reviewLimit: 200,
      newLimit: null,
      reviewLimitToday: { limit: 200, today: 7 },
      newLimitToday: null,
      desiredRetention: 0.9
    }
  };
  const decoded = decodeDeck(encodeDeck(deck));
  assert.equal(decoded.id, deck.id);
  assert.equal(decoded.name, deck.name);
  assert.equal(decoded.mtimeSecs, deck.mtimeSecs);
  assert.equal(decoded.usn, deck.usn);
  assert.equal(decoded.common.browserCollapsed, true);
  assert.equal(decoded.common.lastDayStudied, 1024);
  assert.deepEqual([...decoded.common.other], [0xde, 0xad]);
  assert.equal(decoded.normal.reviewLimit, 200);
  assert.equal(decoded.normal.newLimit, null);
  assert.deepEqual(decoded.normal.reviewLimitToday, { limit: 200, today: 7 });
  assert.ok(Math.abs(decoded.normal.desiredRetention - 0.9) < 1e-6);
});

test('Deck encoding omits default-valued fields like prost', () => {
  const bytes = encodeDeck({
    id: 0,
    name: '默认',
    mtimeSecs: 0,
    usn: 0,
    common: null,
    normal: null
  });
  assert.equal(hex(bytes), '12 06 e9 bb 98 e8 ae a4');
});

test('DeckTreeNode decodes nested children recursively', () => {
  const child = new 协议写入器();
  child.写入64位整数(1, 20);
  child.写入字符串(2, '四级');
  child.写入变长整数(8, 3);
  const root = new 协议写入器();
  root.写入64位整数(1, 10);
  root.写入字符串(2, '英语');
  root.写入子消息(3, child);
  root.写入变长整数(4, 0);
  root.写入变长整数(6, 11);
  root.写入变长整数(7, 2);
  root.写入变长整数(13, 100);
  root.写入变长整数(14, 150);
  root.写入布尔(16, false);

  const node = decodeDeckTreeNode(root.转为字节());
  assert.equal(node.deckId, 10);
  assert.equal(node.name, '英语');
  assert.equal(node.reviewCount, 11);
  assert.equal(node.learnCount, 2);
  assert.equal(node.totalInDeck, 100);
  assert.equal(node.totalIncludingChildren, 150);
  assert.equal(node.children.length, 1);
  assert.equal(node.children[0].deckId, 20);
  assert.equal(node.children[0].newCount, 3);
});

test('DeckTreeRequest encodes now timestamp only when non-zero', () => {
  assert.equal(encodeDeckTreeRequest(0).length, 0);
  const bytes = encodeDeckTreeRequest(1752902400);
  const w = new 协议写入器();
  w.写入64位整数(1, 1752902400);
  assert.equal(hex(bytes), hex(w.转为字节()));
});

test('GetDeckNamesRequest flags and DeckNames decoding', () => {
  assert.equal(encodeGetDeckNamesRequest(false, false).length, 0);
  assert.equal(hex(encodeGetDeckNamesRequest(true, true)), '08 01 10 01');

  const entry = new 协议写入器();
  entry.写入64位整数(1, 1);
  entry.写入字符串(2, '默认');
  const list = new 协议写入器();
  list.写入子消息(1, entry);
  const names = decodeDeckNames(list.转为字节());
  assert.deepEqual(names, [{ id: 1, name: '默认' }]);
});

test('OpChangesWithId / OpChangesWithCount extract scalars and skip changes', () => {
  const w = new 协议写入器();
  const changes = new 协议写入器();
  changes.写入布尔(3, true);
  w.写入子消息(1, changes);
  w.写入64位整数(2, 1752902400999);
  assert.equal(decodeOpChangesWithId(w.转为字节()), 1752902400999);

  const c = new 协议写入器();
  c.写入布尔(1, true);
  c.写入变长整数(2, 42);
  assert.equal(decodeOpChangesWithCount(c.转为字节()), 42);
});

test('ImportAnkiPackageRequest encodes path only', () => {
  const bytes = encodeImportAnkiPackageRequest('/f/四级.apkg');
  const w = new 协议写入器();
  w.写入字符串(1, '/f/四级.apkg');
  assert.equal(hex(bytes), hex(w.转为字节()));
});

test('ImportResponse tallies log buckets and found_notes', () => {
  const note = new 协议写入器();
  note.写入64位整数(1, 1);
  const log = new 协议写入器();
  log.写入子消息(1, note);
  log.写入子消息(1, note);
  log.写入子消息(2, note);
  log.写入子消息(3, note);
  log.写入变长整数(10, 99);
  const resp = new 协议写入器();
  const changes = new 协议写入器();
  changes.写入布尔(2, true);
  resp.写入子消息(1, changes);
  resp.写入子消息(2, log);

  const summary = decodeImportResponse(resp.转为字节());
  assert.deepEqual(summary, { newNotes: 2, updatedNotes: 1, duplicateNotes: 1, foundNotes: 99 });
});
