// anki.import_export package codecs, sourced from Anki 26.05 import_export.proto.
import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

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

/** Matches the choices Anki presents when exporting a deck package. */
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
  const w = new ProtoWriter();
  if (packagePath !== '') w.writeString(1, packagePath);
  if (options !== undefined) w.writeMessage(2, encodeImportAnkiPackageOptions(options));
  return w.toBytes();
}

export function encodeExportAnkiPackageRequest(
  outPath: string,
  deckId: number,
  options: ExportAnkiPackageOptions = DEFAULT_EXPORT_ANKI_PACKAGE_OPTIONS
): Uint8Array {
  const w = new ProtoWriter();
  if (outPath !== '') w.writeString(1, outPath);
  w.writeMessage(2, encodeExportAnkiPackageOptions(options));
  const limit = new ProtoWriter();
  limit.writeInt64(2, deckId);
  w.writeMessage(3, limit);
  return w.toBytes();
}

export function encodeImportCollectionPackageRequest(request: ImportCollectionPackageRequest): Uint8Array {
  const w = new ProtoWriter();
  if (request.colPath !== '') w.writeString(1, request.colPath);
  if (request.backupPath !== '') w.writeString(2, request.backupPath);
  if (request.mediaFolder !== '') w.writeString(3, request.mediaFolder);
  if (request.mediaDb !== '') w.writeString(4, request.mediaDb);
  return w.toBytes();
}

export function encodeExportCollectionPackageRequest(
  outPath: string,
  options: ExportCollectionPackageOptions = DEFAULT_EXPORT_COLLECTION_PACKAGE_OPTIONS
): Uint8Array {
  const w = new ProtoWriter();
  if (outPath !== '') w.writeString(1, outPath);
  if (options.includeMedia) w.writeBool(2, options.includeMedia);
  if (options.legacy) w.writeBool(3, options.legacy);
  return w.toBytes();
}

function encodeImportAnkiPackageOptions(options: ImportAnkiPackageOptions): ProtoWriter {
  const w = new ProtoWriter();
  if (options.mergeNotetypes) w.writeBool(1, options.mergeNotetypes);
  if (options.updateNotes !== ImportAnkiPackageUpdateCondition.IF_NEWER) w.writeVarint(2, options.updateNotes);
  if (options.updateNotetypes !== ImportAnkiPackageUpdateCondition.IF_NEWER) w.writeVarint(3, options.updateNotetypes);
  if (options.withScheduling) w.writeBool(4, options.withScheduling);
  if (options.withDeckConfigs) w.writeBool(5, options.withDeckConfigs);
  return w;
}

function encodeExportAnkiPackageOptions(options: ExportAnkiPackageOptions): ProtoWriter {
  const w = new ProtoWriter();
  if (options.withScheduling) w.writeBool(1, options.withScheduling);
  if (options.withDeckConfigs) w.writeBool(2, options.withDeckConfigs);
  if (options.withMedia) w.writeBool(3, options.withMedia);
  if (options.legacy) w.writeBool(4, options.legacy);
  return w;
}

/** ImportResponse: only counts the Log section required by the presentation layer. */
export function decodeImportResponse(bytes: Uint8Array): ImportSummary {
  const summary: ImportSummary = { newNotes: 0, updatedNotes: 0, duplicateNotes: 0, foundNotes: 0 };
  const r = new ProtoReader(bytes);
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 2) {
      decodeImportLog(r.readBytes(), summary);
    } else {
      r.skipField(tag.wireType);
    }
  }
  return summary;
}

function decodeImportLog(bytes: Uint8Array, summary: ImportSummary): void {
  const r = new ProtoReader(bytes);
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        summary.newNotes += 1;
        r.skipField(tag.wireType);
        break;
      case 2:
        summary.updatedNotes += 1;
        r.skipField(tag.wireType);
        break;
      case 3:
        summary.duplicateNotes += 1;
        r.skipField(tag.wireType);
        break;
      case 10:
        summary.foundNotes = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
}
