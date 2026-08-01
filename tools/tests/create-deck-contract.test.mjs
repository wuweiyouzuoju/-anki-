import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const PANEL = 'entry/src/main/ets/components/创建牌组面板.ets';
const PAGE = 'entry/src/main/ets/pages/首页.ets';
const SERVICE = 'entry/src/main/ets/backend/牌组服务.ts';

test('create deck panel exists as a pure UI building block', () => {
  assert.equal(existsSync(projectUrl(PANEL)), true, `${PANEL} must exist`);
  const panel = read(PANEL);

  assert.match(panel, /@Component/);
  assert.match(panel, /export struct 创建牌组面板/);
  assert.match(panel, /onConfirm: \(fullName: string\) => void/);
  assert.match(panel, /onCancel: \(\) => void/);
  assert.doesNotMatch(panel, /后端会话|牌组服务|libjidecards\.so/,
    'panel must not touch the backend directly');
});

test('create deck panel guards submission and reflects busy/error props', () => {
  const panel = read(PANEL);

  assert.match(panel, /@Prop busy: boolean/);
  assert.match(panel, /@Prop errorMessage: string/);
  assert.match(panel, /deckName\.trim\(\)\.length > 0/);
  assert.match(panel, /\.enabled\(this\.canSubmit\(\)\)/);
  assert.match(panel, /app\.color\.error_text/);
  assert.match(panel, /TextInput\(/);
});

test('create deck panel composes a normalized path from its selected parent', () => {
  const panel = read(PANEL);

  assert.match(panel, /parentOptions: 牌组汇总\[\]/);
  assert.match(panel, /initialParentId/);
  assert.match(panel, /组合牌组路径/);
});

test('create deck panel uses shared dimension tokens and string resources', () => {
  const panel = read(PANEL);

  assert.match(panel, /应用尺寸/);
  assert.doesNotMatch(panel, /\.fontSize\(\d/, 'must not hardcode fontSize');
  assert.doesNotMatch(panel, /\.borderRadius\(\d/, 'must not hardcode borderRadius');
  for (const key of ['create_deck_title', 'deck_name_placeholder',
    'create_deck_cancel', 'create_deck_confirm', 'create_deck_creating']) {
    assert.match(panel, new RegExp(`app\\.string\\.${key}`), `panel must use ${key}`);
  }
});

test('deck service creates decks via NewDeck template then AddDeck', () => {
  const service = read(SERVICE);

  assert.match(service, /async 创建牌组\(名称: string\): Promise<number>/);
  assert.match(service, /牌组方法\.新建牌组/);
  assert.match(service, /牌组方法\.添加牌组/);
  assert.match(service, /模板\.id = 0/);
  assert.match(service, /模板\.name = 名称/);
  assert.match(service, /decodeOpChangesWithId/);
});

test('home page wires the create button through the full flow', () => {
  const page = read(PAGE);
  const createCoord = read('entry/src/main/ets/components/home/创建牌组协调器.ets');

  assert.match(createCoord, /创建牌组面板/);
  assert.match(page, /@State private 显示创建牌组: boolean/);
  assert.match(page, /@State private 创建牌组中: boolean/);
  assert.match(page, /@State private 创建牌组错误: string/);
  assert.match(page, /async 创建牌组\(name: string\)/);
  assert.match(page, /确保已打开\(context\.filesDir\)/);
  assert.match(page, /this\.牌组服务实例\.创建牌组\(name\)/);
  assert.match(page, /await this\.加载主页数据\(\)/, 'must refresh tree after creation');
  assert.match(page, /选中的牌组ID = newDeckId\.toString\(\)/, 'must select the new deck');
});

test('create deck flow surfaces backend errors inside the panel', () => {
  const page = read(PAGE);
  const method = page.match(/private async 创建牌组\(name: string\): Promise<void> \{[\s\S]*?\n  \}/);

  assert.notEqual(method, null);
  assert.match(method[0], /catch \(error\)/);
  assert.match(method[0], /this\.创建牌组错误 = /);
  assert.match(method[0], /finally \{\s*this\.创建牌组中 = false;/);
});
