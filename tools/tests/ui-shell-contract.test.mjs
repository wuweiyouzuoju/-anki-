import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

test('home shell keeps adaptive breakpoints and a virtualized deck list', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const deckList = read('entry/src/main/ets/components/home/主页牌组列表.ets');

  assert.match(page, /value:\s*\['600vp',\s*'840vp'\]/);
  assert.match(page, /reference:\s*BreakpointsReference\.WindowSize/);
  assert.match(page, /@State\s+private\s+当前断点:\s*string\s*=\s*'xs'/);
  assert.match(deckList, /^\s*List\(/m);
  assert.doesNotMatch(page, /\bHOME_SNAPSHOT\b/);
  assert.doesNotMatch(page, /阶段 1 · OHOS 可行性验证/);
  assert.doesNotMatch(page, /interface GateStatus|private readonly gates/);
});

test('home model exposes formal empty data without demo decks', () => {
  const modelPath = 'entry/src/main/ets/model/主页模型.ets';
  assert.equal(existsSync(projectUrl(modelPath)), true, `${modelPath} must exist`);

  const model = read(modelPath);
  assert.match(model, /export interface 牌组汇总/);
  assert.match(model, /export interface 今日学习汇总/);
  assert.match(model, /export interface 主页快照/);
  assert.match(model, /export const 空主页快照:\s*主页快照/);
  assert.doesNotMatch(model, /每日英语|计算机基础|古诗文|通识随记/);
  assert.doesNotMatch(model, /streakDays/);
  assert.doesNotMatch(model, /\bany\b|\bvar\b/);
});

test('home resources provide matching light and dark semantic colors', () => {
  const strings = readJson('entry/src/main/resources/base/element/string.json').string;
  const lightColors = readJson('entry/src/main/resources/base/element/color.json').color;
  const darkColors = readJson('entry/src/main/resources/dark/element/color.json').color;
  const stringNames = new Set(strings.map((item) => item.name));
  const lightNames = new Set(lightColors.map((item) => item.name));
  const darkNames = new Set(darkColors.map((item) => item.name));

  for (const name of ['home_title', 'start_study', 'nav_decks', 'nav_browse', 'nav_stats', 'nav_settings']) {
    assert.equal(stringNames.has(name), true, `missing string resource: ${name}`);
  }

  for (const name of ['surface_page', 'surface_card', 'text_primary', 'text_secondary', 'action_primary', 'border_subtle']) {
    assert.equal(lightNames.has(name), true, `missing light color resource: ${name}`);
    assert.equal(darkNames.has(name), true, `missing dark color resource: ${name}`);
  }
});

test('tablet shell shares one selection state and avoids high-cost visual effects', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const selectionDeclarations = page.match(/@(?:State|Provide|StorageLink)\s*(?:\([^)]*\)\s*)?(?:private\s+)?选中的牌组ID/g) ?? [];

  assert.equal(selectionDeclarations.length, 1);
  assert.match(page, /columns:\s*\{\s*xs:\s*4,\s*sm:\s*8,\s*md:\s*12\s*\}/);
  assert.match(page, /span:\s*\{\s*xs:\s*4,\s*sm:\s*5,\s*md:\s*8\s*\}/);
  assert.match(page, /当前断点\s*===\s*'xs'/);
  assert.doesNotMatch(page, /setInterval|setTimeout|blur\(|backdropBlur|linearGradient/);
});

test('large deck lists create rows lazily', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const deckList = read('entry/src/main/ets/components/home/主页牌组列表.ets');
  const model = read('entry/src/main/ets/model/主页模型.ets');

  assert.match(model, /export class 牌组列表数据源 implements IDataSource/);
  assert.match(deckList, /LazyForEach\(this\.牌组数据源/);
  assert.doesNotMatch(page, /\bHOME_SNAPSHOT\b|ForEach\([^)]*\.decks/);
});

test('unavailable actions cannot fail the home shell when toast is unavailable', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const noticeMethod = page.match(/private 显示提示\([\s\S]*?\): void \{[\s\S]*?\n  \}/);

  assert.notEqual(noticeMethod, null);
  assert.match(noticeMethod[0], /try\s*\{/);
  assert.match(noticeMethod[0], /catch\s*\(/);
  const callMatches = page.match(/this\.显示提示\(/g) || [];
  assert.ok(callMatches.length >= 2, '显示提示 should be called from at least one caller besides its declaration');
});

test('home error state offers an in-place retry path', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const deckList = read('entry/src/main/ets/components/home/主页牌组列表.ets');
  const strings = readJson('entry/src/main/resources/base/element/string.json').string;
  const stringNames = new Set(strings.map((item) => item.name));

  assert.equal(stringNames.has('home_retry'), true, 'missing string resource: home_retry');
  assert.match(deckList, /if \(this\.加载状态 === 'error'\)/);
  assert.match(deckList, /app\.string\.home_retry/);
  assert.match(page, /onRetry: \(\): void => \{\s*this\.加载主页数据\(\);?\s*\}/);
});

test('revised home uses a full-window toolbar without greeting or bottom navigation', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const toolbar = read('entry/src/main/ets/components/home/主页顶部工具栏.ets');

  assert.doesNotMatch(page, /app\.string\.home_title|app\.string\.home_subtitle/);
  assert.doesNotMatch(page, /bottomNavigation|bottomNavItem|sidePane|sideNavItem/);
  assert.match(toolbar, /app\.string\.top_settings/);
  assert.match(toolbar, /app\.string\.create_deck/);
  assert.match(page, /span:\s*\{\s*xs:\s*4,\s*sm:\s*5,\s*md:\s*8\s*\}/);
  assert.match(page, /span:\s*\{\s*xs:\s*0,\s*sm:\s*3,\s*md:\s*4\s*\}/);
  assert.match(page, /if\s*\(this\.当前断点 !== 'xs'\)\s*\{\s*GridCol/);
  assert.match(page,
    /\.expandSafeArea\(\[SafeAreaType\.SYSTEM\],\s*\[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/);
});

test('summary pager hosts two manually navigated cards without auto-looping', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const summary = read('entry/src/main/ets/components/home/主页摘要分页.ets');

  assert.match(summary, /Swiper\(\)/);
  assert.match(summary, /\.autoPlay\(false\)/);
  assert.match(summary, /\.loop\(false\)/);
  for (const component of ['今日摘要卡', '月历卡']) {
    const componentPath = `entry/src/main/ets/components/${component}.ets`;
    assert.equal(existsSync(projectUrl(componentPath)), true, `${componentPath} must exist`);
    assert.match(summary, new RegExp(`${component}\\(\\{`));
  }
  assert.match(page, /构建月历/);
  assert.doesNotMatch(page, /streakDays/);
});

test('home UI uses shared dimension tokens instead of magic numbers', () => {
  const dimensPath = 'entry/src/main/ets/utils/应用尺寸.ets';
  assert.equal(existsSync(projectUrl(dimensPath)), true, `${dimensPath} must exist`);

  const dimens = read(dimensPath);
  assert.match(dimens, /export class 应用尺寸/);

  const files = [
    'entry/src/main/ets/pages/首页.ets',
    'entry/src/main/ets/components/今日摘要卡.ets',
    'entry/src/main/ets/components/月历卡.ets',
    'entry/src/main/ets/components/牌组列表项.ets',
    'entry/src/main/ets/components/牌组详情面板.ets',
    'entry/src/main/ets/components/开始学习按钮.ets',
    'entry/src/main/ets/components/许可证面板.ets'
  ];
  for (const file of files) {
    assert.equal(existsSync(projectUrl(file)), true, `${file} must exist`);
    const source = read(file);
    assert.match(source, /应用尺寸/, `${file} must use 应用尺寸`);
    assert.doesNotMatch(source, /\.fontSize\(\d/, `${file} must not hardcode fontSize`);
    assert.doesNotMatch(source, /\.borderRadius\(\d/, `${file} must not hardcode borderRadius`);
  }
});

test('theme settings persist three modes and synchronize system bars', () => {
  const settingsPath = 'entry/src/main/ets/model/主题设置.ets';
  const storePath = 'entry/src/main/ets/model/主题存储.ets';
  const controllerPath = 'entry/src/main/ets/utils/主题控制器.ets';
  const panelPath = 'entry/src/main/ets/components/设置面板.ets';

  for (const path of [settingsPath, storePath, controllerPath, panelPath]) {
    assert.equal(existsSync(projectUrl(path)), true, `${path} must exist`);
  }

  const settings = read(settingsPath);
  const store = read(storePath);
  const controller = read(controllerPath);
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
  const page = read('entry/src/main/ets/pages/首页.ets');
  assert.match(settings, /'system'\s*\|\s*'light'\s*\|\s*'dark'/);
  assert.match(store, /preferences\.getPreferences/);
  assert.match(controller, /setColorMode/);
  assert.match(controller, /setWindowSystemBarProperties/);
  assert.match(controller, /statusBarColor/);
  assert.match(controller, /navigationBarColor/);
  assert.match(controller, /isStatusBarLightIcon/);
  assert.match(controller, /isNavigationBarLightIcon/);
  assert.match(ability, /systemDarkMode/);
  assert.match(ability, /abilityContext/);
  assert.match(page, /AppStorage\.setOrCreate<主题模式>\('themeMode'/);
  assert.match(ability, /AppStorage\.get<string>\('themeMode'\)/);
  assert.match(ability, /应用系统栏样式\(this\.context, isDark\)/);
});

test('Schulte-style settings keep the approved modal architecture and about content', () => {
  const panelPath = 'entry/src/main/ets/components/设置面板.ets';
  assert.equal(existsSync(projectUrl(panelPath)), true, `${panelPath} must exist`);

  const panel = read(panelPath);
  assert.match(panel, /Stack\(\)/);
  assert.match(panel, /backgroundColor\(this\.遮罩色\(\)\)/);
  assert.match(panel, /List\(\{ space: 12 \}\)/);
  assert.match(panel, /width\('88%'\)/);
  assert.match(panel, /constraintSize\(\{ maxWidth: 480 \}\)/);
  assert.match(panel, /外观分组展开/);
  assert.match(panel, /数据分组展开/);
  assert.match(panel, /数据库分组展开/);
  assert.match(panel, /关于分组展开/);
  assert.match(panel, /app\.string\.feedback_email/);
  assert.match(panel, /app\.media\.sponsor_qrcode/);
  assert.match(panel, /主题模式/);
});

test('jidecards synchronizes system bars after content loads', () => {
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
  const loadCallback = ability.match(/loadContent\('pages\/首页',[\s\S]*?\n    \}\);/)?.[0] ?? '';

  assert.match(loadCallback, /应用系统栏样式/);
});

test('calendar model builds a 5-or-6-week heat map based on actual month layout', () => {
  const calendarPath = 'entry/src/main/ets/model/日历模型.ets';
  assert.equal(existsSync(projectUrl(calendarPath)), true, `${calendarPath} must exist`);

  const calendar = read(calendarPath);
  assert.match(calendar, /export interface 日历单日/);
  assert.match(calendar, /export interface 月历数据/);
  assert.match(calendar, /const 月历最大周数:\s*number\s*=\s*6/);
  assert.match(calendar, /const 日历列数:\s*number\s*=\s*7/);
  assert.match(calendar, /周数:\s*number/);
  assert.match(calendar, /Math\.ceil\(总格数 \/ 日历列数\)/);
  assert.match(calendar,
    /export function 构建月历\(当前时间: Date, 按日期复习次数: Map<string, number>\): 月历数据/);
  assert.match(calendar, /热力强度:/);
  assert.doesNotMatch(calendar, /demoIntensity|Math\.random/);
});
