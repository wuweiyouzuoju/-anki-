import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');

test('home wires the Anki deck tree, action menu, and selected-deck flows', () => {
  const index = read('entry/src/main/ets/pages/Index.ets');
  const detail = read('entry/src/main/ets/components/DeckDetailPane.ets');
  assert.match(index, /HomeActionPanel/);
  assert.match(index, /visibleDeckRows/);
  assert.match(index, /AddNotePanel/);
  assert.match(index, /DataTransferPanel/);
  assert.match(index, /expandedDeckIds/);
  assert.match(index, /createParentId/);
  assert.match(index, /this\.createParentId = ''/);
  assert.match(index, /this\.createParentId = this\.selectedDeckId/);
  assert.match(index, /initialParentId: this\.createParentId/);
  assert.match(detail, /onAddCard/);
  assert.match(detail, /onCreateSubdeck/);
  assert.match(detail, /onExportDeck/);
  // B12 重构：牌组选项校验错误流上移到 Index.ets（DeckDetailPane 仅上抛回调）
  assert.match(index, /ValidationIssue/);
  assert.match(index, /issue\.messageKey/);
});

test('settings owns only language, data, database check, and about entry points', () => {
  const settings = read('entry/src/main/ets/components/SettingsPanel.ets');
  assert.match(settings, /setLanguageMode/);
  assert.match(settings, /onImportData/);
  assert.match(settings, /onExportData/);
  const dataGroup = settings.slice(settings.indexOf('settings_data_management'), settings.indexOf('settings_database_check'));
  assert.doesNotMatch(dataGroup, /check_db_title/);
  assert.doesNotMatch(settings, /backup_sync_title/);
  assert.doesNotMatch(settings, /onUnavailable/);
  assert.doesNotMatch(settings, /onImport:\s*\(/);
});

test('personal replacement is confirmed twice and export is finalized by UI context', () => {
  const index = read('entry/src/main/ets/pages/Index.ets');
  assert.match(index, /confirmPersonalDataReplacement/);
  assert.match(index, /finalizeExport\(context,/);
  assert.match(index, /importDeckFromPicker/);
  assert.match(index, /transferInitialMode/);
  assert.match(index, /transferInitialDeckId/);
  assert.match(index, /transferAllowDeckSelection/);
  assert.match(index, /savedPath !== null/);
  assert.match(index, /this\.showDataTransfer = true/);

  const transfer = read('entry/src/main/ets/components/DataTransferPanel.ets');
  assert.match(transfer, /@Prop initialMode/);
  assert.match(transfer, /@Prop deckOptions/);
  assert.match(transfer, /@Prop allowDeckSelection/);
  assert.match(transfer, /aboutToAppear/);
  assert.match(transfer, /this\.selectedExportDeckId = this\.deckOptions\[0\]\.id/);
  assert.match(transfer, /this\.selectedExportDeckId <= 0/);
  assert.match(transfer, /this\.mode !== 'exportDeck' \|\| this\.selectedExportDeckId > 0/);
  assert.match(index, /openDataTransfer\('importDeck', 0, true\)/);
  assert.match(index, /openDataTransfer\('importDeck', 0, false\);\s*this\.transferError =/,
    'top-right import failure detail must be assigned after opening the panel');
  assert.doesNotMatch(index, /throw new Error\('ability context unavailable'\)/);
});
