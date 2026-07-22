// 新建牌组链路契约测试（M5）：
// - 弹层为纯 UI 积木（不 import 后端），经回调上抛名称；
// - 忙碌/错误态由父级下发；提交需非空且防重入；
// - Index.ets 走 ensureOpen → createDeck → 刷新 的完整链路。
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

function projectUrl(relativePath) {
  return new URL(`../../${relativePath}`, import.meta.url);
}

function read(relativePath) {
  return readFileSync(projectUrl(relativePath), 'utf8');
}

const PANEL = 'entry/src/main/ets/components/CreateDeckPanel.ets';
const PAGE = 'entry/src/main/ets/pages/Index.ets';
const SERVICE = 'entry/src/main/ets/backend/DeckService.ts';

test('create deck panel exists as a pure UI building block', () => {
  assert.equal(existsSync(projectUrl(PANEL)), true, `${PANEL} must exist`);
  const panel = read(PANEL);

  assert.match(panel, /@Component/);
  assert.match(panel, /export struct CreateDeckPanel/);
  assert.match(panel, /onConfirm: \(fullName: string\) => void/);
  assert.match(panel, /onCancel: \(\) => void/);
  assert.doesNotMatch(panel, /BackendSession|DeckService|libjidecards\.so/,
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

  assert.match(panel, /parentOptions: DeckSummary\[\]/);
  assert.match(panel, /initialParentId/);
  assert.match(panel, /composeDeckPath/);
});

test('create deck panel uses shared dimension tokens and string resources', () => {
  const panel = read(PANEL);

  assert.match(panel, /AppDimens/);
  assert.doesNotMatch(panel, /\.fontSize\(\d/, 'must not hardcode fontSize');
  assert.doesNotMatch(panel, /\.borderRadius\(\d/, 'must not hardcode borderRadius');
  for (const key of ['create_deck_title', 'deck_name_placeholder',
    'create_deck_cancel', 'create_deck_confirm', 'create_deck_creating']) {
    assert.match(panel, new RegExp(`app\\.string\\.${key}`), `panel must use ${key}`);
  }
});

test('deck service creates decks via NewDeck template then AddDeck', () => {
  const service = read(SERVICE);

  assert.match(service, /async createDeck\(name: string\): Promise<number>/);
  assert.match(service, /DECKS_METHOD\.NEW_DECK/);
  assert.match(service, /DECKS_METHOD\.ADD_DECK/);
  assert.match(service, /template\.id = 0/);
  assert.match(service, /template\.name = name/);
  assert.match(service, /decodeOpChangesWithId/);
});

test('home page wires the create button through the full flow', () => {
  const page = read(PAGE);

  assert.match(page, /CreateDeckPanel/);
  assert.match(page, /@State private showCreateDeck: boolean/);
  assert.match(page, /@State private createDeckBusy: boolean/);
  assert.match(page, /@State private createDeckError: string/);
  assert.match(page, /async createDeck\(name: string\)/);
  assert.match(page, /ensureOpen\(context\.filesDir\)/);
  assert.match(page, /this\.deckService\.createDeck\(name\)/);
  assert.match(page, /await this\.loadHomeData\(\)/, 'must refresh tree after creation');
  assert.match(page, /selectedDeckId = newDeckId\.toString\(\)/, 'must select the new deck');
});

test('create deck flow surfaces backend errors inside the panel', () => {
  const page = read(PAGE);
  const method = page.match(/private async createDeck\(name: string\): Promise<void> \{[\s\S]*?\n  \}/);

  assert.notEqual(method, null);
  assert.match(method[0], /catch \(error\)/);
  assert.match(method[0], /this\.createDeckError = /);
  assert.match(method[0], /finally \{\s*this\.createDeckBusy = false;/);
});
