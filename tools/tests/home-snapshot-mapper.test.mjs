// HomeSnapshotMapper 单测：牌组树 → 主页快照的映射规则。
// 映射语义来源：third_party/anki/rslib/src/decks/tree.rs（根节点占位、
// 节点计数含子节点合计），本文件锁定这些约定，防回归。
import assert from 'node:assert/strict';
import test from 'node:test';
import {
  composeDeckPath,
  flattenDeckTree,
  normalizeDeckPath,
  visibleDeckRows
} from '../../entry/src/main/ets/model/DeckHierarchy.ets';
import { buildHomeSnapshot } from '../../entry/src/main/ets/model/HomeSnapshotMapper.ets';
import { DeckTone } from '../../entry/src/main/ets/model/HomeModels.ets';

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
  assert.equal(normalizeDeckPath(' 英语：词汇 '), '英语::词汇');
  assert.equal(normalizeDeckPath('英语:词汇'), '英语::词汇');
  assert.equal(normalizeDeckPath('英语：:词汇'), '英语::词汇');
  assert.equal(normalizeDeckPath('英语::词汇'), '英语::词汇');
  assert.equal(normalizeDeckPath(''), null);
  assert.equal(normalizeDeckPath('英语::'), null);
  assert.equal(normalizeDeckPath('::词汇'), null);
  assert.equal(composeDeckPath('英语：词汇', '语法'), '英语::词汇::语法');
  assert.equal(composeDeckPath('', '英语:词汇'), '英语::词汇');
});

test('hierarchy flattens preorder rows and reveals descendants only after every ancestor expands', () => {
  const grandchild = node({ deckId: 12, name: '语法', totalIncludingChildren: 4 });
  const child = node({ deckId: 11, name: '词汇', totalIncludingChildren: 6, children: [grandchild] });
  const parent = node({ deckId: 10, name: '英语', totalIncludingChildren: 20, children: [child] });
  const rows = flattenDeckTree(node({ children: [parent] }));

  assert.deepEqual(rows.map((row) => [row.name, row.fullName, row.depth, row.parentId]), [
    ['英语', '英语', 0, ''],
    ['词汇', '英语::词汇', 1, '10'],
    ['语法', '英语::词汇::语法', 2, '11']
  ]);
  assert.deepEqual(rows[2].ancestorIds, ['10', '11']);
  assert.equal(rows[0].totalCards, 20, 'aggregate totals remain supplied by the backend');
  assert.deepEqual(visibleDeckRows(rows, new Set()), [rows[0]]);
  assert.deepEqual(visibleDeckRows(rows, new Set(['10'])), [rows[0], rows[1]]);
  assert.deepEqual(visibleDeckRows(rows, new Set(['10', '11'])), rows);
});

test('empty root yields an empty formal snapshot', () => {
  const snap = buildHomeSnapshot(node({}));
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
  const snap = buildHomeSnapshot(node({ children: [parent] }));

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
  // Anki today.rs 中 today.answer_count = learn_count + review_count + relearn_count
  // + early_review_count，全库聚合、含全部子牌组学习；旧实现只对顶层牌组求
  // countsForDeckToday.new+review，既漏子牌组、又缺 learn/relearn 口径。
  const withToday = graphs({
    today: {
      answerCount: 42, answerMillis: 0, correctCount: 0, matureCorrect: 0,
      matureCount: 0, learnCount: 10, reviewCount: 20, relearnCount: 5, earlyReviewCount: 7
    }
  });
  const snap = buildHomeSnapshot(node({}), withToday);
  assert.equal(snap.today.completedCount, 42, 'completedCount mirrors graphs.today.answerCount');

  // graphs 缺 today 字段时降级为 0
  assert.equal(buildHomeSnapshot(node({}), graphs({})).today.completedCount, 0);
  assert.equal(buildHomeSnapshot(node({}), null).today.completedCount, 0);
});

test('fallback tone is stable per deckId (independent of position)', () => {
  // 旧实现用 rows.length % 4 让连续创建的 deck 轮转 4 色，但拖动排序后位置变 fallback tone 跟着变，
  // 与用户期望「色条跟着牌组走」矛盾。改为 Math.abs(deckId) % 4 后每张牌组色条固定。
  const root = node({
    children: [1, 2, 3, 4, 5].map((i) => node({ deckId: i, name: `d${i}` }))
  });
  const snap = buildHomeSnapshot(root);
  // TONE_ROTATION = [Blue, Purple, Mint, Amber]
  // id=1 → 1%4=1 → Purple；id=2 → 2 → Mint；id=3 → 3 → Amber；id=4 → 0 → Blue；id=5 → 1 → Purple
  assert.deepEqual(snap.decks.map((d) => d.tone), [
    DeckTone.Purple, DeckTone.Mint, DeckTone.Amber, DeckTone.Blue, DeckTone.Purple
  ]);
});

test('fallback tone unchanged after reordering via orderOverrides', () => {
  // 拖动后位置变，但每张牌组 fallback tone 应保持稳定（核心修复点）
  const root = node({
    children: [1, 2, 3, 4, 5].map((i) => node({ deckId: i, name: `d${i}` }))
  });
  // 把顺序倒过来：5 4 3 2 1
  const orderOverrides = new Map([['', ['5', '4', '3', '2', '1']]]);
  const snap = buildHomeSnapshot(root, null, new Date(), null, null, orderOverrides);
  // 顺序变但 tone 应保持与 deckId 绑定（id=5→Purple, id=4→Blue, id=3→Amber, id=2→Mint, id=1→Purple）
  assert.deepEqual(snap.decks.map((d) => d.tone), [
    DeckTone.Purple, DeckTone.Blue, DeckTone.Amber, DeckTone.Mint, DeckTone.Purple
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
  // Anki reviews.rs 中 day key = (elapsed_secs_since(next_day_start) / 86_400) as i32，
  // 语义是「相对今天的偏移」：0=今天、-1=昨天、-2=前天。
  const data = graphs({
    reviewCountsByDaysAgo: new Map([
      [0, { learn: 2, relearn: 1, young: 3, mature: 4, filtered: 1 }],
      [-2, { learn: 0, relearn: 0, young: 5, mature: 0, filtered: 0 }],
      [-4, { learn: 0, relearn: 0, young: 0, mature: 0, filtered: 0 }]
    ])
  });
  // 锚定 2026-07-02（本地时区），验证跨月回卷：2 天前 = 2026-06-30
  const now = new Date(2026, 6, 2, 12, 0, 0);
  const snap = buildHomeSnapshot(node({}),data, now);

  assert.equal(snap.reviewCountsByDate.size, 2, 'zero-total days are omitted');
  assert.equal(snap.reviewCountsByDate.get('2026-07-02'), 11, 'kinds are summed');
  assert.equal(snap.reviewCountsByDate.get('2026-06-30'), 5, 'month rolls back correctly');
});

test('missing graphs keeps the heat calendar empty', () => {
  const now = new Date(2026, 6, 2, 12, 0, 0);
  assert.equal(buildHomeSnapshot(node({}),null, now).reviewCountsByDate.size, 0);
  assert.equal(
    buildHomeSnapshot(node({}),graphs({}), now).reviewCountsByDate.size, 0);
});

// B12-X 改造 2026-07-21：记忆卡主指标改用「今日不会率」(answer-correct)/answer，
// 全库平均可提取率降为副标题参考。语义改用 Anki Desktop today.ts 同款算法。
test('memory summary reports today again rate when today has answers', () => {
  // 今日答 50 张，其中正确 10 张（40 张"不会"）→ todayAgainRate = 0.8
  // 今日 mature 卡 20 张，其中 mature 正确 15 张 → matureCorrectRate = 0.75
  // FSRS 已开 + retrievability.average=92.5（百分制）→ averageRetrievability = 0.925
  const g = graphs({
    fsrs: true,
    retrievability: { average: 92.5, sumByCard: 0, sumByNote: 0 },
    today: {
      answerCount: 50, answerMillis: 0, correctCount: 10,
      matureCorrect: 15, matureCount: 20,
      learnCount: 0, reviewCount: 0, relearnCount: 0, earlyReviewCount: 0
    }
  });
  const snap = buildHomeSnapshot(node({}), g);

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
  const snap = buildHomeSnapshot(node({}), g);
  assert.equal(snap.memory.state, 'today_empty', 'today.answerCount=0 => today_empty');
  assert.equal(snap.memory.todayAgainRate, 0);
  assert.equal(snap.memory.todayAnsweredCount, 0);
  assert.equal(snap.memory.hasMatureData, false);
  // 全库平均仍可显示（副标题用，让用户对比）—但仅在 FSRS+memory_state 时
  assert.equal(snap.memory.hasRetrievability, true);
  assert.ok(Math.abs(snap.memory.averageRetrievability - 0.925) < 1e-9);
});

test('memory summary hides retrievability subtitle when fsrs off', () => {
  // FSRS 未开 → 不显示全库副标题，但今日不会率仍正常计算
  const g = graphs({
    fsrs: false,
    retrievability: { average: 0, sumByCard: 0, sumByNote: 0 },
    today: {
      answerCount: 30, answerMillis: 0, correctCount: 25,
      matureCorrect: 0, matureCount: 0,
      learnCount: 0, reviewCount: 0, relearnCount: 0, earlyReviewCount: 0
    }
  });
  const snap = buildHomeSnapshot(node({}), g);
  assert.equal(snap.memory.state, 'today_answered');
  assert.ok(Math.abs(snap.memory.todayAgainRate - (5 / 30)) < 1e-9);
  assert.equal(snap.memory.hasMatureData, false, 'matureCount=0 => hasMatureData=false');
  assert.equal(snap.memory.hasRetrievability, false, 'fsrs off => hasRetrievability=false');
});

test('memory summary reports load_error when graphs is null', () => {
  assert.equal(buildHomeSnapshot(node({}), null).memory.state, 'load_error',
    'graphs null (loadGraphsQuietly failed) => load_error');
});
