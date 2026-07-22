// 复习流程链路契约测试（M7）：
// - SchedulerService/CardRenderingService 只经 BackendSession 走正确服务/方法索引；
// - StudyCardHtmlBuilder 为纯函数：节点流 → HTML，媒体相对路径重写到自建域名；
// - StudyPage 走完整链路（取卡→渲染→文案→评分→下一张），Web 组件配置防跨域；
// - Index.ets 通过 Navigation + NavPathStack 跳转 StudyPage（API 12 推荐写法，替代废弃 router）。
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import { encodeDeckId } from '../../entry/src/main/ets/proto/messages/DeckMessages.ts';
import { decodeCountsForDeckToday } from '../../entry/src/main/ets/proto/messages/SchedulerMessages.ts';
import { ProtoWriter } from '../../entry/src/main/ets/proto/core/ProtoWriter.ts';
import {
  buildCardHtml,
  MEDIA_BASE_URL,
  rawSideHtml,
  rewriteMediaUrls
} from '../../entry/src/main/ets/model/StudyCardHtmlBuilder.ets';
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

const SCHEDULER = 'entry/src/main/ets/backend/SchedulerService.ts';
const RENDERING = 'entry/src/main/ets/backend/CardRenderingService.ts';
const STUDY_PAGE = 'entry/src/main/ets/pages/StudyPage.ets';
const MEDIA_HELPER = 'entry/src/main/ets/utils/MediaResponseHelper.ets';
const INDEX_PAGE = 'entry/src/main/ets/pages/Index.ets';
const MAIN_PAGES = 'entry/src/main/resources/base/profile/main_pages.json';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('scheduler service walks the study queue contract', () => {
  const service = read(SCHEDULER);

  assert.match(service, /async getQueuedCards\(deckId: number\): Promise<QueuedCardsView>/);
  assert.match(service, /DECKS_METHOD\.SET_CURRENT_DECK/, 'must select deck before queueing');
  assert.match(service, /SCHEDULER_METHOD\.GET_QUEUED_CARDS/);
  assert.match(service, /encodeGetQueuedCardsRequest\(1, false\)/, 'fetch one card at a time');
  assert.match(service, /SCHEDULER_METHOD\.DESCRIBE_NEXT_STATES/);
  assert.match(service, /encodeSchedulingStates\(states\)/, 'states passthrough for labels');
  assert.match(service, /SCHEDULER_METHOD\.ANSWER_CARD/);
  assert.match(service, /encodeCardAnswer\(answer\)/);
  assert.doesNotMatch(service, /new BackendClient/, 'must go through BackendSession');
});

test('card rendering service wraps RenderExistingCard and ExtractAvTags', () => {
  const service = read(RENDERING);

  assert.match(service, /async renderExistingCard\(cardId: number\): Promise<RenderedCard>/);
  assert.match(service, /CARD_RENDERING_METHOD\.RENDER_EXISTING_CARD/);
  assert.match(service, /encodeRenderExistingCardRequest\(cardId\)/);
  assert.match(service, /async extractSoundFiles\(html: string, questionSide: boolean\): Promise<string\[\]>/);
  assert.match(service, /CARD_RENDERING_METHOD\.EXTRACT_AV_TAGS/);
  assert.match(service, /encodeExtractAvTagsRequest\(html, questionSide\)/);
  assert.doesNotMatch(service, /new BackendClient/);
});

test('deck id encoder matches decks.DeckId wire format', () => {
  // did=300 (varint 0xAC 0x02)，tag = field1 << 3 | 0 = 0x08
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

  const question = buildCardHtml(rendered, 'question');
  assert.match(question, /<!DOCTYPE html>/);
  assert.match(question, /<style>\.card \{ color: black; \}/);
  assert.match(question, /猫 <img src="https:\/\/jidecards-media\.local\/neko\.png">/);
  assert.match(question, /<div class="front">/);

  const answer = buildCardHtml(rendered, 'answer');
  assert.match(answer, /href="https:\/\/jidecards-media\.local\/sound\.mp3"/);
  assert.ok(!answer.includes('neko.png'), 'answer side must not include question nodes');
});

test('media url rewrite skips absolute urls and anchors', () => {
  const html = '<img src="https://cdn.example.com/a.png"><img src="/abs.png">' +
    '<a href="#section">x</a><img src="空格 图.png">';
  const out = rewriteMediaUrls(html);
  assert.match(out, /src="https:\/\/cdn\.example\.com\/a\.png"/, 'absolute http untouched');
  assert.match(out, /src="\/abs\.png"/, 'absolute path untouched');
  assert.match(out, /href="#section"/, 'anchor untouched');
  assert.match(out, new RegExp(`src="${MEDIA_BASE_URL.replaceAll('.', '\\.')}${encodeURIComponent('空格 图.png')}"`),
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

  const html = buildCardHtml(rendered, 'answer');
  assert.ok(!html.includes('[sound:'), 'raw sound syntax must be consumed');
  assert.ok(!html.includes('<audio'), 'no web audio elements in native player scheme');
  assert.match(html, /class="sound-flag"/, 'a small marker stays where audio was');
  assert.match(rawSideHtml(rendered, 'answer'), /\[sound:word\.mp3\]/, 'raw side keeps tags for extraction');
});

test('extract av tags wire format round-trips sound files in order', () => {
  const tag = (name) => {
    const w = new ProtoWriter();
    w.writeString(1, name);
    return w.toBytes();
  };
  const w = new ProtoWriter();
  w.writeString(1, 'stripped text');
  w.writeBytes(2, tag('a.mp3'));
  w.writeBytes(2, tag('b.ogg'));
  const out = decodeExtractAvTagsResponse(w.toBytes());
  assert.equal(out.text, 'stripped text');
  assert.deepEqual(out.soundFiles, ['a.mp3', 'b.ogg']);

  // 请求侧：questionSide=false 为 proto3 默认，不写字段
  assert.deepEqual(Array.from(encodeExtractAvTagsRequest('', false)), []);
});

test('sound player wraps AVPlayer as a serial queue player', () => {
  const player = read('entry/src/main/ets/utils/SoundPlayer.ets');
  assert.match(player, /media\.createAVPlayer\(\)/);
  assert.match(player, /async playQueue\(paths: string\[\]\)/);
  assert.match(player, /async replay\(\)/);
  assert.match(player, /async release\(\)/);
  assert.match(player, /player\.fdSrc = \{ fd: file\.fd, offset: 0, length: /);
  assert.match(player, /state === 'completed' \|\| state === 'error'/, 'completed advances the queue');
});

test('study page plays card audio through native SoundPlayer', () => {
  const page = read(STUDY_PAGE);
  assert.match(page, /import \{ SoundPlayer \} from '..\/utils\/SoundPlayer'/);
  assert.match(page, /extractSoundFiles\(rawHtml, questionSide\)/, 'extract av tags via backend');
  assert.match(page, /soundPlayer\.playQueue\(/, 'auto play per side');
  assert.match(page, /soundPlayer\.replay\(\)/, 'replay button wired');
  assert.match(page, /aboutToDisappear\(\)[\s\S]*?soundPlayer\.release\(\)/, 'player released on page exit');
  assert.doesNotMatch(page, /mediaPlayGestureAccess/, 'web audio scheme removed');
  assert.doesNotMatch(page, /runJavaScript\(/, 'no injected audio playback script');
});

test('study page wires the full review loop', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /pageDeckId: string = ''/, 'deck id arrives via Navigation param');
  assert.match(page, /this\.pathStack\.pop\(\)/, 'back goes through NavPathStack pop');
  assert.doesNotMatch(page, /router\.(getParams|pushUrl|back)\b/, 'deprecated router must be gone');
  assert.match(page, /ensureOpen\(context\.filesDir\)/);
  assert.match(page, /schedulerService\.getQueuedCards\(this\.deckId\)/);
  assert.match(page, /cardRenderingService\.renderExistingCard\(this\.currentCard\.cardId\)/);
  assert.match(page, /schedulerService\.describeNextStates\(this\.currentCard\.states\)/);
  assert.match(page, /buildCardHtml\(this\.rendered, 'question'\)/);
  assert.match(page, /buildCardHtml\(this\.rendered, 'answer'\)/);
  assert.match(page, /schedulerService\.answerCard\(/);
  assert.match(page, /currentState: states\.current/, 'raw state passthrough on answer');
  assert.match(page, /queued\.cards\.length === 0[\s\S]*?phase = 'done'/, 'empty queue reaches done phase');
  assert.match(page, /this\.answering = true/, 'rating must be reentrancy-guarded');
});

test('study page web component blocks file-protocol cross origin correctly', () => {
  const page = read(STUDY_PAGE);

  assert.match(page, /Web\(\{ src: MEDIA_BASE_URL, controller: this\.webController \}\)/);
  assert.match(page, /\.fileAccess\(true\)/);
  assert.match(page, /\.javaScriptAccess\(true\)/);
  assert.match(page, /\.onInterceptRequest\(/);
  assert.match(page, /loadData\(this\.questionHtml, 'text\/html', 'UTF-8', MEDIA_BASE_URL, ' '\)/);
  assert.match(page, /loadData\(this\.answerHtml, 'text\/html', 'UTF-8', MEDIA_BASE_URL, ' '\)/);
  assert.match(page, /readMediaFile\(this\.mediaDir, fileName\)/);
  assert.match(page, /collection\.media/, 'media dir points at the anki media folder');
});

test('media helper infers mime types and reads sandbox files defensively', () => {
  const helper = read(MEDIA_HELPER);

  assert.match(helper, /export function mimeTypeOf\(fileName: string\): string/);
  assert.match(helper, /'png': 'image\/png'/);
  assert.match(helper, /'mp3': 'audio\/mpeg'/);
  assert.match(helper, /application\/octet-stream/, 'unknown extensions fall back');
  assert.match(helper, /export function readMediaFile\(mediaDir: string, fileName: string\): ArrayBuffer \| null/);
  assert.match(helper, /catch \(error\) \{\s*return null;/, 'read failures degrade to null');
});

test('study page is registered and reachable from home', () => {
  const mainPages = JSON.parse(read(MAIN_PAGES));
  assert.ok(mainPages.src.includes('pages/Index'), 'Index must be registered');
  assert.ok(!mainPages.src.includes('pages/StudyPage'),
    'StudyPage is a NavDestination, not a router page');

  const index = read(INDEX_PAGE);
  assert.match(index, /Navigation\(this\.pathStack\)/);
  assert.match(index, /\.navDestination\(this\.pageMap\)/);
  assert.match(index, /name: 'StudyPage'/);
  assert.match(index, /deckId: this\.selectedDeckId/);
  assert.match(index, /deckName: deckDisplayName\(this\.selectedDeck\(\)\)/,
    'deckName follows UI display name (covers user-customized aliases)');
  assert.match(index, /onPop[\s\S]{0,120}?loadHomeData\(\)/,
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
  assert.match(page, /AppDimens/);
  assert.match(page, /app\.string\.study_show_answer/);
  assert.match(page, /app\.string\.study_finish_title/);
  assert.match(page, /app\.string\.study_load_error/);
});

test('counts for deck today decodes new and review tallies', () => {
  const w = new ProtoWriter();
  w.writeVarint(1, 7);
  w.writeVarint(2, 23);
  const counts = decodeCountsForDeckToday(w.toBytes());
  assert.equal(counts.newCount, 7);
  assert.equal(counts.reviewCount, 23);

  assert.deepEqual(decodeCountsForDeckToday(new Uint8Array(0)), { newCount: 0, reviewCount: 0 });
});

test('scheduler service exposes deck today counts via scheduler method 10', () => {
  const service = read(SCHEDULER);
  assert.match(service, /async countsForDeckToday\(deckId: number\): Promise<DeckTodayCounts>/);
  assert.match(service, /SCHEDULER_METHOD\.COUNTS_FOR_DECK_TODAY/);
  assert.match(service, /encodeDeckId\(deckId\)/);
});

test('home sources completed today from graphs.today.answerCount instead of per-deck RPCs', () => {
  // 旧实现 sumCompletedToday 只迭代顶层牌组调用 countsForDeckToday，既漏子牌组学习、
  // 又缺 learn/relearn 口径；新实现直接用 graphs.today.answerCount（全库聚合、完整口径）。
  const index = read(INDEX_PAGE);
  assert.doesNotMatch(index, /sumCompletedToday/,
    'sumCompletedToday must be removed; today.answerCount replaces it');
  assert.doesNotMatch(index, /schedulerService\.countsForDeckToday/,
    'home must not call countsForDeckToday; graphs.today already aggregates all decks');
  assert.match(index, /buildHomeSnapshot\(tree, graphs/);
});
