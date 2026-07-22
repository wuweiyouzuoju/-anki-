// scheduler / card_rendering 消息编解码字节级测试（Anki 26.05）。
import assert from 'node:assert/strict';
import test from 'node:test';

import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import {
  decodeQueuedCards,
  decodeSchedTimingToday,
  decodeSchedulingStates,
  decodeStringList,
  encodeCardAnswer,
  encodeCardId,
  encodeGetQueuedCardsRequest,
  encodeSchedulingStates,
  QUEUE_REVIEW,
  RATING_GOOD
} from '../../entry/src/main/ets/proto/messages/SchedulerMessages.ts';
import {
  decodeRenderCardResponse,
  encodeRenderExistingCardRequest
} from '../../entry/src/main/ets/proto/messages/CardRenderingMessages.ts';

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(' ');
}

test('GetQueuedCardsRequest encodes fetch limit and intraday flag', () => {
  assert.equal(hex(encodeGetQueuedCardsRequest(50, true)), '08 32 10 01');
  assert.equal(hex(encodeGetQueuedCardsRequest(0, false)), '');
});

test('SchedulingStates keeps five raw state blobs for opaque round-trip', () => {
  const w = new ProtoWriter();
  w.writeBytes(1, new Uint8Array([0x0a, 0x01])); // current
  w.writeBytes(2, new Uint8Array([0x0b, 0x02])); // again
  w.writeBytes(3, new Uint8Array([0x0c, 0x03])); // hard
  w.writeBytes(4, new Uint8Array([0x0d, 0x04])); // good
  w.writeBytes(5, new Uint8Array([0x0e, 0x05])); // easy

  const states = decodeSchedulingStates(w.toBytes());
  assert.deepEqual([...states.current], [0x0a, 0x01]);
  assert.deepEqual([...states.easy], [0x0e, 0x05]);

  // 原样回写后字节完全一致：作答/DescribeNextStates 的保真通道
  assert.equal(hex(encodeSchedulingStates(states)), hex(w.toBytes()));
});

test('QueuedCards decodes nested card summary, queue and states', () => {
  const cardMsg = new ProtoWriter();
  cardMsg.writeInt64(1, 100); // id
  cardMsg.writeInt64(2, 200); // note_id
  cardMsg.writeInt64(3, 300); // deck_id
  cardMsg.writeVarint(12, 9); // reps：学习链路不需要，应被跳过

  const statesMsg = new ProtoWriter();
  statesMsg.writeBytes(4, new Uint8Array([0x21])); // good

  const queued = new ProtoWriter();
  queued.writeMessage(1, cardMsg);
  queued.writeVarint(2, QUEUE_REVIEW);
  queued.writeMessage(3, statesMsg);
  const context = new ProtoWriter();
  context.writeString(1, '英语');
  queued.writeMessage(4, context); // context 应被跳过

  const resp = new ProtoWriter();
  resp.writeMessage(1, queued);
  resp.writeVarint(2, 7); // new_count
  resp.writeVarint(3, 3); // learning_count
  resp.writeVarint(4, 11); // review_count

  const view = decodeQueuedCards(resp.toBytes());
  assert.equal(view.cards.length, 1);
  assert.equal(view.cards[0].cardId, 100);
  assert.equal(view.cards[0].noteId, 200);
  assert.equal(view.cards[0].deckId, 300);
  assert.equal(view.cards[0].queue, QUEUE_REVIEW);
  assert.deepEqual([...view.cards[0].states.good], [0x21]);
  assert.equal(view.newCount, 7);
  assert.equal(view.learningCount, 3);
  assert.equal(view.reviewCount, 11);
});

test('CardAnswer encodes all six fields in proto order', () => {
  const bytes = encodeCardAnswer({
    cardId: 123,
    currentState: new Uint8Array([0xaa]),
    newState: new Uint8Array([0xbb, 0xcc]),
    rating: RATING_GOOD,
    answeredAtMillis: 1000,
    millisecondsTaken: 500
  });
  assert.equal(
    hex(bytes),
    '08 7b 12 01 aa 1a 02 bb cc 20 02 28 e8 07 30 f4 03'
  );
});

test('CardAnswer omits AGAIN rating and empty states (proto3 defaults)', () => {
  const bytes = encodeCardAnswer({
    cardId: 1,
    currentState: new Uint8Array(0),
    newState: new Uint8Array(0),
    rating: 0, // AGAIN
    answeredAtMillis: 0,
    millisecondsTaken: 0
  });
  assert.equal(hex(bytes), '08 01');
});

test('CardId encodes cid field', () => {
  assert.equal(hex(encodeCardId(1752902400123)), hex((() => {
    const w = new ProtoWriter();
    w.writeInt64(1, 1752902400123);
    return w.toBytes();
  })()));
});

test('SchedTimingToday decodes days_elapsed and next_day_at', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 5432);
  w.writeInt64(2, 1752998400);
  const timing = decodeSchedTimingToday(w.toBytes());
  assert.equal(timing.daysElapsed, 5432);
  assert.equal(timing.nextDayAt, 1752998400);
});

test('StringList decodes repeated vals (DescribeNextStates output)', () => {
  const w = new ProtoWriter();
  w.writeString(1, '1分钟');
  w.writeString(1, '10分钟');
  w.writeString(1, '4天');
  assert.deepEqual(decodeStringList(w.toBytes()), ['1分钟', '10分钟', '4天']);
});

test('RenderExistingCardRequest encodes card_id only', () => {
  assert.equal(hex(encodeRenderExistingCardRequest(42)), '08 2a');
});

test('RenderCardResponse decodes mixed text/replacement nodes and flags', () => {
  const textNode = new ProtoWriter();
  textNode.writeString(1, '问题：');

  const replMsg = new ProtoWriter();
  replMsg.writeString(1, 'Front');
  replMsg.writeString(2, '世界');
  replMsg.writeString(3, 'cloze:Front');
  replMsg.writeString(3, 'hint');
  const replNode = new ProtoWriter();
  replNode.writeMessage(2, replMsg);

  const resp = new ProtoWriter();
  resp.writeMessage(1, textNode);
  resp.writeMessage(1, replNode);
  resp.writeMessage(2, textNode); // answer 侧复用同一节点即可验证解码
  resp.writeString(3, '.card { font-size: 20px; }');
  resp.writeBool(4, true);
  resp.writeBool(5, false);

  const rendered = decodeRenderCardResponse(resp.toBytes());
  assert.equal(rendered.questionNodes.length, 2);
  assert.equal(rendered.questionNodes[0].text, '问题：');
  assert.equal(rendered.questionNodes[0].replacement, null);
  assert.equal(rendered.questionNodes[1].text, null);
  assert.equal(rendered.questionNodes[1].replacement.fieldName, 'Front');
  assert.equal(rendered.questionNodes[1].replacement.currentText, '世界');
  assert.deepEqual(rendered.questionNodes[1].replacement.filters, ['cloze:Front', 'hint']);
  assert.equal(rendered.answerNodes.length, 1);
  assert.equal(rendered.css, '.card { font-size: 20px; }');
  assert.equal(rendered.latexSvg, true);
  assert.equal(rendered.isEmpty, false);
});
