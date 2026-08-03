// SPDX-License-Identifier: AGPL-3.0-or-later

// 拼写比对器 单元测试：移植自 Anki rslib/src/typeanswer.rs 的 #[cfg(test)] 模块。
// 覆盖 比对答案 / 剥除答案标签 / 转义HTML 的核心行为：
// - 空输入、完全匹配、部分匹配、HTML 转义、strip_expected 预处理
// - SequenceMatcher 字符级 diff token 边界
// - DiffNonCombining（combining=false）的 NFKD 分解 + 组合标记过滤
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
  // HTML 特殊字符 < & 在输出中转义为 &lt; &amp;
  // 注：input 中的 < 不后接 >，因此 剥除答案标签 不会当作 HTML 标签剥除
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
  // typed="1123" vs expected="123"：delete "1" + equal "123"
  assert.strictEqual(
    比对答案('123', '1123', true),
    '<code id=typeans><span class=typeBad>1</span><span class=typeGood>123</span><br><span id=typearrow>&darr;</span><br><span class=typeGood>123</span></code>'
  );
});

test('tokens', () => {
  // 移植自 Rust tokens() 测试：验证 SequenceMatcher 对西班牙语带重音的 diff 边界
  // typed="y ahora qe vamosa hacer" vs expected="¿Y ahora qué vamos a hacer?"
  // opcodes: replace("y"/"¿Y"), equal(" ahora q"), replace("e"/"ué"),
  //          equal(" vamos"), insert(" "), equal("a hacer"), insert("?")
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
  // typed 比 expected 长：多出的字符显示为 typeBad
  // typed="23" vs expected="1" → replace
  assert.strictEqual(
    比对答案('1', '23', true),
    '<code id=typeans><span class=typeBad>23</span><br><span id=typearrow>&darr;</span><br><span class=typeMissed>1</span></code>'
  );
  // typed 比 expected 短：缺失字符在 typed 行显示为 "-"，在 expected 行显示原字符
  // typed="1" vs expected="12" → equal("1") + insert("2")
  assert.strictEqual(
    比对答案('12', '1', true),
    '<code id=typeans><span class=typeGood>1</span><span class=typeMissed>-</span><br><span id=typearrow>&darr;</span><br><span class=typeGood>1</span><span class=typeMissed>2</span></code>'
  );
});

test('missed_chars_counted_correctly', () => {
  // 俄语：typed="нс" vs expected="нос" → equal("н") + insert("о") + equal("с")
  // insert 段在 typed 行显示 "-"（数量 = expected_slice 字符数 = 1）
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
  // 韩语：每个字符是一个 code point，SequenceMatcher 逐字 diff
  // typed="스다뜸다" vs expected="쓰다듬다"
  // opcodes: replace("스"/"쓰"), equal("다"), replace("뜸"/"듬"), equal("다")
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
  // 移植自 Rust does_not_panic_with_certain_unicode：仅验证不抛异常
  const html = 比对答案(
    'Сущность должна быть ответственна только за одно дело',
    'Single responsibility Сущность выполняет только одну задачу.Повод для изменения сущности только один.',
    true
  );
  assert.ok(html.startsWith('<code id=typeans>'));
  assert.ok(html.endsWith('</code>'));
});

test('tags_removed', () => {
  // 剥除答案标签 剥除 <div></div> 标签后只剩 "123"
  assert.strictEqual(剥除答案标签('<div>123</div>'), '123');
  // 完全匹配 → typeGood span
  assert.strictEqual(
    比对答案('<div>123</div>', '123', true),
    '<code id=typeans><span class=typeGood>123</span></code>'
  );
});

test('html_and_media', () => {
  // 剥除答案标签 完整链路：strip [sound:] → strip <b></b> → decode &nbsp; → "1  2"
  const stripped = 剥除答案标签('[sound:foo.mp3]<b>1</b> &nbsp;2');
  assert.strictEqual(stripped, '1  2');
  // typed == expected(已 strip) → collapsed typeGood
  assert.strictEqual(
    比对答案('[sound:foo.mp3]<b>1</b> &nbsp;2', '1  2', true),
    '<code id=typeans><span class=typeGood>1  2</span></code>'
  );
});

test('noncombining_comparison', () => {
  // combining=false：NFKD 分解后过滤组合标记再 diff
  // 希伯来语带 niqqud：typed="שנון" vs expected="שִׁנּוּן"
  // NFKD 分解后两者基础字母相同 → collapsed，但 expectedOriginal 保留原始带标记形式
  assert.strictEqual(
    比对答案('שִׁנּוּן', 'שנון', false),
    '<code id=typeans><span class=typeGood>שִׁנּוּן</span></code>'
  );
  // typed="חופ" vs expected="חוֹף"：基础字母差一个（פ vs ף）
  // equal("חו") + replace("פ"/"ף")
  // expected 行用 expected_split 渲染，组合标记重新附着到基础字母：חוֹ
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
  // 日语浊音：expected="ば"(U+3070) NFKD 分解为 は(U+306F) + U+3099(浊点标记)
  // typed="は"(U+306F) → 过滤后与 expected 基础字母相同 → collapsed
  // expectedOriginal 保留原始 "ば"
  assert.strictEqual(
    比对答案('ば', 'は', false),
    '<code id=typeans><span class=typeGood>ば</span></code>'
  );
});
