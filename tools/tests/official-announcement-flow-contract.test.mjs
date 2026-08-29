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

test('announcement service performs one uncached GET under a hard two-second deadline', () => {
  const source = read('../../entry/src/main/ets/backend/官方公告服务.ets');
  assert.match(source, /from '@kit\.NetworkKit'/);
  assert.match(source, /构建官方公告请求地址/);
  assert.match(source, /http\.RequestMethod\.GET/);
  assert.match(source, /http\.HttpDataType\.STRING/);
  assert.match(source, /usingCache: false/);
  assert.match(source, /connectTimeout: 2000/);
  assert.match(source, /readTimeout: 2000/);
  assert.match(source, /官方公告截止剩余毫秒/);
  assert.match(source, /Promise\.race/);
  assert.match(source, /setTimeout\(/);
  assert.match(source, /clearTimeout\(timerId\);[\s\S]*?client\.destroy\(\);/);
  assert.match(source, /解析可展示官方公告/);
  assert.doesNotMatch(source, /retry|ClientSecret|accessToken/i);
});

test('announcement modal is native, themed, scrollable and non-dismissible', () => {
  const source = read('../../entry/src/main/ets/components/官方公告弹窗.ets');
  assert.match(source, /官方公告展示项/);
  assert.match(source, /announcement\.title/);
  assert.match(source, /announcement\.content/);
  assert.match(source, /official_announcement_published_at/);
  assert.match(source, /official_announcement_acknowledge/);
  assert.match(source, /official_announcement_details/);
  assert.match(source, /onAcknowledge/);
  assert.match(source, /onOpenDetails/);
  assert.match(source, /backgroundBlurStyle\(BlurStyle\.Thin/);
  assert.match(source, /取全屏转场/);
  assert.match(source, /edgeEffect\(EdgeEffect\.Spring\)/);
  assert.doesNotMatch(source, /Web\(|RichText\(|onClose|\.onClick\(\(\) => this\.onAcknowledge/);
});

test('announcement fixed strings are aligned and translated', () => {
  const zh = JSON.parse(read('../../entry/src/main/resources/base/element/string.json')).string;
  const en = JSON.parse(read('../../entry/src/main/resources/en_US/element/string.json')).string;
  const zhMap = new Map(zh.map((item) => [item.name, item.value]));
  const enMap = new Map(en.map((item) => [item.name, item.value]));
  const keys = [
    'official_announcement_published_at',
    'official_announcement_acknowledge',
    'official_announcement_details',
    'official_announcement_open_failed',
    'official_announcement_save_failed',
  ];
  for (const key of keys) {
    assert.ok(zhMap.has(key));
    assert.ok(enMap.has(key));
    assert.doesNotMatch(enMap.get(key), /[\u3400-\u9fff]/);
  }
});

test('home sequences official announcement before cloud onboarding and welcome', () => {
  const source = read('../../entry/src/main/ets/pages/首页.ets');
  assert.match(source, /官方公告服务实例/);
  assert.match(source, /bundleManager\.getBundleInfoForSelf/);
  assert.match(source, /当前语言模式\(\)/);
  assert.match(source, /是否已确认官方公告/);
  assert.match(source, /标记已确认官方公告/);
  const sequence = source.match(/private async 显示首次弹窗序列\(\)[\s\S]*?private async 显示欢迎弹窗一次/)?.[0] ?? '';
  assert.ok(sequence.indexOf('尝试显示官方公告') < sequence.indexOf('是否已完成云端牌组引导'));
  assert.ok(sequence.indexOf('是否已完成云端牌组引导') < sequence.indexOf('显示欢迎弹窗一次'));
  assert.match(source, /if \(this\.显示官方公告\) \{\s*return true;/);
  assert.match(source, /onAcknowledge:[\s\S]*确认官方公告\(\)/);
  assert.match(source, /onOpenDetails:[\s\S]*打开官方公告详情\(\)/);
  assert.doesNotMatch(source, /onPageShow\(\)[\s\S]{0,300}加载公告/);
});

test('home closes and continues even when acknowledgement persistence fails', () => {
  const source = read('../../entry/src/main/ets/pages/首页.ets');
  const method = source.match(/private async 确认官方公告\(\)[\s\S]*?\n  private /)?.[0] ?? '';
  assert.match(method, /await 标记已确认官方公告/);
  assert.match(method, /official_announcement_save_failed/);
  assert.match(method, /this\.显示官方公告 = false/);
  assert.match(method, /await this\.继续首次弹窗序列\(\)/);
});

test('hosted announcement manifest starts disabled and matches schema v1', () => {
  const manifest = JSON.parse(read('../../hosting/announcement.json'));
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.announcement, null);
});
