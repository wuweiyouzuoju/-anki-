import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('cloud deck hosting has one replaceable catalog URL and no management credential', () => {
  const source = read('../../entry/src/main/ets/model/云端牌组配置.ts');
  assert.match(source, /云端牌组目录地址/);
  assert.match(
    source,
    /export const 云端牌组目录地址: string =\s*\n?\s*'https:\/\/4001784660\.cdn\.123clouddisk\.com\/4001784660\/CET%E5%9B%9B%E5%85%AD%E7%BA%A7\/cloud-decks\.json'/,
  );
  assert.doesNotMatch(source, /(accessKey|secretKey|clientSecret|管理密钥)/i);
});

test('first-launch cloud deck onboarding is persisted independently', () => {
  const source = read('../../entry/src/main/ets/model/云端牌组引导存储.ets');
  assert.match(source, /cloud_deck_onboarding_completed/);
  assert.match(source, /是否已完成云端牌组引导/);
  assert.match(source, /标记已完成云端牌组引导/);
  assert.match(source, /preferences\.getPreferences/);
  assert.match(source, /\.flush\(\)/);
});

test('cloud deck service fetches a small HTTPS catalog through NetworkKit', () => {
  const source = read('../../entry/src/main/ets/backend/云端牌组服务.ets');
  assert.match(source, /from '@kit\.NetworkKit'/);
  assert.match(source, /http\.createHttp\(\)/);
  assert.match(source, /http\.RequestMethod\.GET/);
  assert.match(source, /http\.HttpDataType\.STRING/);
  assert.match(source, /responseCode/);
  assert.match(source, /解析云端牌组目录/);
  assert.match(source, /https:\\\/\\\//);
  assert.match(source, /destroy\(\)/);
});

test('cloud deck service streams APKG files to a sandbox directory with progress and cleanup', () => {
  const source = read('../../entry/src/main/ets/backend/云端牌组服务.ets');
  assert.match(source, /from '@kit\.BasicServicesKit'/);
  assert.match(source, /request\.agent\.create/);
  assert.match(source, /request\.agent\.Action\.DOWNLOAD/);
  assert.match(source, /request\.agent\.Mode\.FOREGROUND/);
  assert.match(source, /cloud-decks/);
  assert.match(source, /saveas:/);
  assert.match(source, /task\.on\('progress'/);
  assert.match(source, /task\.on\('completed'/);
  assert.match(source, /task\.on\('failed'/);
  assert.match(source, /statSync/);
  assert.match(source, /readSync/);
  assert.match(source, /unlinkSync/);
  assert.doesNotMatch(source, /!\/\\\.apkg\(\?:\[\?\#\]\|\$\)\/i\.test\(deck\.downloadUrl\)/);
});

test('cloud deck service cannot strand a download promise when listener cleanup throws', () => {
  const source = read('../../entry/src/main/ets/backend/云端牌组服务.ets');
  assert.match(source, /try\s*\{\s*task\.off\('progress'/);
  assert.match(source, /try\s*\{\s*task\.off\('completed'/);
  assert.match(source, /try\s*\{\s*task\.off\('failed'/);
});

test('cloud deck service settles and cleans up a foreground task when the system pauses it', () => {
  const source = read('../../entry/src/main/ets/backend/云端牌组服务.ets');
  assert.match(source, /task\.on\('pause', pauseCallback\)/);
  assert.match(source, /task\.off\('pause', pauseCallback\)/);
  const pauseBody = source.match(/const pauseCallback\s*=\s*\([^)]*\): void =>\s*\{([\s\S]*?)\n\s*\};/);
  assert.ok(pauseBody, 'pause callback body should exist');
  assert.ok(pauseBody[1].indexOf('fail(') < pauseBody[1].indexOf('removeTask('),
    'the promise must settle before task cleanup can throw');
  assert.doesNotMatch(pauseBody[1], /progressCallback\(/);
  assert.match(source, /const removeTask[\s\S]*try\s*\{[\s\S]*request\.agent\.remove/);
  assert.match(source, /request\.agent\.remove\(task\.tid\)/);
});

test('cloud deck service times out waiting or retrying tasks that make no byte progress', () => {
  const source = read('../../entry/src/main/ets/backend/云端牌组服务.ets');
  assert.match(source, /云端牌组无进度超时毫秒/);
  assert.match(source, /setTimeout\(/);
  assert.match(source, /clearTimeout\(/);
  assert.match(source, /progress\.processed > lastProcessed/);
  assert.match(source, /长时间无下载进度/);
  assert.match(source, /request\.agent\.remove\(task\.tid\)/);
});

test('import source modal offers local and software-cloud choices on the shared frosted surface', () => {
  const source = read('../../entry/src/main/ets/components/导入来源弹窗.ets');
  assert.match(source, /import_source_local_title/);
  assert.match(source, /import_source_cloud_title/);
  assert.match(source, /onLocal/);
  assert.match(source, /onCloud/);
  assert.match(source, /backgroundBlurStyle\(BlurStyle\.Thin/);
  assert.match(source, /surface_card/);
  assert.match(source, /取全屏转场时长/);
});

test('cloud deck modal presents selectable public decks, locked future decks and download progress', () => {
  const source = read('../../entry/src/main/ets/components/云端牌组弹窗.ets');
  assert.match(source, /云端牌组目录项/);
  assert.match(source, /selectedIds/);
  assert.match(source, /accessType === 'public'/);
  assert.match(source, /ToggleType\.Checkbox/);
  assert.match(source, /cloud_deck_locked_badge/);
  assert.match(source, /cloud_deck_loading/);
  assert.match(source, /cloud_deck_empty/);
  assert.match(source, /cloud_deck_retry/);
  assert.match(source, /ProgressType\.Linear/);
  assert.match(source, /onDownload/);
  assert.match(source, /backgroundBlurStyle\(BlurStyle\.Thin/);
});

test('cloud deck and import source strings are aligned and translated', () => {
  const zh = JSON.parse(read('../../entry/src/main/resources/base/element/string.json')).string;
  const en = JSON.parse(read('../../entry/src/main/resources/en_US/element/string.json')).string;
  const zhMap = new Map(zh.map((item) => [item.name, item.value]));
  const enMap = new Map(en.map((item) => [item.name, item.value]));
  const required = [
    'import_source_title', 'import_source_local_title', 'import_source_cloud_title',
    'cloud_deck_title', 'cloud_deck_loading', 'cloud_deck_not_configured',
    'cloud_deck_empty', 'cloud_deck_retry', 'cloud_deck_download',
    'cloud_deck_locked_badge', 'cloud_deck_status_success', 'cloud_deck_status_failed',
  ];
  for (const key of required) {
    assert.ok(zhMap.has(key), `missing base key ${key}`);
    assert.ok(enMap.has(key), `missing en_US key ${key}`);
    assert.doesNotMatch(enMap.get(key), /[\u3400-\u9fff]/, `${key} is not translated`);
  }
  assert.deepEqual([...zhMap.keys()].sort(), [...enMap.keys()].sort());
});

test('home routes Import Deck through source selection and preserves the local picker flow', () => {
  const source = read('../../entry/src/main/ets/pages/首页.ets');
  assert.match(source, /导入来源弹窗/);
  assert.match(source, /显示导入来源弹窗 = true/);
  assert.match(source, /onLocal:[\s\S]*从选择器导入牌组\(\)/);
  assert.match(source, /onCloud:[\s\S]*打开云端牌组弹窗\(false\)/);
  assert.match(source, /选取数据文件\(context, \['\.apkg'\]\)/);
});

test('home sequences cloud onboarding before welcome and persists skip or completion', () => {
  const source = read('../../entry/src/main/ets/pages/首页.ets');
  assert.match(source, /是否已完成云端牌组引导/);
  assert.match(source, /显示首次弹窗序列/);
  assert.match(source, /打开云端牌组弹窗\(true\)/);
  assert.match(source, /标记已完成云端牌组引导/);
  assert.match(source, /显示欢迎弹窗一次\(\)/);
  assert.match(source, /if \(this\.显示云端牌组弹窗\)/);
  assert.match(source, /if \(this\.云端牌组忙碌\) return true/);
});

test('home downloads and imports selected cloud decks sequentially through the existing backend', () => {
  const source = read('../../entry/src/main/ets/pages/首页.ets');
  assert.match(source, /for \(const deck of selectedDecks\)/);
  assert.match(source, /await this\.云端牌组服务实例\.下载牌组/);
  assert.match(source, /await 执行牌组导入\(downloadedPath\)/);
  assert.match(source, /await this\.加载主页数据\(\)/);
  assert.match(source, /展开新导入牌组/);
  assert.match(source, /successIds/);
  assert.match(source, /failedIds/);
});
