// proto/messages 新增消息字节级测试：Collection/Scheduler/DeckConfig/Stats（Anki 26.05）
import assert from 'node:assert/strict';
import test from 'node:test';

import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import {
  decodeCheckDatabaseResponse,
  decodeOpChanges,
  decodeOpChangesAfterUndo,
  decodeUndoStatus
} from '../../entry/src/main/ets/proto/messages/CollectionMessages.ts';
import {
  BURY_SUSPEND_MODE_BURY_SCHED,
  decodeCongratsInfo,
  encodeBuryOrSuspendCardsRequest,
  encodeCardIds,
  encodeUnburyDeckRequest
} from '../../entry/src/main/ets/proto/messages/SchedulerMessages.ts';
import {
  decodeDeckConfig,
  decodeDeckConfigsForUpdate,
  decodeLimits,
  encodeDeckConfig,
  encodeDeckConfigId,
  encodeLimits,
  encodeUpdateDeckConfigsRequest
} from '../../entry/src/main/ets/proto/messages/DeckConfigMessages.ts';
import { decodeGraphsResponse, encodeGraphsRequest } from '../../entry/src/main/ets/proto/messages/StatsMessages.ts';

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(' ');
}

// ── Collection ──

test('UndoStatus decodes undo/redo/last_step', () => {
  const w = new ProtoWriter();
  w.writeString(1, 'Add Card');
  w.writeString(2, '');
  w.writeVarint(3, 7);
  const s = decodeUndoStatus(w.toBytes());
  assert.equal(s.undo, 'Add Card');
  assert.equal(s.redo, '');
  assert.equal(s.lastStep, 7);
});

test('OpChanges decodes all bool flags', () => {
  const w = new ProtoWriter();
  w.writeBool(1, true);   // card
  w.writeBool(3, true);   // deck
  w.writeBool(10, true);  // study_queues
  w.writeBool(11, true);  // deck_config
  w.writeBool(12, true);  // mtime
  const c = decodeOpChanges(w.toBytes());
  assert.equal(c.card, true);
  assert.equal(c.note, false);
  assert.equal(c.deck, true);
  assert.equal(c.studyQueues, true);
  assert.equal(c.deckConfig, true);
  assert.equal(c.mtime, true);
});

test('OpChangesAfterUndo decodes nested changes/status/counter', () => {
  const changes = new ProtoWriter();
  changes.writeBool(1, true); // card
  changes.writeBool(10, true); // study_queues

  const status = new ProtoWriter();
  status.writeString(1, '');
  status.writeString(2, 'Review Card');
  status.writeVarint(3, 2);

  const w = new ProtoWriter();
  w.writeMessage(1, changes);
  w.writeString(2, 'Add Card');
  w.writeInt64(3, 1752902400);
  w.writeMessage(4, status);
  w.writeVarint(5, 42);

  const o = decodeOpChangesAfterUndo(w.toBytes());
  assert.equal(o.changes.card, true);
  assert.equal(o.changes.studyQueues, true);
  assert.equal(o.operation, 'Add Card');
  assert.equal(o.revertedToTimestamp, 1752902400);
  assert.equal(o.newStatus.redo, 'Review Card');
  assert.equal(o.counter, 42);
});

test('CheckDatabaseResponse decodes repeated problems', () => {
  const w = new ProtoWriter();
  w.writeString(1, 'missing note');
  w.writeString(1, 'orphan card');
  assert.deepEqual(decodeCheckDatabaseResponse(w.toBytes()), ['missing note', 'orphan card']);
  assert.deepEqual(decodeCheckDatabaseResponse(new Uint8Array(0)), []);
});

// ── Scheduler ──

test('CongratsInfo decodes all fields', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 5);      // learn_remaining
  w.writeVarint(2, 3600);   // secs_until_next_learn
  w.writeBool(3, true);     // review_remaining
  w.writeBool(4, false);    // new_remaining
  w.writeBool(5, true);     // have_sched_buried
  w.writeBool(6, false);    // have_user_buried
  w.writeBool(7, false);    // is_filtered_deck
  w.writeBool(8, true);     // bridge_commands_supported
  w.writeString(9, 'desc'); // deck_description

  const c = decodeCongratsInfo(w.toBytes());
  assert.equal(c.learnRemaining, 5);
  assert.equal(c.secsUntilNextLearn, 3600);
  assert.equal(c.reviewRemaining, true);
  assert.equal(c.newRemaining, false);
  assert.equal(c.haveSchedBuried, true);
  assert.equal(c.haveUserBuried, false);
  assert.equal(c.isFilteredDeck, false);
  assert.equal(c.bridgeCommandsSupported, true);
  assert.equal(c.deckDescription, 'desc');
});

test('CardIds encodes packed repeated int64', () => {
  assert.equal(hex(encodeCardIds([1, 2, 3])), '0a 03 01 02 03');
  assert.equal(hex(encodeCardIds([])), '');
  assert.equal(hex(encodeCardIds([-1])), '0a 0a ff ff ff ff ff ff ff ff ff 01');
});

test('BuryOrSuspendCardsRequest encodes card_ids/note_ids/mode', () => {
  const bytes = encodeBuryOrSuspendCardsRequest([10, 20], [], BURY_SUSPEND_MODE_BURY_SCHED);
  const w = new ProtoWriter();
  w.writePackedInt64(1, [10, 20]);
  w.writeVarint(3, BURY_SUSPEND_MODE_BURY_SCHED);
  assert.equal(hex(bytes), hex(w.toBytes()));
});

test('UnburyDeckRequest encodes deck_id and mode', () => {
  const bytes = encodeUnburyDeckRequest(42, 1);
  const w = new ProtoWriter();
  w.writeInt64(1, 42);
  w.writeVarint(2, 1);
  assert.equal(hex(bytes), hex(w.toBytes()));
});

// ── DeckConfig ──

test('DeckConfigId encodes dcid only', () => {
  assert.equal(hex(encodeDeckConfigId(7)), '08 07');
  assert.equal(hex(encodeDeckConfigId(0)), '');
});

test('DeckConfig roundtrips with settings preservation', () => {
  const legacy = new ProtoWriter();
  legacy.writeVarint(16, 36500);    // maximum_review_interval（未建模）
  legacy.writeFloat(11, 2.5);       // initial_ease（未建模）
  legacy.writeBytes(255, new Uint8Array([0xab, 0xcd])); // other

  const settings = {
    learnSteps: [1, 10],
    newPerDay: 20,
    reviewsPerDay: 200,
    preserved: [legacy.toBytes()]
  };
  const config = {
    id: 1752902400123,
    name: '默认配置',
    mtimeSecs: 1752902400,
    usn: 0,
    config: settings
  };

  const encoded = encodeDeckConfig(config);
  const decoded = decodeDeckConfig(encoded);
  assert.equal(decoded.id, config.id);
  assert.equal(decoded.name, config.name);
  assert.deepEqual(decoded.config.learnSteps, [1, 10]);
  assert.equal(decoded.config.newPerDay, 20);
  assert.equal(decoded.config.reviewsPerDay, 200);
  // 未建模字段按块保留，再次编码后字节完全一致（update 回写不丢字段）
  assert.equal(decoded.config.maximumReviewInterval, 36500);
  assert.ok(Math.abs(decoded.config.initialEase - 2.5) < 1e-6);
  assert.deepEqual(decoded.config.other, new Uint8Array([0xab, 0xcd]));
  assert.equal(decoded.config.preserved.length, 0);
  assert.deepEqual(decodeDeckConfig(encodeDeckConfig(decoded)), decoded);
});

test('DeckConfig encoding omits defaults like prost', () => {
  // config 缺省（null）：全默认不产生任何字节
  const bare = encodeDeckConfig({ id: 0, name: '', mtimeSecs: 0, usn: 0, config: null });
  assert.equal(bare.length, 0);
  // config 存在但全默认：仅 field5 空消息（与 prost Some(默认) 一致）
  const withEmpty = encodeDeckConfig({
    id: 0,
    name: '',
    mtimeSecs: 0,
    usn: 0,
    config: { learnSteps: [], newPerDay: 0, reviewsPerDay: 0, preserved: [] }
  });
  assert.equal(hex(withEmpty), '2a 00');
});

test('Limits roundtrip with optional null defaults', () => {
  const limits = {
    review: 100,
    new: 20,
    reviewToday: null,
    newToday: null,
    reviewTodayActive: true,
    newTodayActive: false,
    desiredRetention: 0.85
  };
  const decoded = decodeLimits(encodeLimits(limits).toBytes());
  assert.equal(decoded.review, 100);
  assert.equal(decoded.new, 20);
  assert.equal(decoded.reviewToday, null);
  assert.equal(decoded.newToday, null);
  assert.equal(decoded.reviewTodayActive, true);
  assert.equal(decoded.newTodayActive, false);
  assert.ok(Math.abs(decoded.desiredRetention - 0.85) < 1e-6);
});

test('DeckConfigsForUpdate decodes nested structure', () => {
  const cfgW = new ProtoWriter();
  cfgW.writeInt64(1, 1);
  cfgW.writeString(2, '预设1');
  cfgW.writeVarint(9, 10);

  const extraW = new ProtoWriter();
  extraW.writeMessage(1, cfgW);
  extraW.writeVarint(2, 3);

  const limitsW = new ProtoWriter();
  limitsW.writeVarint(1, 100);
  limitsW.writeVarint(2, 20);

  const currentW = new ProtoWriter();
  currentW.writeString(1, '英语');
  currentW.writeInt64(2, 1);
  currentW.writePackedInt64(3, [1]);
  currentW.writeMessage(4, limitsW);

  const topW = new ProtoWriter();
  topW.writeMessage(1, extraW);
  topW.writeMessage(2, currentW);
  topW.writeBool(4, true);

  const view = decodeDeckConfigsForUpdate(topW.toBytes());
  assert.equal(view.allConfigs.length, 1);
  assert.equal(view.allConfigs[0].config.name, '预设1');
  assert.equal(view.allConfigs[0].useCount, 3);
  assert.equal(view.currentDeck.name, '英语');
  assert.equal(view.currentDeck.configId, 1);
  assert.deepEqual(view.currentDeck.parentConfigIds, [1]);
  assert.equal(view.currentDeck.limits.review, 100);
  assert.equal(view.schemaModified, true);
});

test('UpdateDeckConfigsRequest encodes full input', () => {
  const config = {
    id: 1,
    name: '预设1',
    mtimeSecs: 0,
    usn: 0,
    config: { learnSteps: [1], newPerDay: 10, reviewsPerDay: 100, preserved: [] }
  };
  const bytes = encodeUpdateDeckConfigsRequest({
    targetDeckId: 42,
    configs: [config],
    removedConfigIds: [7],
    mode: 0,
    cardStateCustomizer: '',
    limits: null,
    newCardsIgnoreReviewLimit: false,
    fsrs: false,
    applyAllParentLimits: false,
    fsrsReschedule: false,
    fsrsHealthCheck: false
  });

  const w = new ProtoWriter();
  w.writeInt64(1, 42);
  w.writeBytes(2, encodeDeckConfig(config));
  w.writePackedInt64(3, [7]);
  assert.equal(hex(bytes), hex(w.toBytes()));
});

// ── Stats ──

test('GraphsResponse decodes today counts and retrievability', () => {
  const todayW = new ProtoWriter();
  todayW.writeVarint(1, 100); // answer_count
  todayW.writeVarint(3, 80);  // correct_count
  todayW.writeVarint(5, 60);  // mature_count
  todayW.writeVarint(7, 40);  // review_count

  const retW = new ProtoWriter();
  retW.writeFloat(2, 0.92);   // average
  retW.writeFloat(3, 12.5);   // sum_by_card
  retW.writeFloat(4, 10.0);   // sum_by_note

  const topW = new ProtoWriter();
  topW.writeMessage(4, todayW);
  topW.writeMessage(12, retW);
  topW.writeBool(13, true);   // fsrs

  const view = decodeGraphsResponse(topW.toBytes());
  assert.equal(view.today.answerCount, 100);
  assert.equal(view.today.correctCount, 80);
  assert.equal(view.today.matureCount, 60);
  assert.equal(view.today.reviewCount, 40);
  assert.ok(Math.abs(view.retrievability.average - 0.92) < 1e-6);
  assert.equal(view.fsrs, true);
});

test('GraphsRequest encodes days only, search stays empty', () => {
  assert.equal(hex(encodeGraphsRequest(0)), '');
  assert.equal(hex(encodeGraphsRequest(30)), '10 1e');
});

test('GraphsResponse decodes per-day review counts map and skips time map', () => {
  // map 条目：field1=key（距今天数），field2=Reviews 子消息
  const entry0 = new ProtoWriter();
  entry0.writeVarint(1, 0); // 今天
  const reviews0 = new ProtoWriter();
  reviews0.writeVarint(1, 2); // learn
  reviews0.writeVarint(3, 3); // young
  entry0.writeMessage(2, reviews0);

  const entry3 = new ProtoWriter();
  entry3.writeVarint(1, 3); // 3 天前
  const reviews3 = new ProtoWriter();
  reviews3.writeVarint(2, 1); // relearn
  reviews3.writeVarint(4, 5); // mature
  reviews3.writeVarint(5, 1); // filtered
  entry3.writeMessage(2, reviews3);

  // time map（field2）首页不用，解码必须跳过而不串位
  const timeEntry = new ProtoWriter();
  timeEntry.writeVarint(1, 0);
  const timeReviews = new ProtoWriter();
  timeReviews.writeVarint(1, 999);
  timeEntry.writeMessage(2, timeReviews);

  const countsW = new ProtoWriter();
  countsW.writeMessage(1, entry0);
  countsW.writeMessage(1, entry3);
  countsW.writeMessage(2, timeEntry);

  const topW = new ProtoWriter();
  topW.writeMessage(9, countsW); // reviews

  const view = decodeGraphsResponse(topW.toBytes());
  assert.equal(view.reviewCountsByDaysAgo.size, 2);
  assert.deepEqual(view.reviewCountsByDaysAgo.get(0), {
    learn: 2, relearn: 0, young: 3, mature: 0, filtered: 0
  });
  assert.deepEqual(view.reviewCountsByDaysAgo.get(3), {
    learn: 0, relearn: 1, young: 0, mature: 5, filtered: 1
  });
});

test('GraphsResponse without reviews field yields null map', () => {
  const view = decodeGraphsResponse(new Uint8Array(0));
  assert.equal(view.reviewCountsByDaysAgo, null);
  assert.equal(view.today, null);
  assert.equal(view.retrievability, null);
  assert.equal(view.fsrs, false);
});
