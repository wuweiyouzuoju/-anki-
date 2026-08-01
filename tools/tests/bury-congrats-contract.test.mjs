import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { 调度器方法, 服务号 } from '../../entry/src/main/ets/backend/服务索引.ts';
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

const SCHEDULER_SERVICE = 'entry/src/main/ets/backend/调度器服务.ts';
const STUDY_PAGE = 'entry/src/main/ets/pages/学习页.ets';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('scheduler method indexes map to CongratsInfo/Restore/UnburyDeck/BuryOrSuspend 11/12/13/14', () => {
  assert.equal(服务号.后端调度器, 13, 'scheduler service id');
  assert.equal(调度器方法.完成页信息, 11);
  assert.equal(调度器方法.恢复埋藏与暂停, 12);
  assert.equal(调度器方法.按牌组恢复埋藏, 13);
  assert.equal(调度器方法.埋藏或暂停, 14);
});

test('bury/suspend mode constants match scheduler.proto (SUSPEND=0, BURY_USER=2, UNBURY ALL=0)', () => {
  assert.equal(BURY_SUSPEND_MODE_SUSPEND, 0);
  assert.equal(BURY_SUSPEND_MODE_BURY_USER, 2);
  assert.equal(UNBURY_MODE_ALL, 0);
});

test('scheduler service wraps bury/suspend, unbury, restore and congrats through 后端会话 only', () => {
  const service = read(SCHEDULER_SERVICE);

  assert.match(service, /后端会话\.获取实例\(\)/);
  assert.doesNotMatch(service, /new 后端客户端/, 'must go through 后端会话');

  assert.match(service, /async 埋藏或暂停卡片\(卡片ID: number, 模式: number\): Promise<void>/);
  assert.match(service, /encodeBuryOrSuspendCardsRequest\(\[卡片ID\], \[\], 模式\)/,
    'single card id, no note ids');
  assert.match(service, /服务号\.后端调度器, 调度器方法\.埋藏或暂停, 请求字节/);

  assert.match(service, /async 按牌组恢复埋藏\(牌组ID: number, 模式: number\): Promise<void>/);
  assert.match(service, /encodeUnburyDeckRequest\(牌组ID, 模式\)/);
  assert.match(service, /服务号\.后端调度器, 调度器方法\.按牌组恢复埋藏, 请求字节/);

  assert.match(service, /async 恢复埋藏与暂停的卡片\(卡片ID列表: number\[\]\): Promise<void>/);
  assert.match(service, /encodeCardIds\(卡片ID列表\)/);
  assert.match(service, /服务号\.后端调度器, 调度器方法\.恢复埋藏与暂停, 请求字节/);

  assert.match(service, /async 获取完成页信息\(\): Promise<CongratsInfo>/);
  assert.match(service, /服务号\.后端调度器, 调度器方法\.完成页信息, new Uint8Array\(0\)/);
  assert.match(service, /decodeCongratsInfo\(响应字节\)/);
});

test('study page bury/suspend entries use upstream reviewer semantics and refetch next card', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /if \(this\.阶段 === 'question' \|\| this\.阶段 === 'answer'\) \{[\s\S]*?app\.string\.study_bury[\s\S]*?app\.string\.study_suspend/,
    'bury/suspend row visible in both question and answer phases');
  assert.match(page, /this\.埋藏或暂停当前卡\(BURY_SUSPEND_MODE_BURY_USER\)/,
    'manual bury maps to BURY_USER (see you tomorrow)');
  assert.match(page, /this\.埋藏或暂停当前卡\(BURY_SUSPEND_MODE_SUSPEND\)/,
    'suspend maps to SUSPEND');

  const body = page.match(/埋藏或暂停当前卡\(mode: number\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /if \(this\.评分中 \|\| this\.当前卡片 === null\)/,
    'bury/suspend reuses reentrancy guard');
  assert.match(body[0], /await this\.调度器服务实例\.埋藏或暂停卡片\(this\.当前卡片\.cardId, mode\);\s*await this\.加载下一张卡\(\);/,
    'card leaves today queue, next card fetched immediately');
  assert.match(body[0], /this\.阶段 = 'error';/,
    'bury/suspend failure surfaces through existing error state');
});

test('done page fetches congrats info when queue empties and degrades silently on failure', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /queued\.cards\.length === 0[\s\S]*?await this\.加载完成页信息\(\);/,
    'congrats info fetched on entering done phase');
  assert.match(page, /this\.完成页数据已加载 = false;[\s\S]*?获取队首卡片/,
    'stale congrats cleared before every refetch');

  const body = page.match(/加载完成页信息\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /await this\.调度器服务实例\.获取完成页信息\(\)/);
  assert.match(body[0], /info\.secsUntilNextLearn < SECONDS_PER_DAY/,
    'learn-remaining hint suppressed when next learn card is >=1 day away (upstream buildNextLearnMsg)');
  assert.match(body[0], /this\.完成页有埋藏 = info\.haveSchedBuried \|\| info\.haveUserBuried/);
  assert.match(body[0], /catch \(error\) \{\s*this\.完成页数据已加载 = false;/,
    'failure degrades to static finish copy');
  assert.doesNotMatch(body[0], /this\.阶段 = 'error'/,
    'congrats failure must not surface as error page');
});

test('done page renders real congrats data and deck-scoped unbury entry', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /\$r\('app\.string\.study_congrats_learn_remaining', this\.完成页学习剩余, this\.完成页下张学习分钟\)/);
  assert.match(page, /if \(this\.完成页复习受限\) \{[\s\S]*?study_congrats_review_limit/);
  assert.match(page, /if \(this\.完成页新卡受限\) \{[\s\S]*?study_congrats_new_limit/);
  assert.match(page, /if \(this\.完成页有埋藏\) \{[\s\S]*?Button\(\$r\('app\.string\.study_unbury'\)\)/);
  assert.match(page, /this\.恢复埋藏\(\);/);

  const body = page.match(/恢复埋藏\(\): Promise<void> \{[\s\S]*?\n  \}/);
  assert.notEqual(body, null);
  assert.match(body[0], /await this\.调度器服务实例\.按牌组恢复埋藏\(this\.牌组ID, UNBURY_MODE_ALL\);\s*await this\.加载下一张卡\(\);/,
    'CongratsInfo exposes no card ids, so restore is deck-scoped like desktop overview, then refetch');
  assert.match(body[0], /this\.阶段 = 'error';/);

  assert.doesNotMatch(page, /恢复埋藏与暂停的卡片\(/,
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
