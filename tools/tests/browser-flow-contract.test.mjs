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
