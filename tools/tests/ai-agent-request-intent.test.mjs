// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  explicitYearClozeRequested,
  inferRequestedCardCount,
} from '../../entry/src/main/ets/model/agent/AgentRequestIntent.ts';

test('explicit requested card counts work for Chinese, English and compact pinyin', () => {
  assert.equal(inferRequestedCardCount('生成5张中国现代史闪卡', 100), 5);
  assert.equal(inferRequestedCardCount('来5道年份填空题', 100), 5);
  assert.equal(inferRequestedCardCount('make 12 flashcards', 100), 12);
  assert.equal(inferRequestedCardCount('zhongguoxiandaishi5daonianfendetiankongti', 100), 5);
});

test('knowledge years and over-limit counts are not misread as card counts', () => {
  assert.equal(inferRequestedCardCount('1949年新中国成立', 100), 0);
  assert.equal(inferRequestedCardCount('生成101张卡', 100), 0);
  assert.equal(inferRequestedCardCount('随便来一点', 100), 0);
});

test('year-cloze intent is explicit across Chinese, English and compact pinyin', () => {
  assert.equal(explicitYearClozeRequested('生成5张中国现代史闪卡，年份就是填空部分'), true);
  assert.equal(explicitYearClozeRequested('考察年份，做成填空题'), true);
  assert.equal(explicitYearClozeRequested('make the year the cloze answer'), true);
  assert.equal(explicitYearClozeRequested('5daonianfendetiankongti'), true);
  assert.equal(explicitYearClozeRequested('1949年新中国成立'), false);
  assert.equal(explicitYearClozeRequested('生成普通填空题'), false);
});
