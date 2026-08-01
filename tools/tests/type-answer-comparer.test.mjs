import assert from 'node:assert/strict';
import test from 'node:test';
import {
  比对答案,
  剥除答案标签,
  转义HTML
} from '../../entry/src/main/ets/model/拼写比对器.ts';

test('empty_input_shows_as_code', () => {
  assert.strictEqual(
    比对答案('<div>123</div>', '', true),
    '<code id=typeans>123</code>'
  );
});

test('correct_input_is_escaped', () => {
  assert.strictEqual(
    比对答案('3 < 5', '3 < 5', true),
    '<code id=typeans><span class=typeGood>3 &lt; 5</span></code>'
  );
  assert.strictEqual(
    比对答案('a & b', 'a & b', true),
    '<code id=typeans><span class=typeGood>a &amp; b</span></code>'
  );
  assert.strictEqual(
    转义HTML('<a href="x">&\'test\'</a>'),
    '&lt;a href=&quot;x&quot;&gt;&amp;&#39;test&#39;&lt;/a&gt;'
  );
});

test('correct_input_is_collapsed', () => {
  assert.strictEqual(
    比对答案('123', '123', true),
    '<code id=typeans><span class=typeGood>123</span></code>'
  );
});

test('incorrect_input_is_not_collapsed', () => {
  assert.strictEqual(
    比对答案('123', '1123', true),
    '<code id=typeans><span class=typeBad>1</span><span class=typeGood>123</span><br><span id=typearrow>&darr;</span><br><span class=typeGood>123</span></code>'
  );
});

test('tokens', () => {
  assert.strictEqual(
    比对答案('¿Y ahora qué vamos a hacer?', 'y ahora qe vamosa hacer', true),
    '<code id=typeans>'
    + '<span class=typeBad>y</span>'
    + '<span class=typeGood> ahora q</span>'
    + '<span class=typeBad>e</span>'
    + '<span class=typeGood> vamos</span>'
    + '<span class=typeMissed>-</span>'
    + '<span class=typeGood>a hacer</span>'
    + '<span class=typeMissed>-</span>'
    + '<br><span id=typearrow>&darr;</span><br>'
    + '<span class=typeMissed>¿Y</span>'
    + '<span class=typeGood> ahora q</span>'
    + '<span class=typeMissed>ué</span>'
    + '<span class=typeGood> vamos</span>'
    + '<span class=typeMissed> </span>'
    + '<span class=typeGood>a hacer</span>'
    + '<span class=typeMissed>?</span>'
    + '</code>'
  );
});

test('missed_chars_only_shown_in_typed_when_after_good', () => {
  assert.strictEqual(
    比对答案('1', '23', true),
    '<code id=typeans><span class=typeBad>23</span><br><span id=typearrow>&darr;</span><br><span class=typeMissed>1</span></code>'
  );
  assert.strictEqual(
    比对答案('12', '1', true),
    '<code id=typeans><span class=typeGood>1</span><span class=typeMissed>-</span><br><span id=typearrow>&darr;</span><br><span class=typeGood>1</span><span class=typeMissed>2</span></code>'
  );
});

test('missed_chars_counted_correctly', () => {
  assert.strictEqual(
    比对答案('нос', 'нс', true),
    '<code id=typeans>'
    + '<span class=typeGood>н</span>'
    + '<span class=typeMissed>-</span>'
    + '<span class=typeGood>с</span>'
    + '<br><span id=typearrow>&darr;</span><br>'
    + '<span class=typeGood>н</span>'
    + '<span class=typeMissed>о</span>'
    + '<span class=typeGood>с</span>'
    + '</code>'
  );
});

test('handles_certain_unicode_as_expected', () => {
  assert.strictEqual(
    比对答案('쓰다듬다', '스다뜸다', true),
    '<code id=typeans>'
    + '<span class=typeBad>스</span>'
    + '<span class=typeGood>다</span>'
    + '<span class=typeBad>뜸</span>'
    + '<span class=typeGood>다</span>'
    + '<br><span id=typearrow>&darr;</span><br>'
    + '<span class=typeMissed>쓰</span>'
    + '<span class=typeGood>다</span>'
    + '<span class=typeMissed>듬</span>'
    + '<span class=typeGood>다</span>'
    + '</code>'
  );
});

test('does_not_panic_with_certain_unicode', () => {
  const html = 比对答案(
    'Сущность должна быть ответственна только за одно дело',
    'Single responsibility Сущность выполняет только одну задачу.Повод для изменения сущности только один.',
    true
  );
  assert.ok(html.startsWith('<code id=typeans>'));
  assert.ok(html.endsWith('</code>'));
});

test('tags_removed', () => {
  assert.strictEqual(剥除答案标签('<div>123</div>'), '123');
  assert.strictEqual(
    比对答案('<div>123</div>', '123', true),
    '<code id=typeans><span class=typeGood>123</span></code>'
  );
});

test('html_and_media', () => {
  const stripped = 剥除答案标签('[sound:foo.mp3]<b>1</b> &nbsp;2');
  assert.strictEqual(stripped, '1  2');
  assert.strictEqual(
    比对答案('[sound:foo.mp3]<b>1</b> &nbsp;2', '1  2', true),
    '<code id=typeans><span class=typeGood>1  2</span></code>'
  );
});

test('noncombining_comparison', () => {
  assert.strictEqual(
    比对答案('שִׁנּוּן', 'שנון', false),
    '<code id=typeans><span class=typeGood>שִׁנּוּן</span></code>'
  );
  assert.strictEqual(
    比对答案('חוֹף', 'חופ', false),
    '<code id=typeans>'
    + '<span class=typeGood>חו</span>'
    + '<span class=typeBad>פ</span>'
    + '<br><span id=typearrow>&darr;</span><br>'
    + '<span class=typeGood>חוֹ</span>'
    + '<span class=typeMissed>ף</span>'
    + '</code>'
  );
  assert.strictEqual(
    比对答案('ば', 'は', false),
    '<code id=typeans><span class=typeGood>ば</span></code>'
  );
});
