// SPDX-License-Identifier: AGPL-3.0-or-later

// T13 浏览卡片功能契约测试：
// - SearchMessages.ts 的 proto 编解码往返（SearchNode / SearchRequest / SortOrder /
//   FindAndReplaceRequest / BrowserColumns / BrowserRow），含 proto3 默认值跳过编码验证。
// - 搜索服务.ts 的 9 个方法签名契约（类存在 + 方法名 + 参数数量）。
// - i18n key 完整性（browser_* key 在中英文 string.json 都存在且对齐）。
//
// 不调用真实后端 NAPI 桥：libjidecards.so 经 resolve hook 桩成空实现，
// 搜索服务仅验证类结构与方法签名，不执行任何 RPC。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { register } from 'node:module';
import test from 'node:test';

import { 协议写入器 } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import { 协议读取器 } from '../../entry/src/main/ets/proto/core/ProtoReader.ts';
import {
  BrowserCellTextElideMode,
  BrowserColumnAlignment,
  BrowserColumnSorting,
  BrowserRowColor,
  SearchNodeCardState,
  SearchNodeFieldSearchMode,
  SearchNodeFlag,
  SearchNodeJoiner,
  SearchNodeRating,
  decodeBrowserColumns,
  decodeBrowserRow,
  decodeSearchNode,
  decodeSearchResponse,
  encodeFindAndReplaceRequest,
  encodeSearchNode,
  encodeSearchRequest,
  makeCardStateNode,
  makeDeckNode,
  makeParsableTextNode,
  makeTagNode
} from '../../entry/src/main/ets/proto/messages/SearchMessages.ts';
import {
  ReviewKind,
  decodeCardStatsResponse,
  encodeCardIdRequest
} from '../../entry/src/main/ets/proto/messages/StatsMessages.ts';

// ---- libjidecards.so 桩（让 后端会话 / 搜索服务 可在 Node 下加载） ----
// 后端客户端.ts import libjidecards.so（HarmonyOS 原生 NAPI），Node 测试环境无此包。
// 注册一个 resolve hook 把它桩成空实现，让 搜索服务.ts 可在 Node 下加载。
const libStub = 'export const openBackend = () => 0; export const closeBackend = () => {}; export const runMethodRaw = () => Promise.resolve(new Uint8Array(0));';
const libStubUrl = 'data:text/javascript;base64,' + Buffer.from(libStub).toString('base64');
const hookCode = `export function resolve(s, c, n) { if (s === 'libjidecards.so') { return { url: ${JSON.stringify(libStubUrl)}, shortCircuit: true }; } return n(s, c); }`;
register('data:text/javascript;base64,' + Buffer.from(hookCode).toString('base64'), import.meta.url);

// ---- 辅助函数 ----

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

/** SearchNode 编解码往返：encode → bytes → decode */
function roundTripSearchNode(node) {
  return decodeSearchNode(encodeSearchNode(node).转为字节());
}

// ---- 测试局部解码器（验证 encode 侧 wire format 契约） ----
// encodeSortOrder / decodeSortOrder 未导出，经 encodeSearchRequest 编码后
// 用 协议读取器 独立解析，验证编码 wire format 与 prost 对齐。

function decodeSortOrderForTest(bytes) {
  const r = new 协议读取器(bytes);
  const order = { kind: 'none' };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        r.读取字节(); // generic.Empty 子消息
        order.kind = 'none';
        break;
      case 2:
        order.kind = 'custom';
        order.custom = r.读取字符串();
        break;
      case 3: {
        order.kind = 'builtin';
        const inner = new 协议读取器(r.读取字节());
        let innerTag;
        while ((innerTag = inner.读取标签()) !== null) {
          switch (innerTag.字段号) {
            case 1: order.column = inner.读取字符串(); break;
            case 2: order.reverse = inner.读取布尔(); break;
            default: inner.跳过字段(innerTag.线类型);
          }
        }
        break;
      }
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return order;
}

function decodeSearchRequestForTest(bytes) {
  const r = new 协议读取器(bytes);
  const req = { search: '', order: { kind: 'none' } };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1: req.search = r.读取字符串(); break;
      case 2: req.order = decodeSortOrderForTest(r.读取字节()); break;
      default: r.跳过字段(tag.线类型);
    }
  }
  return req;
}

function decodeFindAndReplaceRequestForTest(bytes) {
  const r = new 协议读取器(bytes);
  const req = { nids: [], search: '', replacement: '', regex: false, matchCase: false, fieldName: '' };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        if (tag.线类型 === 2) {
          req.nids.push(...r.读取打包64位整数());
        } else {
          req.nids.push(r.读取64位整数());
        }
        break;
      case 2: req.search = r.读取字符串(); break;
      case 3: req.replacement = r.读取字符串(); break;
      case 4: req.regex = r.读取布尔(); break;
      case 5: req.matchCase = r.读取布尔(); break;
      case 6: req.fieldName = r.读取字符串(); break;
      default: r.跳过字段(tag.线类型);
    }
  }
  return req;
}

// ============================================================
// A. proto 编解码往返
// ============================================================

test('makeParsableTextNode round-trips through proto encode/decode', () => {
  const node = makeParsableTextNode('deck:Swahili');
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'parsable_text');
  assert.equal(rt.text, 'deck:Swahili');
});

test('makeDeckNode round-trips through proto encode/decode', () => {
  const node = makeDeckNode('Default');
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'deck');
  assert.equal(rt.deck, 'Default');
});

test('makeTagNode round-trips through proto encode/decode', () => {
  const node = makeTagNode('important');
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'tag');
  assert.equal(rt.tag, 'important');
});

test('makeCardStateNode round-trips with CARD_STATE_DUE', () => {
  const node = makeCardStateNode(SearchNodeCardState.CARD_STATE_DUE);
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'card_state');
  assert.equal(rt.cardState, SearchNodeCardState.CARD_STATE_DUE);
});

test('SearchNode field (fieldName + text + mode) round-trips', () => {
  const node = {
    kind: 'field',
    field: {
      fieldName: 'Front',
      text: 'hello',
      mode: SearchNodeFieldSearchMode.FIELD_SEARCH_MODE_REGEX
    }
  };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'field');
  assert.equal(rt.field.fieldName, 'Front');
  assert.equal(rt.field.text, 'hello');
  assert.equal(rt.field.mode, SearchNodeFieldSearchMode.FIELD_SEARCH_MODE_REGEX);
});

test('SearchNode group (nodes + joiner=OR) round-trips', () => {
  const node = {
    kind: 'group',
    group: {
      nodes: [makeParsableTextNode('deck:Swahili'), makeTagNode('important')],
      joiner: SearchNodeJoiner.OR
    }
  };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'group');
  assert.equal(rt.group.joiner, SearchNodeJoiner.OR);
  assert.equal(rt.group.nodes.length, 2);
  assert.equal(rt.group.nodes[0].kind, 'parsable_text');
  assert.equal(rt.group.nodes[0].text, 'deck:Swahili');
  assert.equal(rt.group.nodes[1].kind, 'tag');
  assert.equal(rt.group.nodes[1].tag, 'important');
});

test('SearchNode negated round-trips', () => {
  const node = { kind: 'negated', negated: makeParsableTextNode('is:new') };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'negated');
  assert.equal(rt.negated.kind, 'parsable_text');
  assert.equal(rt.negated.text, 'is:new');
});

test('SearchNode nids=[1,2,3] round-trips', () => {
  const node = { kind: 'nids', nids: [1, 2, 3] };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'nids');
  assert.deepEqual(rt.nids, [1, 2, 3]);
});

test('SearchNode rated (days=7 + rating=HARD) round-trips', () => {
  const node = {
    kind: 'rated',
    rated: { days: 7, rating: SearchNodeRating.RATING_HARD }
  };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'rated');
  assert.equal(rt.rated.days, 7);
  assert.equal(rt.rated.rating, SearchNodeRating.RATING_HARD);
});

test('SearchNode dupe (notetypeId=123 + firstField=hello) round-trips', () => {
  const node = {
    kind: 'dupe',
    dupe: { notetypeId: 123, firstField: 'hello' }
  };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'dupe');
  assert.equal(rt.dupe.notetypeId, 123);
  assert.equal(rt.dupe.firstField, 'hello');
});

test('SearchNode flag=FLAG_RED round-trips', () => {
  const node = { kind: 'flag', flag: SearchNodeFlag.FLAG_RED };
  const rt = roundTripSearchNode(node);
  assert.equal(rt.kind, 'flag');
  assert.equal(rt.flag, SearchNodeFlag.FLAG_RED);
});

test('SortOrder { kind: none } encodes as omitted (proto3 default)', () => {
  // none 是 SortOrder oneof 的默认值，encodeSearchRequest 不写 field 2
  const bytes = encodeSearchRequest({ search: '', order: { kind: 'none' } });
  assert.equal(bytes.length, 0, 'none order + empty search must produce zero bytes');
  const rt = decodeSearchRequestForTest(bytes);
  assert.equal(rt.order.kind, 'none', 'decoding absent field 2 defaults to none');
});

test('SortOrder { kind: custom, custom: field:Foo } round-trips', () => {
  const bytes = encodeSearchRequest({ search: '', order: { kind: 'custom', custom: 'field:Foo' } });
  const rt = decodeSearchRequestForTest(bytes);
  assert.equal(rt.order.kind, 'custom');
  assert.equal(rt.order.custom, 'field:Foo');
});

test('SortOrder { kind: builtin, column: due, reverse: true } round-trips', () => {
  const bytes = encodeSearchRequest({
    search: '',
    order: { kind: 'builtin', column: 'due', reverse: true }
  });
  const rt = decodeSearchRequestForTest(bytes);
  assert.equal(rt.order.kind, 'builtin');
  assert.equal(rt.order.column, 'due');
  assert.equal(rt.order.reverse, true);
});

test('SearchRequest { search: is:new, order: { kind: none } } round-trips', () => {
  const original = { search: 'is:new', order: { kind: 'none' } };
  const bytes = encodeSearchRequest(original);
  const rt = decodeSearchRequestForTest(bytes);
  assert.equal(rt.search, 'is:new');
  assert.equal(rt.order.kind, 'none', 'none order omitted on wire, defaults back to none');
});

test('FindAndReplaceRequest round-trips all six fields', () => {
  const original = {
    nids: [1, 2],
    search: 'foo',
    replacement: 'bar',
    regex: false,
    matchCase: true,
    fieldName: 'Front'
  };
  const bytes = encodeFindAndReplaceRequest(original);
  const rt = decodeFindAndReplaceRequestForTest(bytes);
  assert.deepEqual(rt.nids, [1, 2]);
  assert.equal(rt.search, 'foo');
  assert.equal(rt.replacement, 'bar');
  assert.equal(rt.regex, false, 'regex=false is proto3 default, must not be written but decoded as false');
  assert.equal(rt.matchCase, true);
  assert.equal(rt.fieldName, 'Front');
});

test('SearchResponse decodes packed repeated int64 (prost default wire type 2)', () => {
  // prost 对 proto3 repeated int64 默认 packed：field 1, wire type 2, 载荷是连续 varint
  const w = new 协议写入器();
  w.写入打包64位整数(1, [100, 200, 300]);
  const ids = decodeSearchResponse(w.转为字节());
  assert.deepEqual(ids, [100, 200, 300], 'packed repeated int64 must decode via wire type 2 payload');
});

test('SearchResponse also decodes non-packed repeated int64 (backward compat wire type 0)', () => {
  // 旧编码器可能用非 packed：每个元素单独 field 1, wire type 0
  const w = new 协议写入器();
  w.写入64位整数(1, 100);
  w.写入64位整数(1, 200);
  w.写入64位整数(1, 300);
  const ids = decodeSearchResponse(w.转为字节());
  assert.deepEqual(ids, [100, 200, 300], 'non-packed repeated int64 must still decode via wire type 0');
});

test('SearchResponse empty input returns empty array', () => {
  const ids = decodeSearchResponse(new Uint8Array(0));
  assert.deepEqual(ids, []);
});

test('SearchResponse mixed packed + non-packed accumulates all ids', () => {
  // prost 不会混用，但规范允许；解码器应能处理
  const w = new 协议写入器();
  w.写入打包64位整数(1, [1, 2]);
  w.写入64位整数(1, 3);
  const ids = decodeSearchResponse(w.转为字节());
  assert.deepEqual(ids, [1, 2, 3]);
});

test('BrowserColumns decodes column with key + labels + sorting', () => {
  const col = new 协议写入器();
  col.写入字符串(1, 'question');
  col.写入字符串(2, 'Question');
  col.写入字符串(3, '问题');
  col.写入变长整数(4, BrowserColumnSorting.SORTING_ASCENDING);
  col.写入变长整数(6, BrowserColumnAlignment.ALIGNMENT_CENTER);
  const cols = new 协议写入器();
  cols.写入子消息(1, col);

  const decoded = decodeBrowserColumns(cols.转为字节());
  assert.equal(decoded.columns.length, 1);
  assert.equal(decoded.columns[0].key, 'question');
  assert.equal(decoded.columns[0].cardsModeLabel, 'Question');
  assert.equal(decoded.columns[0].notesModeLabel, '问题');
  assert.equal(decoded.columns[0].sortingCards, BrowserColumnSorting.SORTING_ASCENDING);
  assert.equal(decoded.columns[0].sortingNotes, BrowserColumnSorting.SORTING_NONE, 'unset sorting defaults to NONE');
  assert.equal(decoded.columns[0].alignment, BrowserColumnAlignment.ALIGNMENT_CENTER);
  assert.equal(decoded.columns[0].usesCellFont, false, 'unset bool defaults to false');
});

test('BrowserRow decodes cells + color + fontName + fontSize', () => {
  const cell = new 协议写入器();
  cell.写入字符串(1, 'hello');
  cell.写入布尔(2, true);
  cell.写入变长整数(3, BrowserCellTextElideMode.ELIDE_RIGHT);
  const row = new 协议写入器();
  row.写入子消息(1, cell);
  row.写入变长整数(2, BrowserRowColor.COLOR_SUSPENDED);
  row.写入字符串(3, 'Arial');
  row.写入变长整数(4, 14);

  const decoded = decodeBrowserRow(row.转为字节());
  assert.equal(decoded.cells.length, 1);
  assert.equal(decoded.cells[0].text, 'hello');
  assert.equal(decoded.cells[0].isRtl, true);
  assert.equal(decoded.cells[0].elideMode, BrowserCellTextElideMode.ELIDE_RIGHT);
  assert.equal(decoded.color, BrowserRowColor.COLOR_SUSPENDED);
  assert.equal(decoded.fontName, 'Arial');
  assert.equal(decoded.fontSize, 14);
});

test('proto3: empty parsable_text SearchNode encodes to zero bytes', () => {
  const bytes = encodeSearchNode(makeParsableTextNode('')).转为字节();
  assert.equal(bytes.length, 0, 'default text="" must be omitted');
});

test('proto3: empty SearchRequest encodes to zero bytes', () => {
  const bytes = encodeSearchRequest({ search: '', order: { kind: 'none' } });
  assert.equal(bytes.length, 0, 'all defaults must be omitted');
});

test('proto3: all-default FindAndReplaceRequest encodes to zero bytes', () => {
  const bytes = encodeFindAndReplaceRequest({
    nids: [], search: '', replacement: '', regex: false, matchCase: false, fieldName: ''
  });
  assert.equal(bytes.length, 0, 'all defaults must be omitted');
});

// ============================================================
// B. 搜索服务契约（9 个方法签名）
// ============================================================

let 搜索服务 = null;
let 实例 = null;

test('搜索服务 module loads with libjidecards.so stubbed', async () => {
  const mod = await import('../../entry/src/main/ets/backend/搜索服务.ts');
  搜索服务 = mod.搜索服务;
  assert.equal(typeof 搜索服务, 'function', '搜索服务 must be importable as a class');
});

test('搜索服务 is a class (has prototype constructor)', () => {
  assert.equal(typeof 搜索服务, 'function');
  assert.equal(搜索服务.prototype.constructor, 搜索服务);
});

test('new 搜索服务() instantiates without calling NAPI', () => {
  实例 = new 搜索服务();
  assert.ok(实例 instanceof 搜索服务, 'instance must be instanceof 搜索服务');
});

test('搜索服务.构建搜索串 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.构建搜索串, 'function');
  assert.equal(实例.构建搜索串.length, 1);
});

test('搜索服务.搜索卡片 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.搜索卡片, 'function');
  assert.equal(实例.搜索卡片.length, 1);
});

test('搜索服务.搜索笔记 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.搜索笔记, 'function');
  assert.equal(实例.搜索笔记.length, 1);
});

test('搜索服务.连接搜索节点 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.连接搜索节点, 'function');
  assert.equal(实例.连接搜索节点.length, 1);
});

test('搜索服务.替换搜索节点 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.替换搜索节点, 'function');
  assert.equal(实例.替换搜索节点.length, 1);
});

test('搜索服务.查找并替换 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.查找并替换, 'function');
  assert.equal(实例.查找并替换.length, 1);
});

test('搜索服务.全部浏览器列 is a function with 0 parameters', () => {
  assert.equal(typeof 实例.全部浏览器列, 'function');
  assert.equal(实例.全部浏览器列.length, 0);
});

test('搜索服务.浏览器行按ID is a function with 1 parameter', () => {
  assert.equal(typeof 实例.浏览器行按ID, 'function');
  assert.equal(实例.浏览器行按ID.length, 1);
});

test('搜索服务.设置激活浏览器列 is a function with 1 parameter', () => {
  assert.equal(typeof 实例.设置激活浏览器列, 'function');
  assert.equal(实例.设置激活浏览器列.length, 1);
});

// ============================================================
// C. i18n key 完整性
// ============================================================

test('browser_* i18n keys exist and align between zh-Hans and en_US', () => {
  const zh = JSON.parse(read('entry/src/main/resources/base/element/string.json'));
  const en = JSON.parse(read('entry/src/main/resources/en_US/element/string.json'));

  const zhKeys = new Set(zh.string.filter(e => e.name.startsWith('browser_')).map(e => e.name));
  const enKeys = new Set(en.string.filter(e => e.name.startsWith('browser_')).map(e => e.name));

  assert.ok(zhKeys.size > 0, 'zh-Hans must have browser_* keys');
  assert.ok(enKeys.size > 0, 'en_US must have browser_* keys');

  const missingInEn = [...zhKeys].filter(k => !enKeys.has(k));
  const missingInZh = [...enKeys].filter(k => !zhKeys.has(k));

  assert.deepEqual(missingInEn, [], `en_US missing browser_* keys: ${missingInEn.join(', ')}`);
  assert.deepEqual(missingInZh, [], `zh-Hans missing browser_* keys: ${missingInZh.join(', ')}`);
  assert.equal(zhKeys.size, enKeys.size, 'browser_* key count must match between zh and en');
});

// ============================================================
// D. T7 浏览编辑区接线契约
// 浏览页必须导入并使用 浏览编辑区 + 笔记服务.更新笔记 + 笔记类型服务.获取笔记类型；
// 编辑区组件必须保留 onCancel/onSave 回调签名与 isDark/busy/errorMessage/fieldNames
// /initialFieldValues/initialTags 六个 @Prop。修改这些字段名会破坏接线。
// ============================================================

test('BrowserPage wires T7 edit panel: imports 浏览编辑区 + 笔记服务 + 笔记类型服务 + 卡片服务', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /import\s+\{[^}]*浏览编辑区[^}]*\}\s*from\s*['"][^'"]*浏览编辑区['"]/);
  assert.match(page, /import\s+\{[^}]*笔记服务[^}]*\}\s*from\s*['"][^'"]*笔记服务['"]/);
  assert.match(page, /import\s+\{[^}]*笔记类型服务[^}]*\}\s*from\s*['"][^'"]*笔记类型服务['"]/);
  assert.match(page, /import\s+\{[^}]*卡片服务[^}]*\}\s*from\s*['"][^'"]*卡片服务['"]/);
  assert.match(page, /import\s+type\s+\{[^}]*EditableNote[^}]*\}\s*from\s*['"][^'"]*NoteMessages['"]/);
});

test('BrowserPage 行点击 loads note via 笔记服务.获取笔记 and field names via 笔记类型服务.获取笔记类型', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /private\s+async\s+行点击\s*\(/);
  assert.match(page, /this\.笔记服务实例\.获取笔记\s*\(/);
  assert.match(page, /this\.笔记类型服务实例\.获取笔记类型\s*\(/);
  assert.match(page, /this\.卡片服务实例\.获取卡片\s*\(/);
  // Cards 模式经 card.noteId 跳到 noteId
  assert.match(page, /card\.noteId/);
});

test('BrowserPage 保存编辑 calls 笔记服务.更新笔记 with skipUndoEntry=false and refreshes list', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /private\s+async\s+保存编辑\s*\(/);
  assert.match(page, /this\.笔记服务实例\.更新笔记\s*\(\s*\[[^\]]+\]\s*,\s*false\s*\)/);
  // 保存成功后关闭弹层 + 重新搜索
  assert.match(page, /this\.显示编辑区\s*=\s*false/);
  assert.match(page, /this\.执行搜索\s*\(\s*\)/);
});

test('BrowserPage build renders 浏览编辑区 conditionally on 显示编辑区', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /if\s*\(this\.显示编辑区\)\s*\{/);
  assert.match(page, /浏览编辑区\s*\(\s*\{/);
  // 接线必备 @Prop 与回调
  assert.match(page, /isDark:\s*this\.是否深色\s*\(\s*\)/);
  assert.match(page, /fieldNames:\s*this\.编辑区字段名列表/);
  assert.match(page, /initialFieldValues:\s*this\.编辑区初始字段值/);
  assert.match(page, /initialTags:\s*this\.编辑区初始标签/);
  // onSave 回调最终调 this.保存编辑（箭头函数体跨行，用 [\s\S] 非贪婪匹配）
  assert.match(page, /onSave:[\s\S]*?this\.保存编辑/);
});

test('浏览编辑区 component preserves T7 presentation-only invariants', () => {
  const panel = read('entry/src/main/ets/components/browser/浏览编辑区.ets');
  // 纯展示层：不直接调后端
  assert.doesNotMatch(panel, /后端会话|笔记服务|笔记类型服务|\.run\(/);
  // 必备 @Prop 与回调签名
  assert.match(panel, /@Prop\s+isDark:\s*boolean/);
  assert.match(panel, /@Prop\s+busy:\s*boolean/);
  assert.match(panel, /@Prop\s+errorMessage:\s*string/);
  assert.match(panel, /@Prop\s+fieldNames:\s*string\[\]/);
  assert.match(panel, /@Prop\s+initialFieldValues:\s*string\[\]/);
  assert.match(panel, /@Prop\s+initialTags:\s*string/);
  assert.match(panel, /onCancel:\s*\(\)\s*=>\s*void/);
  assert.match(panel, /onSave:\s*\(fields:\s*string\[\],\s*tags:\s*string\[\]\)\s*=>\s*Promise<boolean>/);
  // 草稿保留：aboutToAppear 从 initialFieldValues/initialTags 拷贝到内部状态
  assert.match(panel, /this\.fieldValues\s*=\s*this\.initialFieldValues\.slice/);
  assert.match(panel, /this\.tags\s*=\s*this\.initialTags/);
});

// ============================================================
// E. T8 批量操作栏接线契约
// 浏览页必须导入并使用 批量操作栏 + 牌组服务 + 调度器服务.批量埋藏或暂停卡片；
// 批量操作栏组件必须保留 4 个回调签名与 isDark/busy/选中数 @Prop；
// 卡片表格必须上抛 onSelectionChange/onMultiSelectChange 回调。
// ============================================================

test('BrowserPage wires T8 batch actions: imports 批量操作栏 + 牌组服务 + 调度器服务 + DeckTreeNode + BURY_SUSPEND_MODE_SUSPEND', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /import\s+\{[^}]*批量操作栏[^}]*\}\s*from\s*['"][^'"]*批量操作栏['"]/);
  assert.match(page, /import\s+\{[^}]*牌组服务[^}]*\}\s*from\s*['"][^'"]*牌组服务['"]/);
  assert.match(page, /import\s+\{[^}]*调度器服务[^}]*\}\s*from\s*['"][^'"]*调度器服务['"]/);
  assert.match(page, /import\s+type\s+\{[^}]*DeckTreeNode[^}]*\}\s*from\s*['"][^'"]*DeckMessages['"]/);
  assert.match(page, /import\s+\{[^}]*BURY_SUSPEND_MODE_SUSPEND[^}]*\}\s*from\s*['"][^'"]*SchedulerMessages['"]/);
});

test('BrowserPage has T8 batch action methods', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /private\s+async\s+执行批量改牌组\s*\(/);
  assert.match(page, /private\s+async\s+执行批量设置标志\s*\(/);
  assert.match(page, /private\s+async\s+执行批量挂起\s*\(/);
  assert.match(page, /private\s+async\s+执行批量删除\s*\(/);
  assert.match(page, /private\s+async\s+解析选中为卡片ID\s*\(/);
  assert.match(page, /private\s+退出多选\s*\(/);
  assert.match(page, /private\s+扁平化牌组树\s*\(/);
  assert.match(page, /private\s+标志文案\s*\(/);
  // 4 个操作分别调对应 service
  assert.match(page, /this\.卡片服务实例\.设置牌组\s*\(/);
  assert.match(page, /this\.卡片服务实例\.设置标志\s*\(/);
  assert.match(page, /this\.调度器服务实例\.批量埋藏或暂停卡片\s*\(/);
  assert.match(page, /this\.卡片服务实例\.删除卡片\s*\(/);
});

test('BrowserPage build renders 批量操作栏 conditionally on 多选模式值 + 选中ID列表', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /if\s*\(this\.多选模式值\s*&&\s*this\.选中ID列表\.length\s*>\s*0\)/);
  assert.match(page, /批量操作栏\s*\(\s*\{/);
  assert.match(page, /on改牌组:[\s\S]*?this\.打开改牌组弹层/);
  assert.match(page, /on设置标志:[\s\S]*?this\.显示标志弹层\s*=\s*true/);
  assert.match(page, /on挂起:[\s\S]*?this\.显示挂起确认\s*=\s*true/);
  assert.match(page, /on删除:[\s\S]*?this\.显示删除确认\s*=\s*true/);
  // 4 个弹层
  assert.match(page, /if\s*\(this\.显示改牌组弹层\)/);
  assert.match(page, /if\s*\(this\.显示标志弹层\)/);
  assert.match(page, /if\s*\(this\.显示挂起确认\)/);
  assert.match(page, /if\s*\(this\.显示删除确认\)/);
});

test('批量操作栏 component preserves T8 presentation-only invariants', () => {
  const bar = read('entry/src/main/ets/components/browser/批量操作栏.ets');
  // 纯展示层：不直接调后端
  assert.doesNotMatch(bar, /后端会话|卡片服务|笔记服务|牌组服务|调度器服务|\.run\(/);
  // 必备 @Prop 与回调签名
  assert.match(bar, /@Prop\s+isDark:\s*boolean/);
  assert.match(bar, /@Prop\s+busy:\s*boolean/);
  assert.match(bar, /@Prop\s+选中数:\s*number/);
  assert.match(bar, /on改牌组:\s*\(\)\s*=>\s*void/);
  assert.match(bar, /on设置标志:\s*\(\)\s*=>\s*void/);
  assert.match(bar, /on挂起:\s*\(\)\s*=>\s*void/);
  assert.match(bar, /on删除:\s*\(\)\s*=>\s*void/);
  // 4 个按钮文案走 i18n
  assert.match(bar, /app\.string\.browser_action_change_deck/);
  assert.match(bar, /app\.string\.browser_action_set_flag/);
  assert.match(bar, /app\.string\.browser_action_suspend/);
  assert.match(bar, /app\.string\.browser_action_delete/);
});

test('卡片表格 component exposes onSelectionChange + onMultiSelectChange callbacks', () => {
  const table = read('entry/src/main/ets/components/browser/卡片表格.ets');
  assert.match(table, /onSelectionChange:\s*\(选中IDs:\s*number\[\]\)\s*=>\s*void/);
  assert.match(table, /onMultiSelectChange:\s*\(多选:\s*boolean\)\s*=>\s*void/);
  // 选中变化时上抛
  assert.match(table, /this\.onSelectionChange\s*\(\s*Array\.from/);
  assert.match(table, /this\.onMultiSelectChange\s*\(\s*true\s*\)/);
  assert.match(table, /this\.onMultiSelectChange\s*\(\s*false\s*\)/);
});

test('调度器服务 exposes 批量埋藏或暂停卡片 method (T8 batch suspend)', () => {
  const svc = read('entry/src/main/ets/backend/调度器服务.ts');
  assert.match(svc, /async\s+批量埋藏或暂停卡片\s*\(\s*卡片ID列表:\s*number\[\],\s*模式:\s*number\s*\)/);
  assert.match(svc, /this\.会话\.调用\s*\(\s*服务号\.后端调度器,\s*调度器方法\.埋藏或暂停/);
});

test('T8 i18n keys exist in both base and en_US string.json', () => {
  const zh = read('entry/src/main/resources/base/element/string.json');
  const en = read('entry/src/main/resources/en_US/element/string.json');
  const keys = [
    'browser_detail_confirm',
    'browser_action_deck_load_error',
    'browser_action_deck_error',
    'browser_action_flag_error',
    'browser_action_suspend_error',
    'browser_action_delete_error',
    'browser_action_notes_mode_hint',
    'browser_action_suspend_confirm',
    'browser_action_delete_confirm',
    'browser_action_flag_none',
    'browser_action_flag_red',
    'browser_action_flag_orange',
    'browser_action_flag_green',
    'browser_action_flag_blue'
  ];
  for (const k of keys) {
    assert.match(zh, new RegExp(`"name":\\s*"${k}"`), `base missing ${k}`);
    assert.match(en, new RegExp(`"name":\\s*"${k}"`), `en_US missing ${k}`);
  }
});

// ============================================================
// F. T11 卡片信息接线契约
// 浏览页必须导入并使用 卡片信息 + 统计服务.获取卡片统计 + CardStatsView 类型；
// 卡片信息组件必须保留 isDark/stats/errorMessage @Prop + onClose 回调；
// 卡片表格必须上抛 onInfoClick 回调；统计服务必须实现 获取卡片统计 方法；
// 服务索引必须含 统计方法.卡片统计=0；StatsMessages 必须导出
// encodeCardIdRequest/decodeCardStatsResponse/ReviewKind。
// ============================================================

test('BrowserPage wires T11 card info: imports 卡片信息 + 统计服务 + CardStatsView', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /import\s+\{[^}]*卡片信息[^}]*\}\s*from\s*['"][^'"]*卡片信息['"]/);
  assert.match(page, /import\s+\{[^}]*统计服务[^}]*\}\s*from\s*['"][^'"]*统计服务['"]/);
  assert.match(page, /import\s+type\s+\{[^}]*CardStatsView[^}]*\}\s*from\s*['"][^'"]*StatsMessages['"]/);
  assert.match(page, /private\s+readonly\s+统计服务实例:\s*统计服务/);
});

test('BrowserPage has T11 打开卡片信息 / 关闭卡片信息 methods', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /private\s+async\s+打开卡片信息\s*\(\s*卡片ID:\s*number\s*\)/);
  assert.match(page, /private\s+关闭卡片信息\s*\(\s*\)/);
  // 打开时调 统计服务.获取卡片统计
  assert.match(page, /this\.统计服务实例\.获取卡片统计\s*\(/);
  // 4 个 @State：显示 / 数据 / 错误 / 忙碌
  assert.match(page, /@State\s+private\s+显示卡片信息:\s*boolean/);
  assert.match(page, /@State\s+private\s+卡片信息数据:\s*CardStatsView\s*\|\s*null/);
  assert.match(page, /@State\s+private\s+卡片信息错误:\s*string/);
  assert.match(page, /@State\s+private\s+卡片信息忙碌:\s*boolean/);
});

test('BrowserPage build renders 卡片信息 conditionally on 显示卡片信息', () => {
  const page = read('entry/src/main/ets/pages/浏览页.ets');
  assert.match(page, /if\s*\(this\.显示卡片信息\)\s*\{/);
  assert.match(page, /卡片信息\s*\(\s*\{/);
  assert.match(page, /isDark:\s*this\.是否深色\s*\(\s*\)/);
  assert.match(page, /stats:\s*this\.卡片信息数据/);
  assert.match(page, /onClose:[\s\S]*?this\.关闭卡片信息/);
});

test('卡片表格 component exposes onInfoClick callback for T11', () => {
  const table = read('entry/src/main/ets/components/browser/卡片表格.ets');
  assert.match(table, /onInfoClick:\s*\(id:\s*number\)\s*=>\s*void/);
  // 非多选模式下渲染 info 按钮并用 hitTestBehavior(Block) 阻止冒泡后上抛
  assert.match(table, /if\s*\(\s*!this\.多选模式\s*\)/);
  assert.match(table, /hitTestBehavior\s*\(\s*HitTestMode\.Block\s*\)/);
  assert.match(table, /this\.onInfoClick\s*\(\s*行\.id\s*\)/);
});

test('统计服务 exposes 获取卡片统计 method (T11 card stats)', () => {
  const svc = read('entry/src/main/ets/backend/统计服务.ts');
  assert.match(svc, /async\s+获取卡片统计\s*\(\s*卡片ID:\s*number\s*\):\s*Promise<CardStatsView>/);
  assert.match(svc, /this\.会话\.调用\s*\(\s*服务号\.后端统计,\s*统计方法\.卡片统计/);
  assert.match(svc, /decodeCardStatsResponse\s*\(/);
  assert.match(svc, /encodeCardIdRequest\s*\(/);
});

test('服务索引 defines 统计方法.卡片统计 = 0 (Anki stats.proto CardStats)', () => {
  const idx = read('entry/src/main/ets/backend/服务索引.ts');
  assert.match(idx, /卡片统计:\s*0/);
});

test('卡片信息 component preserves T11 presentation-only invariants', () => {
  const panel = read('entry/src/main/ets/components/browser/卡片信息.ets');
  // 纯展示层：不直接调后端
  assert.doesNotMatch(panel, /后端会话|统计服务|卡片服务|笔记服务|\.会话\.调用\s*\(/);
  // 必备 @Prop 与回调签名
  assert.match(panel, /@Prop\s+isDark:\s*boolean/);
  assert.match(panel, /@Prop\s+stats:\s*CardStatsView\s*\|\s*null/);
  assert.match(panel, /@Prop\s+errorMessage:\s*string/);
  assert.match(panel, /onClose:\s*\(\)\s*=>\s*void/);
  // 标题与分区文案走 i18n
  assert.match(panel, /app\.string\.browser_info_title/);
  assert.match(panel, /app\.string\.browser_info_section_schedule/);
  assert.match(panel, /app\.string\.browser_info_section_history/);
  // 关闭按钮文案走 i18n
  assert.match(panel, /app\.string\.browser_info_close/);
  // ReviewKind → 文案映射（6 个枚举值）
  assert.match(panel, /ReviewKind\.LEARNING/);
  assert.match(panel, /ReviewKind\.REVIEW/);
  assert.match(panel, /ReviewKind\.RELEARNING/);
  assert.match(panel, /ReviewKind\.FILTERED/);
  assert.match(panel, /ReviewKind\.MANUAL/);
  assert.match(panel, /ReviewKind\.RESCHEDULED/);
});

// ============================================================
// G. T11 proto 编解码往返
// encodeCardIdRequest / decodeCardStatsResponse / decodeStatsRevlogEntry
// 与 stats.proto CardStats/CardStatsResponse/StatsRevlogEntry wire format 对齐。
// ============================================================

test('encodeCardIdRequest(cardId=0) produces zero bytes (proto3 default omitted)', () => {
  const bytes = encodeCardIdRequest(0);
  assert.equal(bytes.length, 0, 'cardId=0 must be omitted');
});

test('encodeCardIdRequest(cardId=42) round-trips via 协议读取器', () => {
  const bytes = encodeCardIdRequest(42);
  const r = new 协议读取器(bytes);
  const tag = r.读取标签();
  assert.equal(tag.字段号, 1);
  assert.equal(tag.线类型, 0, 'int64 field uses wire type 0 (varint)');
  assert.equal(r.读取64位整数(), 42);
  assert.equal(r.读取标签(), null, 'no more fields');
});

test('decodeCardStatsResponse decodes empty bytes as all-default CardStatsView', () => {
  const out = decodeCardStatsResponse(new Uint8Array(0));
  assert.deepEqual(out.revlog, []);
  assert.equal(out.cardId, 0);
  assert.equal(out.noteId, 0);
  assert.equal(out.deck, '');
  assert.equal(out.added, 0);
  assert.equal(out.interval, 0);
  assert.equal(out.reviews, 0);
  assert.equal(out.lapses, 0);
  assert.equal(out.cardType, '');
  assert.equal(out.notetype, '');
  assert.equal(out.firstReview, undefined);
  assert.equal(out.latestReview, undefined);
  assert.equal(out.dueDate, undefined);
  assert.equal(out.duePosition, undefined);
  assert.equal(out.fsrsRetrievability, undefined);
});

test('decodeCardStatsResponse round-trips all 17 top-level fields', () => {
  // 构造一个含全部字段的 CardStatsResponse 字节流
  const revlog = new 协议写入器();
  revlog.写入64位整数(1, 1700000000);              // time
  revlog.写入变长整数(2, ReviewKind.REVIEW);        // reviewKind
  revlog.写入变长整数(3, 3);                         // buttonChosen
  revlog.写入变长整数(4, 86400);                     // interval
  revlog.写入变长整数(5, 2500);                      // ease
  revlog.写入浮点(6, 12.5);                          // takenSecs
  revlog.写入变长整数(8, 43200);                     // lastInterval

  const w = new 协议写入器();
  w.写入子消息(1, revlog);
  w.写入64位整数(2, 12345);                          // cardId
  w.写入64位整数(3, 67890);                          // noteId
  w.写入字符串(4, 'Default::Sub');                   // deck
  w.写入64位整数(5, 1690000000);                     // added
  w.写入64位整数(6, 1690001000);                     // firstReview
  w.写入64位整数(7, 1700000000);                     // latestReview
  w.写入64位整数(8, 1710000000);                     // dueDate
  w.写入变长整数(9, 7);                              // duePosition
  w.写入变长整数(10, 21);                            // interval
  w.写入变长整数(11, 2500);                          // ease
  w.写入变长整数(12, 15);                            // reviews
  w.写入变长整数(13, 2);                             // lapses
  w.写入浮点(14, 8.3);                              // averageSecs
  w.写入浮点(15, 124.5);                            // totalSecs
  w.写入字符串(16, 'rev');                           // cardType
  w.写入字符串(17, 'Basic');                         // notetype
  w.写入浮点(19, 0.875);                            // fsrsRetrievability

  const out = decodeCardStatsResponse(w.转为字节());
  assert.equal(out.revlog.length, 1);
  assert.equal(out.revlog[0].time, 1700000000);
  assert.equal(out.revlog[0].reviewKind, ReviewKind.REVIEW);
  assert.equal(out.revlog[0].buttonChosen, 3);
  assert.equal(out.revlog[0].interval, 86400);
  assert.equal(out.revlog[0].ease, 2500);
  assert.equal(out.revlog[0].takenSecs, 12.5);
  assert.equal(out.revlog[0].lastInterval, 43200);
  assert.equal(out.cardId, 12345);
  assert.equal(out.noteId, 67890);
  assert.equal(out.deck, 'Default::Sub');
  assert.equal(out.added, 1690000000);
  assert.equal(out.firstReview, 1690001000);
  assert.equal(out.latestReview, 1700000000);
  assert.equal(out.dueDate, 1710000000);
  assert.equal(out.duePosition, 7);
  assert.equal(out.interval, 21);
  assert.equal(out.ease, 2500);
  assert.equal(out.reviews, 15);
  assert.equal(out.lapses, 2);
  assert.equal(out.averageSecs === undefined ? undefined : Math.abs(out.averageSecs - 8.3) < 0.001, true, `averageSecs float32 precision: actual=${out.averageSecs}`);
  assert.equal(out.totalSecs === undefined ? undefined : Math.abs(out.totalSecs - 124.5) < 0.001, true, `totalSecs float32 precision: actual=${out.totalSecs}`);
  assert.equal(out.cardType, 'rev');
  assert.equal(out.notetype, 'Basic');
  assert.equal(out.fsrsRetrievability === undefined ? undefined : Math.abs(out.fsrsRetrievability - 0.875) < 0.001, true, `fsrsRetrievability float32 precision: actual=${out.fsrsRetrievability}`);
});

test('decodeCardStatsResponse decodes multiple revlog entries in order', () => {
  const revlog1 = new 协议写入器();
  revlog1.写入64位整数(1, 1700000000);
  revlog1.写入变长整数(2, ReviewKind.REVIEW);
  const revlog2 = new 协议写入器();
  revlog2.写入64位整数(1, 1690000000);
  revlog2.写入变长整数(2, ReviewKind.LEARNING);
  const w = new 协议写入器();
  w.写入子消息(1, revlog1);
  w.写入子消息(1, revlog2);
  const out = decodeCardStatsResponse(w.转为字节());
  assert.equal(out.revlog.length, 2);
  assert.equal(out.revlog[0].time, 1700000000);
  assert.equal(out.revlog[0].reviewKind, ReviewKind.REVIEW);
  assert.equal(out.revlog[1].time, 1690000000);
  assert.equal(out.revlog[1].reviewKind, ReviewKind.LEARNING);
});

test('decodeCardStatsResponse skips unknown fields (forward compat)', () => {
  // 假设未来 Anki 加了 field 20 (string)，本解码器应跳过不崩
  const w = new 协议写入器();
  w.写入字符串(20, 'unknown future field');
  w.写入64位整数(2, 999); // cardId
  const out = decodeCardStatsResponse(w.转为字节());
  assert.equal(out.cardId, 999);
});

test('T11 i18n keys exist in both base and en_US string.json', () => {
  const zh = read('entry/src/main/resources/base/element/string.json');
  const en = read('entry/src/main/resources/en_US/element/string.json');
  const keys = [
    'browser_info_title',
    'browser_info_loading',
    'browser_info_load_error',
    'browser_info_close',
    'browser_info_section_schedule',
    'browser_info_section_history',
    'browser_info_added',
    'browser_info_first_review',
    'browser_info_latest_review',
    'browser_info_due',
    'browser_info_interval',
    'browser_info_ease',
    'browser_info_reviews',
    'browser_info_lapses',
    'browser_info_avg_time',
    'browser_info_total_time',
    'browser_info_card_type',
    'browser_info_notetype',
    'browser_info_deck',
    'browser_info_retrievability',
    'browser_info_kind_learning',
    'browser_info_kind_review',
    'browser_info_kind_relearning',
    'browser_info_kind_filtered',
    'browser_info_kind_manual',
    'browser_info_kind_rescheduled',
    'browser_info_button_again',
    'browser_info_button_hard',
    'browser_info_button_good',
    'browser_info_button_easy'
  ];
  for (const k of keys) {
    assert.match(zh, new RegExp(`"name":\\s*"${k}"`), `base missing ${k}`);
    assert.match(en, new RegExp(`"name":\\s*"${k}"`), `en_US missing ${k}`);
  }
});

