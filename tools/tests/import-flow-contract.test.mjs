// 导入 .apkg 链路契约测试（M6）：
// - FileImportHelper 用系统 picker 选 .apkg，沙箱暂存与导入由 DataTransferService 负责；
// - Index.ets 走完 选文件 → 复制 → 导入 → 刷新主页 的全链路。
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const HELPER = 'entry/src/main/ets/utils/FileImportHelper.ets';
const PAGE = 'entry/src/main/ets/pages/Index.ets';
const SETTINGS = 'entry/src/main/ets/components/SettingsPanel.ets';

test('file import helper returns the system-granted URI while the transfer service owns staging', () => {
  assert.equal(existsSync(projectUrl(HELPER)), true, `${HELPER} must exist`);
  const helper = read(HELPER);

  assert.match(helper, /export async function pickApkgFile/);
  assert.match(helper, /new picker\.DocumentViewPicker\(context\)/);
  assert.match(helper, /export async function pickDataFile/);
  assert.match(helper, /fileSuffixFilters = suffixes/);
  assert.doesNotMatch(helper, /fileIo|copyFileSync|readSync|writeSync/);
});

test('home page reuses the DataTransfer deck-merge picker and refreshes after import', () => {
  const page = read(PAGE);

  assert.match(page, /async importDeckFromPicker\(\): Promise<void>/);
  assert.match(page, /pickDataFile\(context, \['\.apkg'\]\)/);
  // B12 2026-07-22：导入拆为 stageImportFile（同步）+ runImportDeck（异步），支撑多阶段进度
  assert.match(page, /stageImportFile\(context\.filesDir, uri\)/);
  assert.match(page, /await runImportDeck\(stagedPath\)/);
  assert.match(page, /await this\.loadHomeData\(\)/, 'must refresh tree after import');
  assert.match(page, /HomeActionPanel/);
  assert.match(page, /DataTransferPanel/);
});

test('settings opens the unified data-management entry instead of a direct import row', () => {
  const settings = read(SETTINGS);

  assert.match(settings, /onImportData: \(\) => void/);
  assert.match(settings, /onExportData: \(\) => void/);
  assert.match(settings, /app\.string\.settings_data_management/);
  assert.doesNotMatch(settings, /backup_sync_title/);
});

test('import strings and stage texts are resourced', () => {
  const strings = JSON.parse(read('entry/src/main/resources/base/element/string.json')).string;
  const names = new Set(strings.map((item) => item.name));

  for (const key of ['import_close', 'transfer_import_deck', 'transfer_import_personal']) {
    assert.equal(names.has(key), true, `missing string resource: ${key}`);
  }
});
