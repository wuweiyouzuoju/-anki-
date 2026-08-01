// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import { encodeDeckId } from '../../entry/src/main/ets/proto/messages/DeckMessages.ts';
import { decodeCountsForDeckToday } from '../../entry/src/main/ets/proto/messages/SchedulerMessages.ts';
import { 协议写入器 } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import {
  构建卡片HTML,
  媒体基地址,
  原始侧HTML,
  重写媒体地址
} from '../../entry/src/main/ets/model/学习卡片HTML构建器.ets';
import {
  decodeExtractAvTagsResponse,
  encodeExtractAvTagsRequest
} from '../../entry/src/main/ets/proto/messages/CardRenderingMessages.ts';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const SCHEDULER = 'entry/src/main/ets/backend/调度器服务.ts';
const RENDERING = 'entry/src/main/ets/backend/卡片渲染服务.ts';
const STUDY_PAGE = 'entry/src/main/ets/pages/学习页.ets';
const MEDIA_HELPER = 'entry/src/main/ets/utils/媒体响应助手.ets';
const INDEX_PAGE = 'entry/src/main/ets/pages/首页.ets';
const MAIN_PAGES = 'entry/src/main/resources/base/profile/main_pages.json';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('scheduler service walks the study queue contract', () => {
  const service = read(SCHEDULER);

  assert.match(service, /async 获取队首卡片\(牌组ID: number\): Promise<QueuedCardsView>/);
  assert.match(service, /牌组方法\.设置当前牌组/, 'must select deck before queueing');
  assert.match(service, /调度器方法\.获取队首卡片/);
  assert.match(service, /encodeGetQueuedCardsRequest\(1, false\)/, 'fetch one card at a time');
  assert.match(service, /调度器方法\.描述下一档状态/);
  assert.match(service, /encodeSchedulingStates\(状态字节\)/, 'states passthrough for labels');
  assert.match(service, /调度器方法\.提交评分/);
  assert.match(service, /encodeCardAnswer\(作答参数\)/);
  assert.doesNotMatch(service, /new 后端客户端/, 'must go through 后端会话');
});

test('card rendering service wraps RenderExistingCard and ExtractAvTags', () => {
  const service = read(RENDERING);

  assert.match(service, /async 渲染既有卡片\(卡片ID: number\): Promise<RenderedCard>/);
  assert.match(service, /卡片渲染方法\.渲染既有卡片/);
  assert.match(service, /encodeRenderExistingCardRequest\(卡片ID\)/);
  assert.match(service, /async 提取音频文件\(HTML文本: string, 是否正面: boolean\): Promise<string\[\]>/);
  assert.match(service, /卡片渲染方法\.提取音视频标签/);
  assert.match(service, /encodeExtractAvTagsRequest\(HTML文本, 是否正面\)/);
  assert.doesNotMatch(service, /new 后端客户端/);
});

test('deck id encoder matches decks.DeckId wire format', () => {
  assert.deepEqual(Array.from(encodeDeckId(300)), [0x08, 0xAC, 0x02]);
  assert.deepEqual(Array.from(encodeDeckId(0)), [], 'proto3 default omitted');
});

test('html builder assembles nodes, css and media base url', () => {
  const rendered = {
    questionNodes: [
      { text: '<div class="front">', replacement: null },
      { text: null, replacement: { fieldName: 'Front', currentText: '猫 <img src="neko.png">', filters: [] } },
      { text: '</div>', replacement: null }
    ],
    answerNodes: [
      { text: null, replacement: { fieldName: 'Back', currentText: 'cat <a href="sound.mp3">play</a>', filters: [] } }
    ],
    css: '.card { color: black; }',
    latexSvg: false,
    isEmpty: false
  };

  const question = 构建卡片HTML(rendered, 'question');
  assert.match(question, /<!DOCTYPE html>/);
  assert.match(question, /<style>\.card \{ color: black; \}/);
  assert.match(question, /猫 <img src="https:\/\/jidecards-media\.local\/neko\.png">/);
  assert.match(question, /<div class="front">/);

  const answer = 构建卡片HTML(rendered, 'answer');
  assert.match(answer, /href="https:\/\/jidecards-media\.local\/sound\.mp3"/);
  assert.ok(!answer.includes('neko.png'), 'answer side must not include question nodes');
});

test('media url rewrite skips absolute urls and anchors', () => {
  const html = '<img src="https://cdn.example.com/a.png"><img src="/abs.png">' +
    '<a href="#section">x</a><img src="空格 图.png">';
  const out = 重写媒体地址(html);
  assert.match(out, /src="https:\/\/cdn\.example\.com\/a\.png"/, 'absolute http untouched');
  assert.match(out, /src="\/abs\.png"/, 'absolute path untouched');
  assert.match(out, /href="#section"/, 'anchor untouched');
  assert.match(out, new RegExp(`src="${媒体基地址.replaceAll('.', '\\.')}${encodeURIComponent('空格 图.png')}"`),
    'relative media names are rewritten and uri-encoded');
});

test('html builder strips [sound:] tags, playback left to native player', () => {
  const rendered = {
    questionNodes: [
      { text: '<div>front</div>', replacement: null }
    ],
    answerNodes: [
      { text: null, replacement: { fieldName: 'Back', currentText: 'hello [sound:word.mp3] world', filters: [] } }
    ],
    css: '',
    latexSvg: false,
    isEmpty: false
  };

  const html = 构建卡片HTML(rendered, 'answer');
  assert.ok(!html.includes('[sound:'), 'raw sound syntax must be consumed');
  assert.ok(!html.includes('<audio'), 'no web audio elements in native player scheme');
  assert.match(html, /class="sound-flag"/, 'a small marker stays where audio was');
  assert.match(原始侧HTML(rendered, 'answer'), /\[sound:word\.mp3\]/, 'raw side keeps tags for extraction');
});

test('extract av tags wire format round-trips sound files in order', () => {
  const tag = (name) => {
    const w = new 协议写入器();
    w.写入字符串(1, name);
    return w.转为字节();
  };
  const w = new 协议写入器();
  w.写入字符串(1, 'stripped text');
  w.写入字节(2, tag('a.mp3'));
  w.写入字节(2, tag('b.ogg'));
  const out = decodeExtractAvTagsResponse(w.转为字节());
  assert.equal(out.text, 'stripped text');
  assert.deepEqual(out.soundFiles, ['a.mp3', 'b.ogg']);

  assert.deepEqual(Array.from(encodeExtractAvTagsRequest('', false)), []);
});

test('sound player wraps AVPlayer as a serial queue player', () => {
  const player = read('entry/src/main/ets/utils/声音播放器.ets');
  assert.match(player, /media\.createAVPlayer\(\)/);
  assert.match(player, /async 播放队列\(路径列表: string\[\]\)/);
  assert.match(player, /async 重播\(\)/);
  assert.match(player, /async 释放\(\)/);
  assert.match(player, /播放器\.fdSrc = \{ fd: 文件\.fd, offset: 0, length: /);
  assert.match(player, /状态 === 'completed' \|\| 状态 === 'error'/, 'completed advances the queue');
});

test('study page plays card audio through native SoundPlayer', () => {
  const page = read(STUDY_PAGE);
  assert.match(page, /import \{ 声音播放器 \} from '..\/utils\/声音播放器'/);
  assert.match(page, /提取音频文件\(rawHtml, questionSide\)/, 'extract av tags via backend');
  assert.match(page, /声音播放器实例\.播放队列\(/, 'auto play per side');
  assert.match(page, /声音播放器实例\.重播\(\)/, 'replay button wired');
  assert.match(page, /aboutToDisappear\(\)[\s\S]*?声音播放器实例\.释放\(\)/, 'player released on page exit');
  assert.doesNotMatch(page, /mediaPlayGestureAccess/, 'web audio scheme removed');
  assert.doesNotMatch(page, /runJavaScript\([^)]*\baudio\b/i, 'no injected audio playback script');
  assert.match(page, /runJavaScript\(['"]anki\.imageOcclusion\.setup\(\)['"]\)/,
    'image occlusion setup fallback wired via runJavaScript');
});

test('image occlusion IIFE exposes toggle and hides #toggle button (BUG-007)', () => {
  const builder = read('entry/src/main/ets/model/学习卡片HTML构建器.ets');
  assert.match(builder, /toggle:\s*function\s*\(\s*\)\s*\{/, 'anki.imageOcclusion.toggle method defined');
  assert.match(builder, /getElementById\(['"]toggle['"]\)/, '#toggle button looked up in setup');
  assert.match(builder, /btn\.style\.display\s*=\s*['"]none['"]/, '#toggle button hidden via display=none');
  assert.match(builder, /if\s*\(window\.anki\.imageOcclusion\)\s*\{\s*return;\s*\}/,
    'IIFE does not redefine anki.imageOcclusion if already present');
});

test('study page wires the full review loop', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /pageDeckId: string = ''/, 'deck id arrives via Navigation param');
  assert.match(page, /this\.pathStack\.pop\(\)/, 'back goes through NavPathStack pop');
  assert.doesNotMatch(page, /router\.(getParams|pushUrl|back)\b/, 'deprecated router must be gone');
  assert.match(page, /确保已打开\(context\.filesDir\)/);
  assert.match(page, /调度器服务实例\.获取队首卡片\(this\.牌组ID\)/);
  assert.match(page, /卡片渲染服务实例\.渲染既有卡片\(this\.当前卡片\.cardId\)/);
  assert.match(page, /调度器服务实例\.描述下一档状态\(this\.当前卡片\.states\)/);
  assert.match(page, /构建卡片HTML\(this\.已渲染, 'question'\)/);
  assert.match(page, /构建卡片HTML\(this\.已渲染, 'answer'\)/);
  assert.match(page, /调度器服务实例\.提交评分\(/);
  assert.match(page, /currentState: states\.current/, 'raw state passthrough on answer');
  assert.match(page, /queued\.cards\.length === 0[\s\S]*?阶段 = 'done'/, 'empty queue reaches done phase');
  assert.match(page, /this\.评分中 = true/, 'rating must be reentrancy-guarded');
});

test('study page web component blocks file-protocol cross origin correctly', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /Web\(\{ src: '', controller: this\.网页控制器 \}\)/);
  assert.match(page, /\.fileAccess\(true\)/);
  assert.match(page, /\.javaScriptAccess\(true\)/);
  assert.match(page, /\.onInterceptRequest\(/);
  assert.match(page, /loadData\(this\.正面HTML, 'text\/html', 'UTF-8', 媒体基地址, ' '\)/);
  assert.match(page, /loadData\(this\.背面HTML, 'text\/html', 'UTF-8', 媒体基地址, ' '\)/);
  assert.match(page, /读取媒体文件\(this\.媒体目录, fileName\)/);
  assert.match(page, /collection\.media/, 'media dir points at the anki media folder');
});

test('media helper infers mime types and reads sandbox files defensively', () => {
  const helper = read(MEDIA_HELPER);

  assert.match(helper, /export function 取MIME类型\(文件名: string\): string/);
  assert.match(helper, /'png': 'image\/png'/);
  assert.match(helper, /'mp3': 'audio\/mpeg'/);
  assert.match(helper, /application\/octet-stream/, 'unknown extensions fall back');
  assert.match(helper, /export function 读取媒体文件\(媒体目录: string, 文件名: string\): ArrayBuffer \| null/);
  assert.match(helper, /catch \(错误\) \{\s*return null;/, 'read failures degrade to null');
});

test('study page is registered and reachable from home', () => {
  const mainPages = JSON.parse(read(MAIN_PAGES));
  assert.ok(mainPages.src.includes('pages/首页'), '首页 must be registered');
  assert.ok(!mainPages.src.includes('pages/学习页'),
    '学习页 is a NavDestination, not a router page');

  const index = read(INDEX_PAGE);
  assert.match(index, /Navigation\(this\.页面栈\)/);
  assert.match(index, /\.navDestination\(this\.页面映射\)/);
  assert.match(index, /name: 'StudyPage'/);
  assert.match(index, /deckId: this\.选中的牌组ID/);
  assert.match(index, /deckName: 牌组显示名\(this\.选中牌组\(\)\)/,
    'deckName follows UI display name (covers user-customized aliases)');
  assert.match(index, /onPop[\s\S]{0,120}?加载主页数据\(\)/,
    'home refreshes after returning from study');
  assert.doesNotMatch(index, /router\.pushUrl/, 'deprecated router must be gone');
});

test('study strings are resourced', () => {
  const strings = read(STRINGS);
  for (const key of ['study_back', 'study_show_answer', 'study_remaining_detail',
    'study_finish_title', 'study_finish_hint', 'study_load_error', 'study_replay_sound',
    'rating_again', 'rating_hard', 'rating_good', 'rating_easy']) {
    assert.match(strings, new RegExp(`"name": "${key}"`), `missing string ${key}`);
  }

  const page = read(STUDY_PAGE);
  assert.doesNotMatch(page, /\.fontSize\(\d/, 'page must use dimension tokens');
  assert.match(page, /应用尺寸/);
  assert.match(page, /app\.string\.study_show_answer/);
  assert.match(page, /app\.string\.study_finish_title/);
  assert.match(page, /app\.string\.study_load_error/);
});

test('counts for deck today decodes new and review tallies', () => {
  const w = new 协议写入器();
  w.写入变长整数(1, 7);
  w.写入变长整数(2, 23);
  const counts = decodeCountsForDeckToday(w.转为字节());
  assert.equal(counts.newCount, 7);
  assert.equal(counts.reviewCount, 23);

  assert.deepEqual(decodeCountsForDeckToday(new Uint8Array(0)), { newCount: 0, reviewCount: 0 });
});

test('scheduler service exposes deck today counts via scheduler method 10', () => {
  const service = read(SCHEDULER);
  assert.match(service, /async 获取牌组今日计数\(牌组ID: number\): Promise<DeckTodayCounts>/);
  assert.match(service, /调度器方法\.牌组今日计数/);
  assert.match(service, /encodeDeckId\(牌组ID\)/);
});

test('home sources completed today from graphs.today.answerCount instead of per-deck RPCs', () => {
  const index = read(INDEX_PAGE);
  assert.doesNotMatch(index, /sumCompletedToday/,
    'sumCompletedToday must be removed; today.answerCount replaces it');
  assert.doesNotMatch(index, /调度器服务实例\.获取牌组今日计数/,
    'home must not call 获取牌组今日计数; graphs.today already aggregates all decks');
  assert.match(index, /构建主页快照\(tree, graphs/);
});
