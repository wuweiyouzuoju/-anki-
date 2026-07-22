import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '..', '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('Anki 26.05 import/export service methods use the generated indexes', () => {
  const ids = read('entry/src/main/ets/backend/ServiceIds.ts');
  assert.match(ids, /IMPORT_COLLECTION_PACKAGE:\s*0/);
  assert.match(ids, /EXPORT_COLLECTION_PACKAGE:\s*1/);
  assert.match(ids, /IMPORT_ANKI_PACKAGE:\s*2/);
  assert.match(ids, /EXPORT_ANKI_PACKAGE:\s*4/);
});

test('import/export codecs include official deck and collection package fields', () => {
  const codec = read('entry/src/main/ets/proto/messages/ImportExportMessages.ts');
  for (const symbol of [
    'ImportAnkiPackageOptions',
    'encodeImportAnkiPackageRequest',
    'encodeExportAnkiPackageRequest',
    'encodeImportCollectionPackageRequest',
    'encodeExportCollectionPackageRequest'
  ]) {
    assert.match(codec, new RegExp(symbol));
  }
  assert.match(codec, /writeInt64\(2,.*deckId/);
  for (const field of ['withScheduling', 'withDeckConfigs', 'withMedia', 'legacy']) {
    assert.match(codec, new RegExp(field));
  }
  assert.match(codec, /includeMedia/);
});

test('data transfer service exposes package workflows and safe collection replacement', () => {
  const service = read('entry/src/main/ets/backend/DataTransferService.ts');
  for (const method of ['exportDeck', 'exportCollection', 'runImportDeck', 'replaceCollection']) {
    assert.match(service, new RegExp(`export async function ${method}`));
  }
  // B12 2026-07-22：importDeck 拆为 stageImportFile（同步复制到沙箱）+ runImportDeck（后端 RPC）
  assert.match(service, /export function stageImportFile/);
  assert.match(service, /if \(!confirmed\) \{\s*throw new DataTransferValidationError/);
  assert.match(service, /export class DataTransferValidationError extends Error/);
  assert.doesNotMatch(service, /session\.close\(\)/);
  const closeAt = service.indexOf('session.closeCollection()');
  const backupAt = service.indexOf('createSafetyCopy');
  const importAt = service.indexOf('session.runWithClosedCollection(', backupAt);
  const reopenAt = service.indexOf('ensureOpen(filesDir)');
  assert.ok(closeAt < backupAt && backupAt < importAt && importAt < reopenAt);
  assert.match(service, /finally[\s\S]*removeQuietly/);
  assert.match(service, /export async function finalizeExport/);
  assert.match(service, /saveSandboxExport/);
  assert.match(service, /nextTransferOutputId/);
  assert.match(service, /copyDirectory\(/);
  assert.match(service, /removeDirectoryQuietly\(safetyCopy\.rootDir\)/);
  const successfulReopenAt = service.indexOf('await session.ensureOpen(filesDir);');
  const cleanupAt = service.indexOf('deleteSafetyCopy(safetyCopy);');
  const catchAt = service.indexOf('} catch (error)', reopenAt);
  assert.ok(successfulReopenAt < cleanupAt && catchAt < cleanupAt, 'safety cleanup must run after rollback scope');
});

test('data transfer panel only emits typed intents and separates merge from replacement', () => {
  const panel = read('entry/src/main/ets/components/DataTransferPanel.ets');
  assert.match(panel, /export type DataTransferIntent/);
  assert.match(panel, /replacePersonalData/);
  assert.match(panel, /onIntent/);
  assert.doesNotMatch(panel, /DataTransferService|BackendSession|\.run\(/);
  // 模式切换：B12-Y2 2026-07-22 起改用 @Builder modeTab（4 个 Tab 水平排列）替代 Select+TRANSFER_MODES[index]
  assert.match(panel, /TRANSFER_MODES: DataTransferMode\[\]/);
  assert.match(panel, /@Builder modeTab/);
  // 导出选项默认展开（不再用 showExportOptions 切换）
  assert.match(panel, /personalReplacementAcknowledged/);
  for (const option of ['includeScheduling', 'includeDeckConfigs', 'includeMedia', 'legacy']) {
    assert.match(panel, new RegExp(option));
  }
});

test('backend session retains the native handle while collection-only RPCs run', () => {
  const session = read('entry/src/main/ets/backend/BackendSession.ts');
  const collectionMessages = read('entry/src/main/ets/proto/messages/CollectionMessages.ts');
  assert.match(session, /type SessionState = 'closed' \| 'collectionClosed' \| 'ready'/);
  assert.match(session, /async closeCollection\(\): Promise<void>/);
  assert.match(session, /async runWithClosedCollection\(/);
  assert.match(session, /COLLECTION_METHOD\.CLOSE/);
  assert.match(collectionMessages, /encodeCloseCollectionRequest/);
  assert.match(collectionMessages, /writeBool\(1, downgradeToSchema11\)/);
});

test('sandbox exports are delivered through the official document saver and always cleaned', () => {
  const service = read('entry/src/main/ets/backend/DataTransferService.ts');
  assert.match(service, /new picker\.DocumentSaveOptions\(\)/);
  assert.match(service, /documentPicker\.save\(options\)/);
  assert.match(service, /finally[\s\S]*removeQuietly\(sandboxPath\)/);
});

test('provider URI imports stage data through file descriptors instead of copyFileSync', () => {
  const service = read('entry/src/main/ets/backend/DataTransferService.ts');
  assert.match(service, /function copyFileByDescriptor\(\s*sourceUriOrPath: string,\s*targetUriOrPath: string\s*\): void/);
  assert.match(service, /fs\.openSync\(sourceUriOrPath, fs\.OpenMode\.READ_ONLY\)/);
  assert.match(service, /fs\.openSync\(\s*targetUriOrPath,\s*fs\.OpenMode\.READ_WRITE \| fs\.OpenMode\.CREATE \| fs\.OpenMode\.TRUNC\s*\)/);
  assert.match(service, /fs\.readSync\(source\.fd, buffer, \{ length: buffer\.byteLength \}\)/);
  assert.match(service, /let writtenTotal: number = 0;/);
  assert.match(service, /while \(writtenTotal < readSize\) \{/);
  assert.match(service, /const remaining: ArrayBuffer = buffer\.slice\(writtenTotal, readSize\);/);
  assert.match(service, /const writtenSize: number =\s*fs\.writeSync\(\s*target\.fd, remaining, \{ length: remaining\.byteLength \}\);/);
  assert.match(service, /if \(writtenSize <= 0\) \{\s*throw new Error\('Unable to write transferred data\.'\);\s*\}/);
  assert.match(service, /writtenTotal \+= writtenSize;/);
  assert.match(service, /finally\s*\{\s*fs\.closeSync\(target\);\s*\}/);
  assert.match(service, /finally\s*\{\s*fs\.closeSync\(source\);\s*\}/);
  assert.match(service, /copyFileByDescriptor\(uri, path\)/);
  assert.doesNotMatch(service, /fs\.copyFileSync\(uri, path\)/);
});

test('document saver writes the selected provider URI through file descriptors and cleans up', () => {
  const service = read('entry/src/main/ets/backend/DataTransferService.ts');
  assert.match(service, /copyFileByDescriptor\(sandboxPath, uris\[0\]\)/);
  assert.doesNotMatch(service, /fs\.copyFileSync\(sandboxPath, uris\[0\]\)/);
  assert.match(service, /if \(uris\.length === 0\) return null;/);
  assert.match(service, /finally[\s\S]*removeQuietly\(sandboxPath\)/);
});

test('file-picker helper never bypasses granted URI permissions with copyFileSync', () => {
  const helper = read('entry/src/main/ets/utils/FileImportHelper.ets');
  assert.doesNotMatch(helper, /fs\.copyFileSync/);
});
