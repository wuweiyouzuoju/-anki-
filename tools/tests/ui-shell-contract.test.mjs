// SPDX-License-Identifier: AGPL-3.0-or-later

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
  // List 现在挂在 主页牌组列表 积木组件里
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
  // LazyForEach 现在挂在 主页牌组列表 积木组件里
  assert.match(deckList, /LazyForEach\(this\.牌组数据源/);
  assert.doesNotMatch(page, /\bHOME_SNAPSHOT\b|ForEach\([^)]*\.decks/);
});

test('unavailable actions cannot fail the home shell when toast is unavailable', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const noticeMethod = page.match(/private 显示提示\([\s\S]*?\): void \{[\s\S]*?\n  \}/);

  assert.notEqual(noticeMethod, null);
  assert.match(noticeMethod[0], /try\s*\{/);
  assert.match(noticeMethod[0], /catch\s*\(/);
  // 显示提示 必须有至少一个调用点（除声明行外）
  // 2026-07-28 清理死代码：删除了未被任何地方调用的 private 显示不可用提示() 方法，
  // 改为验证 显示提示 有多个真实业务调用点（home_load_error / create_deck_done / transfer_done 等）。
  const callMatches = page.match(/this\.显示提示\(/g) || [];
  assert.ok(callMatches.length >= 2, '显示提示 should be called from at least one caller besides its declaration');
});

test('home error state offers an in-place retry path', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const deckList = read('entry/src/main/ets/components/home/主页牌组列表.ets');
  const strings = readJson('entry/src/main/resources/base/element/string.json').string;
  const stringNames = new Set(strings.map((item) => item.name));

  assert.equal(stringNames.has('home_retry'), true, 'missing string resource: home_retry');
  // error 块挂在 主页牌组列表 积木组件里，文案用 app.string.home_retry
  assert.match(deckList, /if \(this\.加载状态 === 'error'\)/);
  assert.match(deckList, /app\.string\.home_retry/);
  // 首页.ets 把 onRetry 回调绑到 加载主页数据，确保重试触发数据重拉
  assert.match(page, /onRetry: \(\): void => \{\s*this\.加载主页数据\(\);?\s*\}/);
});

test('revised home uses a full-window toolbar without greeting or bottom navigation', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const toolbar = read('entry/src/main/ets/components/home/主页顶部工具栏.ets');

  assert.doesNotMatch(page, /app\.string\.home_title|app\.string\.home_subtitle/);
  assert.doesNotMatch(page, /bottomNavigation|bottomNavItem|sidePane|sideNavItem/);
  // 顶部工具栏按钮文案移至 主页顶部工具栏 积木组件
  // 2026-07-20 后：原设置/浏览/统计 3 按钮合并为「更多」按钮（study_more），右侧保留「创建牌组」
  assert.match(toolbar, /app\.string\.study_more/);
  assert.match(toolbar, /app\.string\.create_deck/);
  assert.match(page, /span:\s*\{\s*xs:\s*4,\s*sm:\s*5,\s*md:\s*8\s*\}/);
  assert.match(page, /span:\s*\{\s*xs:\s*0,\s*sm:\s*3,\s*md:\s*4\s*\}/);
  assert.match(page, /if\s*\(this\.当前断点 !== 'xs'\)\s*\{\s*GridCol/);
  assert.match(page,
    /\.expandSafeArea\(\[SafeAreaType\.SYSTEM\],\s*\[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/);
});

test('summary pager hosts Swiper 8 pages with today progress and stats', () => {
  const page = read('entry/src/main/ets/pages/首页.ets');
  const summary = read('entry/src/main/ets/components/home/主页摘要分页.ets');

  // 主页摘要分页 改成 Swiper 8 页（用户决策 2026-08-15）：今日进度 + 7 统计页
  assert.match(summary, /今日摘要卡\(\{/);
  assert.match(summary, /Swiper\(\)/);
  assert.match(summary, /今日进度页/);
  assert.match(summary, /记忆率页/);
  assert.match(summary, /今日计数页/);
  assert.match(summary, /卡片状态页/);
  assert.match(summary, /小时分布页/);
  assert.match(summary, /难度分布页/);
  assert.match(summary, /间隔分布页/);
  assert.match(summary, /未来到期页/);
  assert.doesNotMatch(summary, /月历卡/);
  // 折叠功能已取消：今日摘要卡 不再接收 已折叠 / 切换展开回调
  assert.doesNotMatch(summary, /已折叠/);
  assert.doesNotMatch(summary, /切换展开回调/);
  assert.doesNotMatch(summary, /摘要折叠/);
  assert.doesNotMatch(summary, /onToggleExpand/);
  // 首页 不再保留 摘要折叠 @State、恢复摘要展开状态 方法、保存摘要展开状态 调用
  assert.doesNotMatch(page, /摘要折叠/);
  assert.doesNotMatch(page, /恢复摘要展开状态/);
  assert.doesNotMatch(page, /保存摘要展开状态/);
  assert.doesNotMatch(page, /加载摘要展开状态/);
  assert.doesNotMatch(page, /streakDays/);
});

test('hour histogram range is shared by stats page, home card and widget', () => {
  const stats = read('entry/src/main/ets/pages/统计页.ets');
  const store = read('entry/src/main/ets/model/桌面卡片数据存储.ets');
  const summary = read('entry/src/main/ets/components/home/主页摘要分页.ets');
  const widget = read('entry/src/main/ets/widget/pages/统计卡片.ets');
  const card = read('entry/src/main/ets/components/stats/小时分布卡.ets');

  // 偏好持久化：统计页切换档位保存，三处提取/渲染前加载同一偏好
  assert.match(store, /export async function 加载小时分布窗口/);
  assert.match(store, /export async function 保存小时分布窗口/);
  assert.match(store, /stats_hours_range/);
  assert.match(stats, /保存小时分布窗口\(索引\)/);
  assert.match(stats, /加载小时分布窗口\(\)/);
  // 提取按窗口取对应时间段（0=1月 1=3月 2=1年 3=全部）
  assert.match(store, /小时窗口 === 1 \? 小时源\.threeMonths/);
  assert.match(store, /小时分布窗口: 小时窗口/);
  // 统计页切换后立即推送卡片快照
  assert.match(stats, /刷新卡片快照\(\)/);
  // 首页/FSRS 控制器提取时加载窗口偏好
  const home = read('entry/src/main/ets/pages/首页.ets');
  const fsrs = read('entry/src/main/ets/model/FSRS控制器.ets');
  assert.match(home, /提取卡片数据\(graphs, 总待学, 牌组总数, await 加载小时分布窗口\(\)\)/);
  assert.match(fsrs, /提取卡片数据\(graphs, 总待学, 牌组总数, await 加载小时分布窗口\(\)\)/);
  // 两处卡片标题跟随窗口（不再固定"全部"）
  assert.doesNotMatch(summary, /小时分布（全部）'\)/);
  assert.doesNotMatch(widget, /小时分布（全部）'\)/);
  assert.match(summary, /小时分布窗口标签\(\)/);
  assert.match(widget, /小时分布窗口标签\(\)/);
  // 小时分布卡档位选择由统计页 @Link 管理 + 切换回调
  assert.match(card, /@Link 时间段索引: number/);
  assert.match(card, /onRangeChange/);
  // 桌面卡片：刻度数字独立成行（0/6/12/18/23），禁止与柱子同列混排（会遮挡柱子且顶高柱区）
  assert.doesNotMatch(widget, /索引 % 3 === 0/);
  // 三处小时刻度统一五等分居中：数字中心间距严格相等（贴边 Start/End 会让首尾段偏窄）
  for (const 标签 of ['0', '6', '12', '18', '23']) {
    assert.match(widget, new RegExp(`Text\\('${标签}'\\)[\\s\\S]{0,120}layoutWeight\\(1\\)[\\s\\S]{0,40}TextAlign\\.Center`));
    assert.match(card, new RegExp(`Text\\('${标签}'\\)[\\s\\S]{0,120}layoutWeight\\(1\\)[\\s\\S]{0,40}TextAlign\\.Center`));
    assert.match(summary, new RegExp(`Text\\('${标签}'\\)[\\s\\S]{0,120}layoutWeight\\(1\\)[\\s\\S]{0,40}TextAlign\\.Center`));
  }
  assert.doesNotMatch(widget, /layoutWeight\(3\)/);
  assert.doesNotMatch(card, /layoutWeight\(3\)/);
  assert.doesNotMatch(summary, /layoutWeight\(3\)/);
});

test('difficulty percent values are used as-is, never divided by 10', () => {
  // 后端 eases.rs：SM-2 键 = ease_factor/10、平均 = median/10；FSRS 键 = percent_to_bin(D×100)、平均 = median×100
  // —— 两种模式的键与平均都已是百分比，前端直接显示，不得再 /10
  const stats = read('entry/src/main/ets/components/stats/难度分布卡.ets');
  const widget = read('entry/src/main/ets/widget/pages/统计卡片.ets');
  const home = read('entry/src/main/ets/components/home/主页摘要分页.ets');
  for (const [名称, 源] of [['统计页', stats], ['桌面卡片', widget], ['首页摘要', home]]) {
    assert.doesNotMatch(源, /平均[\s\S]{0,80}\/\s*10/, `${名称}难度平均值不得再除以 10`);
  }
  assert.doesNotMatch(stats, /键\s*\/\s*10/, '难度桶标签直接用后端百分比键');
  // % 由参数携带，资源模式尾部不得再挂 %（曾致双 %% 显示）
  const strings = read('entry/src/main/resources/base/element/string.json');
  const enStrings = read('entry/src/main/resources/en_US/element/string.json');
  assert.doesNotMatch(strings, /stats_ease_average[^}]*%s%/);
  assert.doesNotMatch(enStrings, /stats_ease_average[^}]*%s%/);
});

test('graphs request days must be 365 everywhere, never derived from current date', () => {
  // 后端 hours 四档（近1月/3月/1年/全部）都从 days 限定的 revlog 里统计，
  // 首页/FSRS控制器曾误传 new Date().getDate()（今天是几号），导致
  // 首页摘要与桌面卡片的小时分布和统计页（365）完全不一致。
  const home = read('entry/src/main/ets/pages/首页.ets');
  const fsrs = read('entry/src/main/ets/model/FSRS控制器.ets');
  const stats = read('entry/src/main/ets/pages/统计页.ets');
  assert.match(home, /获取图表统计\(365\)/, '首页静默加载图表必须传 365');
  assert.match(fsrs, /获取图表统计\(365\)/, 'FSRS控制器刷新桌面卡片必须传 365');
  for (const [名称, 源] of [['首页', home], ['FSRS控制器', fsrs], ['统计页', stats]]) {
    assert.doesNotMatch(源, /获取图表统计\(new Date\(\)/, `${名称}禁止用日期函数派生统计天数`);
  }
});

test('widget payload stays under the 2KB form transfer limit', () => {
  // FormBindingData 跨进程传输上限约 2KB：难度桶（SM-2 键域 130~390 可上百桶）与
  // 间隔桶不截断时 JSON 超限，updateForm 静默失败，桌面卡片冻结在旧数据。
  const store = read('entry/src/main/ets/model/桌面卡片数据存储.ets');
  assert.match(store, /聚合分布桶\(难度桶数组, 20\)/, '难度桶必须聚合分箱到 ≤20 桶');
  assert.match(store, /间隔桶数组\.slice\(0, 20\)/, '间隔分布必须截断到 ≤20 桶');
  assert.match(store, /聚合分布桶[\s\S]*?桶宽/, '聚合分布桶函数必须存在且等宽分箱');
});

test('widget push falls back to running form infos when formId file is empty', () => {
  // 旧版本添加的卡片从未注册过 formId，主进程主动推送会静默跳过；
  // formId 列表为空时必须用 getPublishedRunningFormInfos 兜底（FormInfo 无 formId
  // 字段，只有 RunningFormInfo 有）并写回文件自愈。
  const store = read('entry/src/main/ets/model/桌面卡片数据存储.ets');
  assert.match(store, /ids\.length === 0[\s\S]{0,200}从系统拉取formId/, '推送前 formId 为空必须走系统兜底');
  assert.match(store, /getPublishedRunningFormInfos\(\)/, '兜底必须调用 getPublishedRunningFormInfos');
  assert.match(store, /覆盖写formId文件/, '兜底结果必须写回 formId 文件自愈');
});

test('interval graph always shows intervals; stability is a separate FSRS-only graph', () => {
  // 对齐 Anki 官方（桌面/AnkiDroid 同源 rslib）：Review Intervals 与 FSRS 无关，
  // 始终显示卡片实际间隔；Card Stability 是独立图，仅 FSRS 启用时显示。
  // 曾错误地把 stability 混入间隔分布卡（FSRS 时替换 intervals），导致统计页与卡片口径混乱。
  const interval = read('entry/src/main/ets/components/stats/间隔分布卡.ets');
  const statsPage = read('entry/src/main/ets/pages/统计页.ets');
  const store = read('entry/src/main/ets/model/桌面卡片数据存储.ets');
  assert.doesNotMatch(interval, /FSRS稳定度|是否FSRS/, '间隔分布卡不得含 FSRS 分支');
  assert.match(statsPage, /间隔分布卡\(\{[^}]*间隔数据/, '统计页间隔分布卡只接 intervals');
  assert.match(statsPage, /图表数据\.fsrs[^)]*稳定度分布卡|稳定度分布卡/, '统计页须有独立稳定度分布卡');
  assert.match(statsPage, /图表数据 !== null && this\.图表数据\.fsrs\)/, '稳定度卡仅在 FSRS 启用时渲染');
  assert.match(store, /间隔源: Intervals \| null = 图表数据\.intervals/, '卡片快照间隔分布只用 intervals');
});

test('forecast shows a full month of thin bars in stats page, home card and widget', () => {
  const store = read('entry/src/main/ets/model/桌面卡片数据存储.ets');
  const summary = read('entry/src/main/ets/components/home/主页摘要分页.ets');
  const widget = read('entry/src/main/ets/widget/pages/统计卡片.ets');
  const card = read('entry/src/main/ets/components/stats/预测卡.ets');

  // 数据层提取整月 30 天（0~29），缺失天补 0
  assert.match(store, /天偏移 >= 0 && 天偏移 <= 29/);
  assert.match(store, /for \(let i: number = 0; i <= 29; i\+\+\)/);
  // 桌面卡片与首页摘要：整月细条 + 今/+15/+29 刻度行（独立成行，不与柱子混排）
  // 标题与统计页统一为 Anki 官方名称（Future Due → 未来到期预测）
  assert.match(widget, /未来到期预测/);
  assert.match(summary, /未来到期预测/);
  assert.match(widget, /Text\(.*'今'.*\)[\s\S]{0,200}TextAlign\.Start/);
  assert.match(widget, /Text\('\+29'\)[\s\S]{0,200}TextAlign\.End/);
  // 首页摘要卡已本地化：今 → this.t('今', 'Today')，+29 仍为字面量
  assert.match(summary, /Text\(this\.t\('今',\s*'Today'\)\)/);
  assert.match(summary, /Text\('\+29'\)/);
  // 统计页预测卡：范围切换 + 绿色渐变（对齐 Anki FutureDue），图内积压复选框
  assert.doesNotMatch(card, /PanGesture|偏移X|柱子宽度/);
  assert.match(card, /范围索引: number = 0/);
  assert.match(card, /取预测柱色/);
  assert.match(card, /on积压变更/);
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

test('Schulte-style settings keep the approved full-screen page architecture and about content', () => {
  // 2026-08-15：设置页从模态弹窗改为全屏独立页面，移除遮罩色背景、88% 宽度与 maxWidth:480 模态约束。
  // 顶部条改用页面底色背景 + 状态栏高度 padding，模态遮罩色() 辅助方法保留供其他场景调用。
  const panelPath = 'entry/src/main/ets/components/设置面板.ets';
  assert.equal(existsSync(projectUrl(panelPath)), true, `${panelPath} must exist`);

  const panel = read(panelPath);
  assert.match(panel, /Stack\(\)/);
  assert.match(panel, /List\(\{ space: 12 \}\)/);
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
  // 旧实现固定 42 格（6 行），某些月份多空行 + 卡片高度溢出；改为动态 5/6 行：
  // 月历最大周数=6 上限、日历列数=7 每行 7 格；周数 由 leading+days 决定。
  assert.match(calendar, /const 月历最大周数:\s*number\s*=\s*6/);
  assert.match(calendar, /const 日历列数:\s*number\s*=\s*7/);
  assert.match(calendar, /周数:\s*number/);
  assert.match(calendar, /Math\.ceil\(总格数 \/ 日历列数\)/);
  assert.match(calendar,
    /export function 构建月历\(当前时间: Date, 按日期复习次数: Map<string, number>\): 月历数据/);
  assert.match(calendar, /热力强度:/);
  assert.doesNotMatch(calendar, /demoIntensity|Math\.random/);
});
