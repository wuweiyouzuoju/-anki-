// 撤销链路契约测试（T2）：
// - CollectionService 只经 BackendSession 走 BACKEND_COLLECTION(3) 的 7/8/9 方法索引；
// - UndoStatus/OpChangesAfterUndo 解码器字段符合 collection.proto；
// - StudyPage 撤销按钮真实接线 undo()，撤销后重新取卡，失败走 errorDetail；
// - redo 仅服务层封装备用，UI 不暴露（上游移动端惯例）。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { COLLECTION_METHOD, SERVICE } from '../../entry/src/main/ets/backend/ServiceIds.ts';
import {
  decodeOpChangesAfterUndo,
  decodeUndoStatus
} from '../../entry/src/main/ets/proto/messages/CollectionMessages.ts';
import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const COLLECTION_SERVICE = 'entry/src/main/ets/backend/CollectionService.ts';
const STUDY_PAGE = 'entry/src/main/ets/pages/StudyPage.ets';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('collection service method indexes map to GetUndoStatus/Undo/Redo 7/8/9', () => {
  assert.equal(SERVICE.BACKEND_COLLECTION, 3, 'collection service id');
  assert.equal(COLLECTION_METHOD.GET_UNDO_STATUS, 7);
  assert.equal(COLLECTION_METHOD.UNDO, 8);
  assert.equal(COLLECTION_METHOD.REDO, 9);
});

test('collection service wraps undo trio through BackendSession only', () => {
  const service = read(COLLECTION_SERVICE);

  assert.match(service, /BackendSession\.getInstance\(\)/);
  assert.doesNotMatch(service, /new BackendClient/, 'must go through BackendSession');

  assert.match(service, /async getUndoStatus\(\): Promise<UndoStatus>/);
  assert.match(service, /SERVICE\.BACKEND_COLLECTION, COLLECTION_METHOD\.GET_UNDO_STATUS, new Uint8Array\(0\)/);
  assert.match(service, /decodeUndoStatus\(response\)/);

  assert.match(service, /async undo\(\): Promise<OpChangesAfterUndo>/);
  assert.match(service, /SERVICE\.BACKEND_COLLECTION, COLLECTION_METHOD\.UNDO, new Uint8Array\(0\)/);
  assert.match(service, /decodeOpChangesAfterUndo\(response\)/);

  assert.match(service, /async redo\(\): Promise<OpChangesAfterUndo>/);
  assert.match(service, /SERVICE\.BACKEND_COLLECTION, COLLECTION_METHOD\.REDO, new Uint8Array\(0\)/);
});

test('undo status decoder reads labels and last step', () => {
  const w = new ProtoWriter();
  w.writeString(1, '复习卡片');
  w.writeString(2, '');
  w.writeVarint(3, 12);
  const status = decodeUndoStatus(w.toBytes());
  assert.deepEqual(status, { undo: '复习卡片', redo: '', lastStep: 12 });

  assert.deepEqual(decodeUndoStatus(new Uint8Array(0)), { undo: '', redo: '', lastStep: 0 },
    'empty wire means nothing to undo/redo');
});

test('op changes after undo decoder reads nested changes and new status', () => {
  const changes = new ProtoWriter();
  changes.writeBool(1, true);
  changes.writeBool(10, true);
  const newStatus = new ProtoWriter();
  newStatus.writeString(1, '复习卡片');
  newStatus.writeVarint(3, 7);
  const w = new ProtoWriter();
  w.writeMessage(1, changes);
  w.writeString(2, '复习卡片');
  w.writeInt64(3, 1720000000);
  w.writeMessage(4, newStatus);
  w.writeVarint(5, 3);

  const out = decodeOpChangesAfterUndo(w.toBytes());
  assert.equal(out.operation, '复习卡片');
  assert.equal(out.revertedToTimestamp, 1720000000);
  assert.equal(out.counter, 3);
  assert.equal(out.changes?.card, true);
  assert.equal(out.changes?.studyQueues, true);
  assert.equal(out.changes?.note, false);
  assert.equal(out.newStatus?.undo, '复习卡片');
  assert.equal(out.newStatus?.lastStep, 7);
});

test('study page refreshes undo availability on entry and after rating', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /import \{ CollectionService \} from '\.\.\/backend\/CollectionService'/);
  assert.match(page, /private async refreshUndoStatus\(\): Promise<void>/);
  assert.match(page, /await this\.collectionService\.getUndoStatus\(\)/);
  assert.match(page, /this\.undoAvailable = status\.undo\.length > 0/,
    'empty undo label means unavailable');
  // loadNextCard 同时覆盖「页面进入」与「评分成功后」两条路径（startSession/rate 均汇入）
  assert.match(page, /await this\.refreshUndoStatus\(\);\s*const queued = await this\.schedulerService\.getQueuedCards/,
    'undo status refreshes before every card fetch');
});

test('study page undo button is wired to undo then refetch', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /if \(this\.undoAvailable\) \{[\s\S]*?Button\(\$r\('app\.string\.study_undo'\)\)/,
    'undo button hidden when nothing to undo');
  assert.match(page, /this\.undoLast\(\);/, 'button taps into undo handler');

  assert.match(page, /if \(this\.answering \|\| !this\.undoAvailable\)/, 'undo reuses reentrancy guard');
  assert.match(page, /await this\.collectionService\.undo\(\);\s*await this\.loadNextCard\(\);/,
    'undone card returns to queue front, refetch required');
  const undoBody = page.match(/undoLast\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(undoBody, null);
  assert.match(undoBody[0], /this\.phase = 'error';/);
  assert.match(undoBody[0], /this\.errorDetail = error instanceof Error \? error\.message : `\$\{error\}`;/,
    'undo failure surfaces through existing error state');
});

test('redo stays service-only and undo strings are resourced', () => {
  const page = read(STUDY_PAGE);
  assert.doesNotMatch(page, /collectionService\.redo\(/, 'redo must not be exposed in study UI');

  const strings = read(STRINGS);
  assert.match(strings, /"name": "study_undo"/);
});
