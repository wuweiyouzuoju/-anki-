// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  组合牌组路径,
  平铺牌组树,
  规范化牌组路径,
  可见牌组行
} from '../../entry/src/main/ets/model/牌组层级.ets';
import { 构建主页快照 } from '../../entry/src/main/ets/model/主页快照映射器.ets';
import { 牌组色调 } from '../../entry/src/main/ets/model/主页模型.ets';

function node(partial) {
  return {
    deckId: 0,
    name: '',
    level: 0,
    collapsed: false,
    reviewCount: 0,
    learnCount: 0,
    newCount: 0,
    totalInDeck: 0,
    totalIncludingChildren: 0,
    filtered: false,
    children: [],
    ...partial
  };
}

test('hierarchy paths normalize Chinese and ASCII separators while rejecting empty segments', () => {
  assert.equal(规范化牌组路径(' 英语：词汇 '), '英语::词汇');
  assert.equal(规范化牌组路径('英语:词汇'), '英语::词汇');
  assert.equal(规范化牌组路径('英语：:词汇'), '英语::词汇');
  assert.equal(规范化牌组路径('英语::词汇'), '英语::词汇');
  assert.equal(规范化牌组路径(''), null);
  assert.equal(规范化牌组路径('英语::'), null);
  assert.equal(规范化牌组路径('::词汇'), null);
  assert.equal(组合牌组路径('英语：词汇', '语法'), '英语::词汇::语法');
  assert.equal(组合牌组路径('', '英语:词汇'), '英语::词汇');
});

test('hierarchy flattens preorder rows and reveals descendants only after every ancestor expands', () => {
  const grandchild = node({ deckId: 12, name: '语法', totalIncludingChildren: 4 });
  const child = node({ deckId: 11, name: '词汇', totalIncludingChildren: 6, children: [grandchild] });
  const parent = node({ deckId: 10, name: '英语', totalIncludingChildren: 20, children: [child] });
  const rows = 平铺牌组树(node({ children: [parent] }));

  assert.deepEqual(rows.map((row) => [row.name, row.fullName, row.depth, row.parentId]), [
    ['英语', '英语', 0, ''],
    ['词汇', '英语::词汇', 1, '10'],
    ['语法', '英语::词汇::语法', 2, '11']
  ]);
  assert.deepEqual(rows[2].ancestorIds, ['10', '11']);
  assert.equal(rows[0].totalCards, 20, 'aggregate totals remain supplied by the backend');
  assert.deepEqual(可见牌组行(rows, new Set()), [rows[0]]);
  assert.deepEqual(可见牌组行(rows, new Set(['10'])), [rows[0], rows[1]]);
  assert.deepEqual(可见牌组行(rows, new Set(['10', '11'])), rows);
});

test('empty root yields an empty formal snapshot', () => {
  const snap = 构建主页快照(node({}));
  assert.equal(snap.decks.length, 0);
  assert.equal(snap.today.pendingCount, 0);
  assert.equal(snap.today.completedCount, 0);
  assert.equal(snap.today.deckCount, 0);
  assert.equal(snap.memory.state, 'load_error', 'no graphs => load_error (no today data to show)');
  assert.equal(snap.reviewCountsByDate.size, 0);
});

test('all deck rows keep backend aggregate counts without double counting', () => {
  const child = node({
    deckId: 11, name: '子牌组', newCount: 2, learnCount: 1, reviewCount: 3,
    totalInDeck: 5, totalIncludingChildren: 5
  });
  const parent = node({
    deckId: 10, name: '父牌组', newCount: 6, learnCount: 4, reviewCount: 9,
    totalInDeck: 8, totalIncludingChildren: 13, children: [child]
  });
  const snap = 构建主页快照(node({ children: [parent] }));

  assert.equal(snap.decks.length, 2, 'the complete preorder tree is listed');
  const deck = snap.decks[0];
  assert.equal(deck.id, '10');
  assert.equal(deck.name, '父牌组');
  assert.equal(deck.newCount, 6);
  assert.equal(deck.learningCount, 4);
  assert.equal(deck.reviewCount, 9);
  assert.equal(deck.totalCards, 13, 'total cards include children');
  assert.equal(deck.fullName, '父牌组');
  assert.equal(deck.depth, 0);
  assert.equal(deck.parentId, '');
  assert.equal(deck.hasChildren, true);
  assert.deepEqual(deck.ancestorIds, []);

  const childDeck = snap.decks[1];
  assert.equal(childDeck.name, '子牌组');
  assert.equal(childDeck.fullName, '父牌组::子牌组');
  assert.equal(childDeck.depth, 1);
  assert.equal(childDeck.parentId, '10');
  assert.equal(childDeck.totalCards, 5, 'child count remains its own backend count');
  assert.deepEqual(childDeck.ancestorIds, ['10']);

  assert.equal(snap.today.completedCount, 0, 'completedCount falls back to 0 when graphs is null');
  assert.equal(snap.today.pendingCount, 19, 'pending sums top-level rows only');
  assert.equal(snap.today.deckCount, 2, 'deck count covers nested decks');
});

test('completed today is sourced from graphs.today.answerCount (full learn/review/relearn/filtered scope, all decks aggregated)', () => {
  const withToday = graphs({
    today: {
      answerCount: 42, answerMillis: 0, correctCount: 0, matureCorrect: 0,
      matureCount: 0, learnCount: 10, reviewCount: 20, relearnCount: 5, earlyReviewCount: 7
    }
  });
  const snap = 构建主页快照(node({}), withToday);
  assert.equal(snap.today.completedCount, 42, 'completedCount mirrors graphs.today.answerCount');

  assert.equal(构建主页快照(node({}), graphs({})).today.completedCount, 0);
  assert.equal(构建主页快照(node({}), null).today.completedCount, 0);
});

test('fallback tone is stable per deckId (independent of position)', () => {
  const root = node({
    children: [1, 2, 3, 4, 5].map((i) => node({ deckId: i, name: `d${i}` }))
  });
  const snap = 构建主页快照(root);
  assert.deepEqual(snap.decks.map((d) => d.tone), [
    牌组色调.Purple, 牌组色调.Mint, 牌组色调.Amber, 牌组色调.Blue, 牌组色调.Purple
  ]);
});

test('fallback tone unchanged after reordering via orderOverrides', () => {
  const root = node({
    children: [1, 2, 3, 4, 5].map((i) => node({ deckId: i, name: `d${i}` }))
  });
  const orderOverrides = new Map([['', ['5', '4', '3', '2', '1']]]);
  const snap = 构建主页快照(root, null, new Date(), null, null, orderOverrides);
  assert.deepEqual(snap.decks.map((d) => d.tone), [
    牌组色调.Purple, 牌组色调.Blue, 牌组色调.Amber, 牌组色调.Mint, 牌组色调.Purple
  ]);
});

function graphs(partial) {
  return {
    today: null,
    retrievability: null,
    reviewCountsByDaysAgo: null,
    fsrs: false,
    ...partial
  };
}

test('review counts map day-offset buckets to local calendar dates', () => {
  const data = graphs({
    reviewCountsByDaysAgo: new Map([
      [0, { learn: 2, relearn: 1, young: 3, mature: 4, filtered: 1 }],
      [-2, { learn: 0, relearn: 0, young: 5, mature: 0, filtered: 0 }],
      [-4, { learn: 0, relearn: 0, young: 0, mature: 0, filtered: 0 }]
    ])
  });
  const now = new Date(2026, 6, 2, 12, 0, 0);
  const snap = 构建主页快照(node({}),data, now);

  assert.equal(snap.reviewCountsByDate.size, 2, 'zero-total days are omitted');
  assert.equal(snap.reviewCountsByDate.get('2026-07-02'), 11, 'kinds are summed');
  assert.equal(snap.reviewCountsByDate.get('2026-06-30'), 5, 'month rolls back correctly');
});

test('missing graphs keeps the heat calendar empty', () => {
  const now = new Date(2026, 6, 2, 12, 0, 0);
  assert.equal(构建主页快照(node({}),null, now).reviewCountsByDate.size, 0);
  assert.equal(
    构建主页快照(node({}),graphs({}), now).reviewCountsByDate.size, 0);
});

test('memory summary reports today again rate when today has answers', () => {
  const g = graphs({
    fsrs: true,
    retrievability: { average: 92.5, sumByCard: 0, sumByNote: 0 },
    today: {
      answerCount: 50, answerMillis: 0, correctCount: 10,
      matureCorrect: 15, matureCount: 20,
      learnCount: 0, reviewCount: 0, relearnCount: 0, earlyReviewCount: 0
    }
  });
  const snap = 构建主页快照(node({}), g);

  assert.equal(snap.memory.state, 'today_answered', 'today.answerCount>0 => today_answered');
  assert.ok(Math.abs(snap.memory.todayAgainRate - 0.8) < 1e-9,
    'todayAgainRate = (answer - correct) / answer = (50-10)/50 = 0.8');
  assert.equal(snap.memory.todayAnsweredCount, 50, '副标题"今日共答 50 次"');
  assert.equal(snap.memory.hasMatureData, true, 'matureCount>0 => hasMatureData');
  assert.ok(Math.abs(snap.memory.matureCorrectRate - 0.75) < 1e-9,
    'matureCorrectRate = matureCorrect / matureCount = 15/20');
  assert.equal(snap.memory.hasRetrievability, true, 'fsrs on + retrievability.average>0');
  assert.ok(Math.abs(snap.memory.averageRetrievability - 0.925) < 1e-9,
    '全库平均副标题：百分制 92.5 → 0-1 ratio 0.925');
});

test('memory summary shows today_empty when no reviews today', () => {
  const g = graphs({ fsrs: true, retrievability: { average: 92.5, sumByCard: 0, sumByNote: 0 } });
  const snap = 构建主页快照(node({}), g);
  assert.equal(snap.memory.state, 'today_empty', 'today.answerCount=0 => today_empty');
  assert.equal(snap.memory.todayAgainRate, 0);
  assert.equal(snap.memory.todayAnsweredCount, 0);
  assert.equal(snap.memory.hasMatureData, false);
  assert.equal(snap.memory.hasRetrievability, true);
  assert.ok(Math.abs(snap.memory.averageRetrievability - 0.925) < 1e-9);
});

test('memory summary hides retrievability subtitle when fsrs off', () => {
  const g = graphs({
    fsrs: false,
    retrievability: { average: 0, sumByCard: 0, sumByNote: 0 },
    today: {
      answerCount: 30, answerMillis: 0, correctCount: 25,
      matureCorrect: 0, matureCount: 0,
      learnCount: 0, reviewCount: 0, relearnCount: 0, earlyReviewCount: 0
    }
  });
  const snap = 构建主页快照(node({}), g);
  assert.equal(snap.memory.state, 'today_answered');
  assert.ok(Math.abs(snap.memory.todayAgainRate - (5 / 30)) < 1e-9);
  assert.equal(snap.memory.hasMatureData, false, 'matureCount=0 => hasMatureData=false');
  assert.equal(snap.memory.hasRetrievability, false, 'fsrs off => hasRetrievability=false');
});

test('memory summary reports load_error when graphs is null', () => {
  assert.equal(构建主页快照(node({}), null).memory.state, 'load_error',
    'graphs null (loadGraphsQuietly failed) => load_error');
});
