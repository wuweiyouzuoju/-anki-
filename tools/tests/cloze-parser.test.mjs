// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  文本中的填空编号,
  提取拼写填空内容,
  揭示填空内容
} from '../../entry/src/main/ets/model/填空解析器.ts';

test('cloze_numbers_in_string', () => {
  assert.deepEqual(文本中的填空编号('test'), []);
  assert.deepEqual(文本中的填空编号('{{c2::te}}{{c1::s}}t{{'), [1, 2]);
  assert.deepEqual(文本中的填空编号('{{c0::te}}s{{c2::t}}s'), [2]);
});

test('cloze_only', () => {
  assert.equal(揭示填空内容('foo', 1, true), '');
  assert.equal(揭示填空内容('foo {{c1::bar}}', 1, true), '...');
  assert.equal(揭示填空内容('foo {{c1::bar::baz}}', 1, true), 'baz');
  assert.equal(揭示填空内容('foo {{c1::bar}}', 1, false), 'bar');
  assert.equal(揭示填空内容('foo {{c1::bar}}', 2, false), '');
  assert.equal(揭示填空内容('{{c1::foo}} {{c1::bar}}', 1, false), 'foo, bar');
});

test('clozes_for_typing', () => {
  assert.equal(提取拼写填空内容('{{c2::foo}}', 1), '');
  assert.equal(
    提取拼写填空内容('{{c1::foo}} {{c1::bar}} {{c1::foo}}', 1),
    'foo, bar, foo'
  );
  assert.equal(
    提取拼写填空内容('{{c1::foo}} {{c1::foo}} {{c1::foo}}', 1),
    'foo'
  );
});

test('extract_cloze_for_typing_basic', () => {
  assert.equal(提取拼写填空内容('foo {{c1::bar}}', 1), 'bar');
  assert.equal(提取拼写填空内容('foo {{c1::bar}}', 2), '');
  assert.equal(提取拼写填空内容('foo {{c1::bar::baz}}', 1), 'bar');
});

test('nested_cloze_for_typing', () => {
  assert.equal(提取拼写填空内容('foo {{c1::bar {{c2::baz}}}}', 1), 'bar baz');
  assert.equal(提取拼写填空内容('foo {{c1::bar {{c2::baz}}}}', 2), 'baz');
});

test('multi_card_cloze_edge_cases', () => {
  assert.deepEqual(文本中的填空编号('{{c1,1,2::test}}'), [1, 2]);
  assert.deepEqual(文本中的填空编号('{{c0,1,2::test}}'), [1, 2]);
  assert.deepEqual(文本中的填空编号('{{c1,,3::test}}'), [1, 3]);
});

test('multi_card_cloze_only_filter', () => {
  const text = '{{c1,2::shared}} and {{c1::first}} vs {{c2::second}}';
  assert.equal(揭示填空内容(text, 1, true), '..., ...');
  assert.equal(揭示填空内容(text, 2, true), '..., ...');
  assert.equal(揭示填空内容(text, 1, false), 'shared, first');
  assert.equal(揭示填空内容(text, 2, false), 'shared, second');
});

test('multi_card_nested_cloze', () => {
  assert.deepEqual(文本中的填空编号('{{c1,2::outer {{c3::inner}}}}'), [1, 2, 3]);
});

test('nested_parent_child_card_same_cloze', () => {
  assert.deepEqual(文本中的填空编号('{{c1::outer {{c1::inner}}}}'), [1]);
});

test('multi_card_cloze_with_hints_for_typing', () => {
  assert.equal(提取拼写填空内容('{{c1,2::answer::hint}}', 1), 'answer');
  assert.equal(提取拼写填空内容('{{c1,2::answer::hint}}', 2), 'answer');
});

test('multi_ordinal_extract_for_typing', () => {
  assert.deepEqual(文本中的填空编号('{{c1,2::shared}}'), [1, 2]);
  assert.equal(提取拼写填空内容('{{c1,2::shared}}', 1), 'shared');
  assert.equal(提取拼写填空内容('{{c1,2::shared}}', 2), 'shared');
});

test('non_latin_text', () => {
  assert.deepEqual(文本中的填空编号('öaöaöööaö'), []);
});
