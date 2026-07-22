// 埋藏/暂停 + 完成页契约测试（T3）：
// - SchedulerService 只经 BackendSession 走 BACKEND_SCHEDULER(13) 的 11/12/13/14 方法索引；
// - StudyPage 提供「埋藏/暂停」次级入口：BURY_USER（明天再见）/SUSPEND（手动恢复前不再出现），
//   与上游 reviewer.py bury_current_card/suspend_current_card 语义一致，成功后直接取下一张；
// - 完成页接 congratsInfo 真实数据（剩余学习卡/今日上限提示/恢复埋藏入口）；
// - CongratsInfo 只有布尔标记、不给卡片 id，恢复必须走 UnburyDeck(deckId, ALL)
//   （同桌面 overview.py on_unbury），不能走按 id 的 RestoreBuriedAndSuspendedCards；
// - congratsInfo 失败降级为静态完成文案，不进入错误态。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { SCHEDULER_METHOD, SERVICE } from '../../entry/src/main/ets/backend/ServiceIds.ts';
import {
  BURY_SUSPEND_MODE_BURY_USER,
  BURY_SUSPEND_MODE_SUSPEND,
  UNBURY_MODE_ALL
} from '../../entry/src/main/ets/proto/messages/SchedulerMessages.ts';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const SCHEDULER_SERVICE = 'entry/src/main/ets/backend/SchedulerService.ts';
const STUDY_PAGE = 'entry/src/main/ets/pages/StudyPage.ets';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('scheduler method indexes map to CongratsInfo/Restore/UnburyDeck/BuryOrSuspend 11/12/13/14', () => {
  assert.equal(SERVICE.BACKEND_SCHEDULER, 13, 'scheduler service id');
  assert.equal(SCHEDULER_METHOD.CONGRATS_INFO, 11);
  assert.equal(SCHEDULER_METHOD.RESTORE_BURIED_AND_SUSPENDED, 12);
  assert.equal(SCHEDULER_METHOD.UNBURY_DECK, 13);
  assert.equal(SCHEDULER_METHOD.BURY_OR_SUSPEND, 14);
});

test('bury/suspend mode constants match scheduler.proto (SUSPEND=0, BURY_USER=2, UNBURY ALL=0)', () => {
  // 上游 pylib/anki/scheduler/base.py：手动 bury_cards → BURY_USER；suspend_cards → SUSPEND
  assert.equal(BURY_SUSPEND_MODE_SUSPEND, 0);
  assert.equal(BURY_SUSPEND_MODE_BURY_USER, 2);
  assert.equal(UNBURY_MODE_ALL, 0);
});

test('scheduler service wraps bury/suspend, unbury, restore and congrats through BackendSession only', () => {
  const service = read(SCHEDULER_SERVICE);

  assert.match(service, /BackendSession\.getInstance\(\)/);
  assert.doesNotMatch(service, /new BackendClient/, 'must go through BackendSession');

  assert.match(service, /async buryOrSuspendCards\(cardId: number, mode: number\): Promise<void>/);
  assert.match(service, /encodeBuryOrSuspendCardsRequest\(\[cardId\], \[\], mode\)/,
    'single card id, no note ids');
  assert.match(service, /SERVICE\.BACKEND_SCHEDULER, SCHEDULER_METHOD\.BURY_OR_SUSPEND, request/);

  assert.match(service, /async unburyDeck\(deckId: number, mode: number\): Promise<void>/);
  assert.match(service, /encodeUnburyDeckRequest\(deckId, mode\)/);
  assert.match(service, /SERVICE\.BACKEND_SCHEDULER, SCHEDULER_METHOD\.UNBURY_DECK, request/);

  assert.match(service, /async restoreBuriedAndSuspendedCards\(cardIds: number\[\]\): Promise<void>/);
  assert.match(service, /encodeCardIds\(cardIds\)/);
  assert.match(service, /SERVICE\.BACKEND_SCHEDULER, SCHEDULER_METHOD\.RESTORE_BURIED_AND_SUSPENDED, request/);

  assert.match(service, /async congratsInfo\(\): Promise<CongratsInfo>/);
  assert.match(service, /SERVICE\.BACKEND_SCHEDULER, SCHEDULER_METHOD\.CONGRATS_INFO, new Uint8Array\(0\)/);
  assert.match(service, /decodeCongratsInfo\(response\)/);
});

test('study page bury/suspend entries use upstream reviewer semantics and refetch next card', () => {
  const page = read(STUDY_PAGE);

  // 次级操作行：问题/答案两态均可见
  assert.match(page, /if \(this\.phase === 'question' \|\| this\.phase === 'answer'\) \{[\s\S]*?app\.string\.study_bury[\s\S]*?app\.string\.study_suspend/,
    'bury/suspend row visible in both question and answer phases');
  assert.match(page, /this\.buryOrSuspendCurrent\(BURY_SUSPEND_MODE_BURY_USER\)/,
    'manual bury maps to BURY_USER (see you tomorrow)');
  assert.match(page, /this\.buryOrSuspendCurrent\(BURY_SUSPEND_MODE_SUSPEND\)/,
    'suspend maps to SUSPEND');

  const body = page.match(/buryOrSuspendCurrent\(mode: number\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /if \(this\.answering \|\| this\.currentCard === null\)/,
    'bury/suspend reuses reentrancy guard');
  assert.match(body[0], /await this\.schedulerService\.buryOrSuspendCards\(this\.currentCard\.cardId, mode\);\s*await this\.loadNextCard\(\);/,
    'card leaves today queue, next card fetched immediately');
  assert.match(body[0], /this\.phase = 'error';/,
    'bury/suspend failure surfaces through existing error state');
});

test('done page fetches congrats info when queue empties and degrades silently on failure', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /queued\.cards\.length === 0[\s\S]*?await this\.loadCongratsInfo\(\);/,
    'congrats info fetched on entering done phase');
  assert.match(page, /this\.congratsLoaded = false;[\s\S]*?getQueuedCards/,
    'stale congrats cleared before every refetch');

  const body = page.match(/loadCongratsInfo\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /await this\.schedulerService\.congratsInfo\(\)/);
  assert.match(body[0], /info\.secsUntilNextLearn < SECONDS_PER_DAY/,
    'learn-remaining hint suppressed when next learn card is >=1 day away (upstream buildNextLearnMsg)');
  assert.match(body[0], /this\.congratsBuried = info\.haveSchedBuried \|\| info\.haveUserBuried/);
  assert.match(body[0], /catch \(error\) \{\s*this\.congratsLoaded = false;/,
    'failure degrades to static finish copy');
  assert.doesNotMatch(body[0], /this\.phase = 'error'/,
    'congrats failure must not surface as error page');
});

test('done page renders real congrats data and deck-scoped unbury entry', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /\$r\('app\.string\.study_congrats_learn_remaining', this\.congratsLearnRemaining, this\.congratsNextLearnMinutes\)/);
  assert.match(page, /if \(this\.congratsReviewRemaining\) \{[\s\S]*?study_congrats_review_limit/);
  assert.match(page, /if \(this\.congratsNewRemaining\) \{[\s\S]*?study_congrats_new_limit/);
  assert.match(page, /if \(this\.congratsBuried\) \{[\s\S]*?Button\(\$r\('app\.string\.study_unbury'\)\)/);
  assert.match(page, /this\.restoreBuried\(\);/);

  const body = page.match(/restoreBuried\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /await this\.schedulerService\.unburyDeck\(this\.deckId, UNBURY_MODE_ALL\);\s*await this\.loadNextCard\(\);/,
    'CongratsInfo exposes no card ids, so restore is deck-scoped like desktop overview, then refetch');
  assert.match(body[0], /this\.phase = 'error';/);

  assert.doesNotMatch(page, /restoreBuriedAndSuspendedCards\(/,
    'id-based restore is not usable from the congrats page (no ids available)');
});

test('bury/suspend/congrats strings are resourced', () => {
  const strings = read(STRINGS);
  for (const key of ['study_bury', 'study_suspend', 'study_congrats_title',
    'study_congrats_learn_remaining', 'study_congrats_review_limit',
    'study_congrats_new_limit', 'study_unbury']) {
    assert.match(strings, new RegExp(`"name": "${key}"`), `missing string ${key}`);
  }
});
