// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export enum ImportAnkiPackageUpdateCondition {
  IF_NEWER = 0,
  ALWAYS = 1,
  NEVER = 2
}

export interface ImportAnkiPackageOptions {
  mergeNotetypes: boolean;
  updateNotes: ImportAnkiPackageUpdateCondition;
  updateNotetypes: ImportAnkiPackageUpdateCondition;
  withScheduling: boolean;
  withDeckConfigs: boolean;
}

export interface ExportAnkiPackageOptions {
  withScheduling: boolean;
  withDeckConfigs: boolean;
  withMedia: boolean;
  legacy: boolean;
}

export interface ExportCollectionPackageOptions {
  includeMedia: boolean;
  legacy: boolean;
}

export interface ImportCollectionPackageRequest {
  colPath: string;
  backupPath: string;
  mediaFolder: string;
  mediaDb: string;
}

export interface ImportSummary {
  newNotes: number;
  updatedNotes: number;
  duplicateNotes: number;
  foundNotes: number;
}

export const DEFAULT_IMPORT_ANKI_PACKAGE_OPTIONS: ImportAnkiPackageOptions = {
  mergeNotetypes: false,
  updateNotes: ImportAnkiPackageUpdateCondition.IF_NEWER,
  updateNotetypes: ImportAnkiPackageUpdateCondition.IF_NEWER,
  withScheduling: false,
  withDeckConfigs: false
};

export const DEFAULT_EXPORT_ANKI_PACKAGE_OPTIONS: ExportAnkiPackageOptions = {
  withScheduling: true,
  withDeckConfigs: true,
  withMedia: true,
  legacy: false
};

export const DEFAULT_EXPORT_COLLECTION_PACKAGE_OPTIONS: ExportCollectionPackageOptions = {
  includeMedia: true,
  legacy: false
};

export function encodeImportAnkiPackageRequest(
  packagePath: string,
  options?: ImportAnkiPackageOptions
): Uint8Array {
  const w = new 协议写入器();
  if (packagePath !== '') w.写入字符串(1, packagePath);
  if (options !== undefined) w.写入子消息(2, encodeImportAnkiPackageOptions(options));
  return w.转为字节();
}

export function encodeExportAnkiPackageRequest(
  outPath: string,
  deckId: number,
  options: ExportAnkiPackageOptions = DEFAULT_EXPORT_ANKI_PACKAGE_OPTIONS
): Uint8Array {
  const w = new 协议写入器();
  if (outPath !== '') w.写入字符串(1, outPath);
  w.写入子消息(2, encodeExportAnkiPackageOptions(options));
  const limit = new 协议写入器();
  limit.写入64位整数(2, deckId);
  w.写入子消息(3, limit);
  return w.转为字节();
}

export function encodeImportCollectionPackageRequest(request: ImportCollectionPackageRequest): Uint8Array {
  const w = new 协议写入器();
  if (request.colPath !== '') w.写入字符串(1, request.colPath);
  if (request.backupPath !== '') w.写入字符串(2, request.backupPath);
  if (request.mediaFolder !== '') w.写入字符串(3, request.mediaFolder);
  if (request.mediaDb !== '') w.写入字符串(4, request.mediaDb);
  return w.转为字节();
}

export function encodeExportCollectionPackageRequest(
  outPath: string,
  options: ExportCollectionPackageOptions = DEFAULT_EXPORT_COLLECTION_PACKAGE_OPTIONS
): Uint8Array {
  const w = new 协议写入器();
  if (outPath !== '') w.写入字符串(1, outPath);
  if (options.includeMedia) w.写入布尔(2, options.includeMedia);
  if (options.legacy) w.写入布尔(3, options.legacy);
  return w.转为字节();
}

function encodeImportAnkiPackageOptions(options: ImportAnkiPackageOptions): 协议写入器 {
  const w = new 协议写入器();
  if (options.mergeNotetypes) w.写入布尔(1, options.mergeNotetypes);
  if (options.updateNotes !== ImportAnkiPackageUpdateCondition.IF_NEWER) w.写入变长整数(2, options.updateNotes);
  if (options.updateNotetypes !== ImportAnkiPackageUpdateCondition.IF_NEWER) w.写入变长整数(3, options.updateNotetypes);
  if (options.withScheduling) w.写入布尔(4, options.withScheduling);
  if (options.withDeckConfigs) w.写入布尔(5, options.withDeckConfigs);
  return w;
}

function encodeExportAnkiPackageOptions(options: ExportAnkiPackageOptions): 协议写入器 {
  const w = new 协议写入器();
  if (options.withScheduling) w.写入布尔(1, options.withScheduling);
  if (options.withDeckConfigs) w.写入布尔(2, options.withDeckConfigs);
  if (options.withMedia) w.写入布尔(3, options.withMedia);
  if (options.legacy) w.写入布尔(4, options.legacy);
  return w;
}

export function decodeImportResponse(bytes: Uint8Array): ImportSummary {
  const summary: ImportSummary = { newNotes: 0, updatedNotes: 0, duplicateNotes: 0, foundNotes: 0 };
  const r = new 协议读取器(bytes);
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 2) {
      decodeImportLog(r.读取字节(), summary);
    } else {
      r.跳过字段(tag.线类型);
    }
  }
  return summary;
}

function decodeImportLog(bytes: Uint8Array, summary: ImportSummary): void {
  const r = new 协议读取器(bytes);
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        summary.newNotes += 1;
        r.跳过字段(tag.线类型);
        break;
      case 2:
        summary.updatedNotes += 1;
        r.跳过字段(tag.线类型);
        break;
      case 3:
        summary.duplicateNotes += 1;
        r.跳过字段(tag.线类型);
        break;
      case 10:
        summary.foundNotes = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
}
