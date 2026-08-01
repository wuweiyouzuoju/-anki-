import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('home wires the Anki deck tree, action menu, and selected-deck flows', () => {
  const index = read('entry/src/main/ets/pages/首页.ets');
  const detail = read('entry/src/main/ets/components/牌组详情面板.ets');
  const transferCoord = read('entry/src/main/ets/components/home/数据迁移协调器.ets');
  assert.match(index, /主页操作面板/);
  assert.match(index, /可见牌组行/);
  assert.match(index, /添加笔记页/);
  assert.match(transferCoord, /数据迁移面板/);
  assert.match(index, /展开的牌组ID集合/);
  assert.match(index, /创建父牌组ID/);
  assert.match(index, /this\.创建父牌组ID = ''/);
  assert.match(index, /this\.创建父牌组ID = this\.选中的牌组ID/);
  assert.match(index, /父牌组ID: this\.创建父牌组ID/);
  assert.match(detail, /添加卡片/);
  assert.match(detail, /创建子牌组/);
  assert.match(detail, /导出牌组/);
  assert.match(index, /校验问题/);
  assert.match(index, /issue\.消息键/);
});

test('settings owns only language, data, database check, and about entry points', () => {
  const settings = read('entry/src/main/ets/components/设置面板.ets');
  assert.match(settings, /设置语言模式/);
  assert.match(settings, /导入数据回调/);
  assert.match(settings, /导出数据回调/);
  const dataGroup = settings.slice(settings.indexOf('settings_data_management'), settings.indexOf('settings_database_check'));
  assert.doesNotMatch(dataGroup, /check_db_title/);
  assert.doesNotMatch(settings, /backup_sync_title/);
  assert.doesNotMatch(settings, /onUnavailable/);
  assert.doesNotMatch(settings, /onImport:\s*\(/);
});

test('personal replacement is confirmed twice and export is finalized by UI context', () => {
  const index = read('entry/src/main/ets/pages/首页.ets');
  assert.match(index, /确认个人数据替换/);
  assert.match(index, /完成导出\(context,/);
  assert.match(index, /执行牌组导入/);
  assert.match(index, /数据迁移初始模式/);
  assert.match(index, /数据迁移初始牌组ID/);
  assert.match(index, /数据迁移允许选牌组/);
  assert.match(index, /savedPath !== null/);
  assert.match(index, /this\.显示数据迁移 = true/);

  const transfer = read('entry/src/main/ets/components/数据迁移面板.ets');
  assert.match(transfer, /@Prop initialMode/);
  assert.match(transfer, /@Prop deckOptions/);
  assert.match(transfer, /@Prop allowDeckSelection/);
  assert.match(transfer, /aboutToAppear/);
  assert.match(transfer, /this\.已选导出牌组Id = this\.deckOptions\[0\]\.id/);
  assert.match(transfer, /this\.已选导出牌组Id <= 0/);
  assert.match(transfer, /this\.模式 !== 'exportDeck' \|\| this\.已选导出牌组Id > 0/);
  assert.match(index, /打开数据迁移\('importDeck', 0, true\)/);
  assert.match(index, /打开数据迁移\('importDeck', 0, false\);\s*this\.数据迁移错误 =/,
    'top-right import failure detail must be assigned after opening the panel');
  assert.doesNotMatch(index, /throw new Error\('ability context unavailable'\)/);
});
