import test from 'node:test';
import assert from 'node:assert/strict';

import {
  解析可展示官方公告,
  构建官方公告请求地址,
  追加已确认官方公告ID,
} from '../../entry/src/main/ets/model/官方公告模型.ts';

const documentOf = (announcement) => JSON.stringify({ schemaVersion: 1, announcement });

const active = {
  id: '20260829-01',
  enabled: true,
  titleZh: '官方公告',
  contentZh: '中文正文',
  titleEn: 'Official announcement',
  contentEn: 'English body',
  publishedAt: '2026-08-29T18:00:00+08:00',
  startsAt: '2026-08-29T18:00:00+08:00',
  expiresAt: '2026-09-30T23:59:59+08:00',
  minimumAppVersion: '2.0.0',
  maximumAppVersion: '',
  actionUrl: 'https://example.com/announcement.html',
};

test('parses a targeted announcement and chooses the requested language', () => {
  const now = Date.parse('2026-08-30T00:00:00+08:00');
  const zh = 解析可展示官方公告(documentOf(active), '2.3.3', now, 'zh-Hans');
  const en = 解析可展示官方公告(documentOf(active), '2.3.3', now, 'en');
  assert.equal(zh?.title, '官方公告');
  assert.equal(en?.content, 'English body');
  assert.equal(en?.publishedAt, active.publishedAt);
  assert.equal(en?.actionUrl, active.actionUrl);
});

test('falls back field-by-field to Chinese when English copy is empty', () => {
  const raw = { ...active, titleEn: '', contentEn: '' };
  const item = 解析可展示官方公告(
    documentOf(raw), '2.3.3', Date.parse('2026-08-30T00:00:00+08:00'), 'en');
  assert.equal(item?.title, active.titleZh);
  assert.equal(item?.content, active.contentZh);
});

test('returns null for disabled, null, early, expired, and out-of-range notices', () => {
  const now = Date.parse('2026-08-30T00:00:00+08:00');
  assert.equal(解析可展示官方公告(documentOf(null), '2.3.3', now, 'zh-Hans'), null);
  assert.equal(解析可展示官方公告(documentOf({ ...active, enabled: false }), '2.3.3', now, 'zh-Hans'), null);
  assert.equal(解析可展示官方公告(documentOf(active), '2.3.3', Date.parse('2026-08-28T00:00:00+08:00'), 'zh-Hans'), null);
  assert.equal(解析可展示官方公告(documentOf(active), '2.3.3', Date.parse('2026-10-01T00:00:00+08:00'), 'zh-Hans'), null);
  assert.equal(解析可展示官方公告(documentOf({ ...active, minimumAppVersion: '3.0.0' }), '2.3.3', now, 'zh-Hans'), null);
  assert.equal(解析可展示官方公告(documentOf({ ...active, maximumAppVersion: '2.2.9' }), '2.3.3', now, 'zh-Hans'), null);
});

test('rejects malformed and unsafe protocol data', () => {
  const now = Date.parse('2026-08-30T00:00:00+08:00');
  assert.throws(() => 解析可展示官方公告('{', '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告(JSON.stringify({ schemaVersion: 2, announcement: active }), '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告(documentOf({ ...active, id: '../bad' }), '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告(documentOf({ ...active, actionUrl: 'http://example.com' }), '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告(documentOf({ ...active, expiresAt: active.startsAt }), '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告(documentOf({ ...active, titleZh: 'x'.repeat(81) }), '2.3.3', now, 'zh-Hans'));
  assert.throws(() => 解析可展示官方公告('你'.repeat(22000), '2.3.3', now, 'zh-Hans'), /64 KiB/);
});

test('builds a stable five-minute cache key', () => {
  const a = 构建官方公告请求地址('https://example.com/announcement.json', Date.parse('2026-08-29T18:03:01Z'));
  const b = 构建官方公告请求地址('https://example.com/announcement.json', Date.parse('2026-08-29T18:04:59Z'));
  const c = 构建官方公告请求地址('https://example.com/announcement.json?channel=stable', Date.parse('2026-08-29T18:05:00Z'));
  assert.equal(a, b);
  assert.match(a, /\?v=202608291800$/);
  assert.match(c, /&v=202608291805$/);
});

test('acknowledged ids are unique and bounded to the latest 32', () => {
  let ids = [];
  for (let index = 0; index < 35; index += 1) {
    ids = 追加已确认官方公告ID(ids, `notice-${index}`);
  }
  ids = 追加已确认官方公告ID(ids, 'notice-34');
  assert.equal(ids.length, 32);
  assert.equal(ids[0], 'notice-3');
  assert.equal(ids.at(-1), 'notice-34');
  assert.equal(ids.filter((id) => id === 'notice-34').length, 1);
});
