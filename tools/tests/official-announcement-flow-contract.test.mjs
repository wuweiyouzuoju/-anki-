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
