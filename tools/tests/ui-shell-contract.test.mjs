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
  const page = read('entry/src/main/ets/pages/Index.ets');

  assert.match(page, /value:\s*\['600vp',\s*'840vp'\]/);
  assert.match(page, /reference:\s*BreakpointsReference\.WindowSize/);
  assert.match(page, /@State\s+private\s+currentBreakpoint:\s*string\s*=\s*'xs'/);
  assert.match(page, /^\s*List\(/m);
  assert.doesNotMatch(page, /\bHOME_SNAPSHOT\b/);
  assert.doesNotMatch(page, /阶段 1 · OHOS 可行性验证/);
  assert.doesNotMatch(page, /interface GateStatus|private readonly gates/);
});

test('home model exposes formal empty data without demo decks', () => {
  const modelPath = 'entry/src/main/ets/model/HomeModels.ets';
  assert.equal(existsSync(projectUrl(modelPath)), true, `${modelPath} must exist`);

  const model = read(modelPath);
  assert.match(model, /export interface DeckSummary/);
  assert.match(model, /export interface StudySummary/);
  assert.match(model, /export interface HomeSnapshot/);
  assert.match(model, /export const EMPTY_HOME_SNAPSHOT:\s*HomeSnapshot/);
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
  const page = read('entry/src/main/ets/pages/Index.ets');
  const selectionDeclarations = page.match(/@(?:State|Provide)\s*(?:\([^)]*\)\s*)?(?:private\s+)?selectedDeckId/g) ?? [];

  assert.equal(selectionDeclarations.length, 1);
  assert.match(page, /columns:\s*\{\s*xs:\s*4,\s*sm:\s*8,\s*md:\s*12\s*\}/);
  assert.match(page, /span:\s*\{\s*xs:\s*4,\s*sm:\s*5,\s*md:\s*8\s*\}/);
  assert.match(page, /currentBreakpoint\s*===\s*'xs'/);
  assert.doesNotMatch(page, /setInterval|setTimeout|blur\(|backdropBlur|linearGradient/);
});

test('large deck lists create rows lazily', () => {
  const page = read('entry/src/main/ets/pages/Index.ets');
  const model = read('entry/src/main/ets/model/HomeModels.ets');

  assert.match(model, /export class DeckDataSource implements IDataSource/);
  assert.match(page, /LazyForEach\(this\.deckDataSource/);
  assert.doesNotMatch(page, /\bHOME_SNAPSHOT\b|ForEach\([^)]*\.decks/);
});

test('unavailable actions cannot fail the home shell when toast is unavailable', () => {
  const page = read('entry/src/main/ets/pages/Index.ets');
  const noticeMethod = page.match(/private showNotice\([\s\S]*?\): void \{[\s\S]*?\n  \}/);

  assert.notEqual(noticeMethod, null);
  assert.match(noticeMethod[0], /try\s*\{/);
  assert.match(noticeMethod[0], /catch\s*\(/);
  assert.match(page, /private showUnavailableNotice\(\): void \{\s*this\.showNotice\(/);
});

test('home error state offers an in-place retry path', () => {
  const page = read('entry/src/main/ets/pages/Index.ets');
  const strings = readJson('entry/src/main/resources/base/element/string.json').string;
  const stringNames = new Set(strings.map((item) => item.name));

  assert.equal(stringNames.has('home_retry'), true, 'missing string resource: home_retry');
  const errorBlock = page.match(/if \(this\.loadState === 'error'\) \{[\s\S]*?\n        \}/);
  assert.notEqual(errorBlock, null);
  assert.match(errorBlock[0], /app\.string\.home_retry/);
  assert.match(errorBlock[0], /this\.loadHomeData\(\)/);
});

test('revised home uses a full-window toolbar without greeting or bottom navigation', () => {
  const page = read('entry/src/main/ets/pages/Index.ets');

  assert.doesNotMatch(page, /app\.string\.home_title|app\.string\.home_subtitle/);
  assert.doesNotMatch(page, /bottomNavigation|bottomNavItem|sidePane|sideNavItem/);
  assert.match(page, /app\.string\.top_settings/);
  assert.match(page, /app\.string\.create_deck/);
  assert.match(page, /span:\s*\{\s*xs:\s*4,\s*sm:\s*5,\s*md:\s*8\s*\}/);
  assert.match(page, /span:\s*\{\s*xs:\s*0,\s*sm:\s*3,\s*md:\s*4\s*\}/);
  assert.match(page, /if\s*\(this\.currentBreakpoint !== 'xs'\)\s*\{\s*GridCol/);
  assert.match(page,
    /\.expandSafeArea\(\[SafeAreaType\.SYSTEM\],\s*\[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/);
});

test('summary pager hosts two manually navigated cards without auto-looping', () => {
  const page = read('entry/src/main/ets/pages/Index.ets');

  assert.match(page, /Swiper\(\)/);
  assert.match(page, /\.autoPlay\(false\)/);
  // loop=false：2 张卡不需要首末循环；旧 loop=true 在边界依赖 cachedCount，
  // 未设时首末衔接可能短暂白屏（HarmonyOS Swiper 官方文档明确）。
  assert.match(page, /\.loop\(false\)/);
  for (const component of ['TodaySummaryCard', 'MonthCalendarCard']) {
    const componentPath = `entry/src/main/ets/components/${component}.ets`;
    assert.equal(existsSync(projectUrl(componentPath)), true, `${componentPath} must exist`);
    assert.match(page, new RegExp(`${component}\\(\\{`));
  }
  assert.match(page, /buildMonthCalendar/);
  assert.doesNotMatch(page, /streakDays/);
});

test('home UI uses shared dimension tokens instead of magic numbers', () => {
  const dimensPath = 'entry/src/main/ets/utils/AppDimens.ets';
  assert.equal(existsSync(projectUrl(dimensPath)), true, `${dimensPath} must exist`);

  const dimens = read(dimensPath);
  assert.match(dimens, /export class AppDimens/);

  const files = [
    'entry/src/main/ets/pages/Index.ets',
    'entry/src/main/ets/components/TodaySummaryCard.ets',
    'entry/src/main/ets/components/MonthCalendarCard.ets',
    'entry/src/main/ets/components/DeckListItem.ets',
    'entry/src/main/ets/components/DeckDetailPane.ets',
    'entry/src/main/ets/components/StartStudyButton.ets',
    'entry/src/main/ets/components/LicensesPanel.ets'
  ];
  for (const file of files) {
    assert.equal(existsSync(projectUrl(file)), true, `${file} must exist`);
    const source = read(file);
    assert.match(source, /AppDimens/, `${file} must use AppDimens`);
    assert.doesNotMatch(source, /\.fontSize\(\d/, `${file} must not hardcode fontSize`);
    assert.doesNotMatch(source, /\.borderRadius\(\d/, `${file} must not hardcode borderRadius`);
  }
});

test('theme settings persist three modes and synchronize system bars', () => {
  const settingsPath = 'entry/src/main/ets/model/ThemeSettings.ets';
  const storePath = 'entry/src/main/ets/model/ThemeStore.ets';
  const controllerPath = 'entry/src/main/ets/utils/ThemeController.ets';
  const panelPath = 'entry/src/main/ets/components/SettingsPanel.ets';

  for (const path of [settingsPath, storePath, controllerPath, panelPath]) {
    assert.equal(existsSync(projectUrl(path)), true, `${path} must exist`);
  }

  const settings = read(settingsPath);
  const store = read(storePath);
  const controller = read(controllerPath);
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
  const page = read('entry/src/main/ets/pages/Index.ets');
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
  assert.match(page, /AppStorage\.setOrCreate<ThemeMode>\('themeMode'/);
  assert.match(ability, /AppStorage\.get<string>\('themeMode'\)/);
  assert.match(ability, /applySystemBars\(this\.context, isDark\)/);
});

test('Schulte-style settings keep the approved modal architecture and about content', () => {
  const panelPath = 'entry/src/main/ets/components/SettingsPanel.ets';
  assert.equal(existsSync(projectUrl(panelPath)), true, `${panelPath} must exist`);

  const panel = read(panelPath);
  assert.match(panel, /Stack\(\)/);
  assert.match(panel, /backgroundColor\(this\.maskColor\(\)\)/);
  assert.match(panel, /List\(\{ space: 12 \}\)/);
  assert.match(panel, /width\('88%'\)/);
  assert.match(panel, /constraintSize\(\{ maxWidth: 480 \}\)/);
  assert.match(panel, /groupAppearanceOpen/);
  assert.match(panel, /groupDataOpen/);
  assert.match(panel, /groupDatabaseOpen/);
  assert.match(panel, /groupAboutOpen/);
  assert.match(panel, /app\.string\.feedback_email/);
  assert.match(panel, /app\.media\.sponsor_qrcode/);
  assert.match(panel, /ThemeMode/);
});

test('jidecards synchronizes system bars after content loads', () => {
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets');
  const loadCallback = ability.match(/loadContent\('pages\/Index',[\s\S]*?\n    \}\);/)?.[0] ?? '';

  assert.match(loadCallback, /applySystemBars/);
});

test('calendar model builds a 5-or-6-week heat map based on actual month layout', () => {
  const calendarPath = 'entry/src/main/ets/model/CalendarModels.ets';
  assert.equal(existsSync(projectUrl(calendarPath)), true, `${calendarPath} must exist`);

  const calendar = read(calendarPath);
  assert.match(calendar, /export interface CalendarDay/);
  assert.match(calendar, /export interface MonthCalendar/);
  // 旧实现固定 42 格（6 行），某些月份多空行 + 卡片高度溢出；改为动态 5/6 行：
  // CALENDAR_MAX_WEEKS=6 上限、CALENDAR_COLUMNS=7 每行 7 格；weekCount 由 leading+days 决定。
  assert.match(calendar, /const CALENDAR_MAX_WEEKS:\s*number\s*=\s*6/);
  assert.match(calendar, /const CALENDAR_COLUMNS:\s*number\s*=\s*7/);
  assert.match(calendar, /weekCount:\s*number/);
  assert.match(calendar, /Math\.ceil\(totalCells \/ CALENDAR_COLUMNS\)/);
  assert.match(calendar,
    /export function buildMonthCalendar\(now: Date, reviewCountsByDate: Map<string, number>\): MonthCalendar/);
  assert.match(calendar, /intensity:/);
  assert.doesNotMatch(calendar, /demoIntensity|Math\.random/);
});
