// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BackendSession } from './BackendSession';
import { IMPORT_EXPORT_METHOD, SERVICE } from './ServiceIds';
import type { ImportSummary } from '../proto/messages/ImportExportMessages';
import {
  decodeImportResponse,
  encodeExportAnkiPackageRequest,
  encodeExportCollectionPackageRequest,
  encodeImportAnkiPackageRequest,
  encodeImportCollectionPackageRequest
} from '../proto/messages/ImportExportMessages';

export interface DeckExportOptions {
  withScheduling: boolean;
  withDeckConfigs: boolean;
  withMedia: boolean;
  legacy: boolean;
}

export interface CollectionExportOptions {
  includeMedia: boolean;
  legacy: boolean;
}

const COLLECTION_FILE: string = 'collection.anki2';
const MEDIA_DB_FILE: string = 'collection.mdb';
const MEDIA_FOLDER: string = 'collection.media';
const COPY_BUFFER_SIZE: number = 64 * 1024;
let transferOutputId: number = 0;

interface SafetyCopy {
  rootDir: string;
  collectionPath: string;
  mediaDbPath: string;
  mediaFolderPath: string;
}

export type DataTransferValidationKey = 'transfer_confirmation_required';

/** Stable presentation key for transfer preconditions; UI code owns localization. */
export class DataTransferValidationError extends Error {
  readonly messageKey: DataTransferValidationKey;

  constructor(messageKey: DataTransferValidationKey) {
    super(messageKey);
    this.messageKey = messageKey;
  }
}

/** Exports a selected deck and its children into an Anki .apkg sandbox file. */
export async function exportDeck(
  filesDir: string,
  deckId: number,
  options: DeckExportOptions
): Promise<string> {
  const outPath = transferOutputPath(filesDir, 'deck', 'apkg');
  try {
    await BackendSession.getInstance().run(
      SERVICE.BACKEND_IMPORT_EXPORT,
      IMPORT_EXPORT_METHOD.EXPORT_ANKI_PACKAGE,
      encodeExportAnkiPackageRequest(outPath, deckId, options)
    );
    return outPath;
  } catch (error) {
    removeQuietly(outPath);
    throw error;
  }
}

/** Exports all personal Anki data into a sandbox .colpkg file. */
export async function exportCollection(
  filesDir: string,
  options: CollectionExportOptions
): Promise<string> {
  const outPath = transferOutputPath(filesDir, 'collection', 'colpkg');
  try {
    await BackendSession.getInstance().run(
      SERVICE.BACKEND_IMPORT_EXPORT,
      IMPORT_EXPORT_METHOD.EXPORT_COLLECTION_PACKAGE,
      encodeExportCollectionPackageRequest(outPath, options)
    );
    return outPath;
  } catch (error) {
    removeQuietly(outPath);
    throw error;
  }
}

/**
 * Completes a previously exported sandbox file through Harmony's document saver.
 * Task 6 owns invoking this UI-context boundary after receiving an export intent.
 */
export async function finalizeExport(
  context: common.UIAbilityContext,
  sandboxPath: string,
  fileName: string,
  extension: string
): Promise<string | null> {
  return saveSandboxExport(context, sandboxPath, fileName, extension);
}

async function saveSandboxExport(
  context: common.UIAbilityContext,
  sandboxPath: string,
  fileName: string,
  extension: string
): Promise<string | null> {
  try {
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = [extension];
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: Array<string> = await documentPicker.save(options);
    if (uris.length === 0) return null;
    copyFileByDescriptor(sandboxPath, uris[0]);
    return uris[0];
  } finally {
    removeQuietly(sandboxPath);
  }
}

/** Copies the selected .apkg into the sandbox for backend import. Returns the staged path. */
export function stageImportFile(filesDir: string, sourceUri: string): string {
  return copyUriToSandbox(filesDir, sourceUri, 'apkg');
}

/** Runs the backend import on a previously staged file, then cleans up. */
export async function runImportDeck(stagedPath: string): Promise<ImportSummary> {
  try {
    const response = await BackendSession.getInstance().run(
      SERVICE.BACKEND_IMPORT_EXPORT,
      IMPORT_EXPORT_METHOD.IMPORT_ANKI_PACKAGE,
      encodeImportAnkiPackageRequest(stagedPath)
    );
    return decodeImportResponse(response);
  } finally {
    removeQuietly(stagedPath);
  }
}

/** Replaces personal data only after the presentation layer obtains its second confirmation. */
export async function replaceCollection(
  filesDir: string,
  sourceUri: string,
  confirmed: boolean,
  onStage?: (stage: number) => void
): Promise<void> {
  if (!confirmed) {
    throw new DataTransferValidationError('transfer_confirmation_required');
  }

  onStage?.(0); // 准备文件中
  const stagedPath = copyUriToSandbox(filesDir, sourceUri, 'colpkg');
  const session = BackendSession.getInstance();
  let safetyCopy: SafetyCopy | null = null;
  try {
    onStage?.(1); // 关闭数据库中
    await session.closeCollection();
    safetyCopy = createSafetyCopy(filesDir);
    onStage?.(2); // 导入数据中
    await session.runWithClosedCollection(
      SERVICE.BACKEND_IMPORT_EXPORT,
      IMPORT_EXPORT_METHOD.IMPORT_COLLECTION_PACKAGE,
      encodeImportCollectionPackageRequest({
        colPath: `${filesDir}/${COLLECTION_FILE}`,
        backupPath: stagedPath,
        mediaFolder: `${filesDir}/${MEDIA_FOLDER}`,
        mediaDb: `${filesDir}/${MEDIA_DB_FILE}`
      })
    );
    onStage?.(3); // 恢复数据库中
    await session.ensureOpen(filesDir);
  } catch (error) {
    if (safetyCopy !== null) {
      restoreSafetyCopy(filesDir, safetyCopy);
    }
    await session.ensureOpen(filesDir);
    throw error;
  } finally {
    removeQuietly(stagedPath);
  }
  if (safetyCopy !== null) {
    deleteSafetyCopy(safetyCopy);
  }
}

function transferOutputPath(filesDir: string, stem: string, extension: string): string {
  const exportsDir = `${filesDir}/exports`;
  ensureDirectory(exportsDir);
  return `${exportsDir}/${stem}-${Date.now()}-${nextTransferOutputId()}.${extension}`;
}

function nextTransferOutputId(): number {
  transferOutputId += 1;
  return transferOutputId;
}

function createSafetyCopy(filesDir: string): SafetyCopy {
  const rootDir = `${filesDir}/transfer-safety-${Date.now()}-${nextTransferOutputId()}`;
  const collectionPath = `${rootDir}/${COLLECTION_FILE}`;
  const mediaDbPath = `${rootDir}/${MEDIA_DB_FILE}`;
  const mediaFolderPath = `${rootDir}/${MEDIA_FOLDER}`;
  ensureDirectory(rootDir);
  copyFile(`${filesDir}/${COLLECTION_FILE}`, collectionPath);
  copyFile(`${filesDir}/${MEDIA_DB_FILE}`, mediaDbPath);
  copyDirectory(`${filesDir}/${MEDIA_FOLDER}`, mediaFolderPath);
  return { rootDir, collectionPath, mediaDbPath, mediaFolderPath };
}

function restoreSafetyCopy(filesDir: string, safetyCopy: SafetyCopy): void {
  copyFile(safetyCopy.collectionPath, `${filesDir}/${COLLECTION_FILE}`);
  copyFile(safetyCopy.mediaDbPath, `${filesDir}/${MEDIA_DB_FILE}`);
  const mediaPath = `${filesDir}/${MEDIA_FOLDER}`;
  removeDirectory(mediaPath);
  copyDirectory(safetyCopy.mediaFolderPath, mediaPath);
}

function deleteSafetyCopy(safetyCopy: SafetyCopy): void {
  removeDirectoryQuietly(safetyCopy.rootDir);
}

function removeDirectoryQuietly(path: string): void {
  try {
    removeDirectory(path);
  } catch (error) {
    // A stale private recovery copy is safe; it must not roll back a successful import.
  }
}

function copyDirectory(sourcePath: string, targetPath: string): void {
  if (!pathExists(sourcePath)) {
    return;
  }
  ensureDirectory(targetPath);
  for (const entry of fs.listFileSync(sourcePath)) {
    const sourceChild = `${sourcePath}/${entry}`;
    const targetChild = `${targetPath}/${entry}`;
    if (fs.statSync(sourceChild).isDirectory()) {
      copyDirectory(sourceChild, targetChild);
    } else {
      copyFile(sourceChild, targetChild);
    }
  }
}

function removeDirectory(path: string): void {
  if (!pathExists(path)) {
    return;
  }
  for (const entry of fs.listFileSync(path)) {
    const child = `${path}/${entry}`;
    if (fs.statSync(child).isDirectory()) {
      removeDirectory(child);
    } else {
      removeQuietly(child);
    }
  }
  fs.rmdirSync(path);
}

function ensureDirectory(path: string): void {
  if (!pathExists(path)) {
    fs.mkdirSync(path);
  }
}

function pathExists(path: string): boolean {
  try {
    return fs.accessSync(path);
  } catch (error) {
    return false;
  }
}

function copyFile(sourcePath: string, targetPath: string): void {
  fs.copyFileSync(sourcePath, targetPath);
}

function copyUriToSandbox(filesDir: string, uri: string, extension: string): string {
  const importsDir: string = `${filesDir}/imports`;
  if (!pathExists(importsDir)) fs.mkdirSync(importsDir);
  const path: string = `${importsDir}/import-${Date.now()}-${nextTransferOutputId()}.${extension}`;
  try {
    copyFileByDescriptor(uri, path);
    return path;
  } catch (error) {
    removeQuietly(path);
    throw error;
  }
}

/**
 * Streams a sandbox path or a document-provider URI with descriptors. copyFileSync
 * cannot safely consume the temporary provider permissions returned by Harmony pickers.
 */
function copyFileByDescriptor(sourceUriOrPath: string, targetUriOrPath: string): void {
  const source: fs.File = fs.openSync(sourceUriOrPath, fs.OpenMode.READ_ONLY);
  try {
    const target: fs.File = fs.openSync(
      targetUriOrPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(COPY_BUFFER_SIZE);
      let readSize: number = fs.readSync(source.fd, buffer, { length: buffer.byteLength });
      while (readSize > 0) {
        let writtenTotal: number = 0;
        while (writtenTotal < readSize) {
          // fileIo's offset is a file position, not an ArrayBuffer offset.
          const remaining: ArrayBuffer = buffer.slice(writtenTotal, readSize);
          const writtenSize: number = fs.writeSync(
            target.fd, remaining, { length: remaining.byteLength });
          if (writtenSize <= 0) {
            throw new Error('Unable to write transferred data.');
          }
          writtenTotal += writtenSize;
        }
        readSize = fs.readSync(source.fd, buffer, { length: buffer.byteLength });
      }
    } finally {
      fs.closeSync(target);
    }
  } finally {
    fs.closeSync(source);
  }
}

function removeQuietly(path: string): void {
  try {
    fs.unlinkSync(path);
  } catch (error) {
    // The transfer input/output is temporary; cleanup must not mask the primary result.
  }
}
