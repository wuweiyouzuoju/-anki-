import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('announcement acknowledgements use one bounded Preferences record', () => {
  const source = read('../../entry/src/main/ets/model/官方公告存储.ets');
  assert.match(source, /official_announcement_acknowledged_ids_v1/);
  assert.match(source, /读取已确认官方公告ID列表\(\): Promise<string\[\]>/);
  assert.match(source, /是否已确认官方公告\(id: string\): Promise<boolean>/);
  assert.match(source, /标记已确认官方公告\(id: string\): Promise<boolean>/);
  assert.match(source, /追加已确认官方公告ID/);
  assert.match(source, /await store\.flush\(\);\s*return true;/);
  assert.match(source, /catch \(error\) \{\s*return false;/);
});

test('announcement hosting has one public URL and no management credential', () => {
  const source = read('../../entry/src/main/ets/model/官方公告配置.ts');
  assert.match(source, /https:\/\/4001784660\.cdn\.123clouddisk\.com\/4001784660\/jidecards\/announcement\.json/);
  assert.doesNotMatch(source, /(clientSecret|clientID|accessToken|refreshToken|password|管理密钥)/i);
});

test('announcement service performs one uncached two-second GET and always destroys the client', () => {
  const source = read('../../entry/src/main/ets/backend/官方公告服务.ets');
  assert.match(source, /from '@kit\.NetworkKit'/);
  assert.match(source, /构建官方公告请求地址/);
  assert.match(source, /http\.RequestMethod\.GET/);
  assert.match(source, /http\.HttpDataType\.STRING/);
  assert.match(source, /usingCache: false/);
  assert.match(source, /connectTimeout: 2000/);
  assert.match(source, /readTimeout: 2000/);
  assert.match(source, /解析可展示官方公告/);
  assert.match(source, /finally \{\s*client\.destroy\(\);/);
  assert.doesNotMatch(source, /setTimeout|retry|ClientSecret|accessToken/i);
});
