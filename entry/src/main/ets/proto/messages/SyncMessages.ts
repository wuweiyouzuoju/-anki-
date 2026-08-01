// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface SyncStatusRequiredValues {
  NO_CHANGES: number;
  NORMAL_SYNC: number;
  FULL_SYNC: number;
}

export const SYNC_STATUS_REQUIRED: SyncStatusRequiredValues = {
  NO_CHANGES: 0,
  NORMAL_SYNC: 1,
  FULL_SYNC: 2
};

export interface SyncCollectionRequiredValues {
  NO_CHANGES: number;
  NORMAL_SYNC: number;
  FULL_SYNC: number;
  FULL_DOWNLOAD: number;
  FULL_UPLOAD: number;
}

export const SYNC_COLLECTION_REQUIRED: SyncCollectionRequiredValues = {
  NO_CHANGES: 0,
  NORMAL_SYNC: 1,
  FULL_SYNC: 2,
  FULL_DOWNLOAD: 3,
  FULL_UPLOAD: 4
};

export interface SyncAuth {
  hkey: string;
  endpoint: string;
  ioTimeoutSecs: number;
}

export interface SyncLoginRequest {
  username: string;
  password: string;
  endpoint: string;
}

export interface SyncStatusResponse {
  required: number;
  newEndpoint: string;
}

export interface SyncCollectionRequest {
  auth: SyncAuth;
  syncMedia: boolean;
}

export interface SyncCollectionResponse {
  hostNumber: number;
  serverMessage: string;
  required: number;
  newEndpoint: string;
  serverMediaUsn: number;
}

export interface MediaSyncStatusResponse {
  active: boolean;
  progress: MediaSyncProgress;
}

export interface MediaSyncProgress {
  checked: string;
  added: string;
  removed: string;
}

export interface FullUploadOrDownloadRequest {
  auth: SyncAuth;
  upload: boolean;
  serverUsn: number | null;
}

export function encodeSyncAuth(auth: SyncAuth): Uint8Array {
  const w = new 协议写入器();
  if (auth.hkey !== '') {
    w.写入字符串(1, auth.hkey);
  }
  if (auth.endpoint !== '') {
    w.写入字符串(2, auth.endpoint);
  }
  if (auth.ioTimeoutSecs !== 0) {
    w.写入变长整数(3, auth.ioTimeoutSecs);
  }
  return w.转为字节();
}

export function encodeSyncLoginRequest(req: SyncLoginRequest): Uint8Array {
  const w = new 协议写入器();
  if (req.username !== '') {
    w.写入字符串(1, req.username);
  }
  if (req.password !== '') {
    w.写入字符串(2, req.password);
  }
  if (req.endpoint !== '') {
    w.写入字符串(3, req.endpoint);
  }
  return w.转为字节();
}

export function encodeSyncCollectionRequest(req: SyncCollectionRequest): Uint8Array {
  const w = new 协议写入器();
  const authBytes = encodeSyncAuth(req.auth);
  if (authBytes.length > 0) {
    w.写入字节(1, authBytes);
  }
  if (req.syncMedia) {
    w.写入布尔(2, req.syncMedia);
  }
  return w.转为字节();
}

export function encodeMediaSyncProgress(progress: MediaSyncProgress): Uint8Array {
  const w = new 协议写入器();
  if (progress.checked !== '') {
    w.写入字符串(1, progress.checked);
  }
  if (progress.added !== '') {
    w.写入字符串(2, progress.added);
  }
  if (progress.removed !== '') {
    w.写入字符串(3, progress.removed);
  }
  return w.转为字节();
}

export function encodeFullUploadOrDownloadRequest(req: FullUploadOrDownloadRequest): Uint8Array {
  const w = new 协议写入器();
  const authBytes = encodeSyncAuth(req.auth);
  if (authBytes.length > 0) {
    w.写入字节(1, authBytes);
  }
  if (req.upload) {
    w.写入布尔(2, req.upload);
  }
  if (req.serverUsn !== null) {
    if (req.serverUsn < 0) {
      w.写入64位整数(3, req.serverUsn);
    } else {
      w.写入变长整数(3, req.serverUsn);
    }
  }
  return w.转为字节();
}

export function encodeEmptyRequest(): Uint8Array {
  return new Uint8Array(0);
}

export function encodeStringRequest(value: string): Uint8Array {
  const w = new 协议写入器();
  if (value !== '') {
    w.写入字符串(1, value);
  }
  return w.转为字节();
}

export function decodeBoolResponse(bytes: Uint8Array): boolean {
  const r = new 协议读取器(bytes);
  let value = false;
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        value = r.读取布尔();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return value;
}

export function decodeSyncAuth(bytes: Uint8Array): SyncAuth {
  const r = new 协议读取器(bytes);
  const out: SyncAuth = {
    hkey: '',
    endpoint: '',
    ioTimeoutSecs: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.hkey = r.读取字符串();
        break;
      case 2:
        out.endpoint = r.读取字符串();
        break;
      case 3:
        out.ioTimeoutSecs = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeSyncStatusResponse(bytes: Uint8Array): SyncStatusResponse {
  const r = new 协议读取器(bytes);
  const out: SyncStatusResponse = {
    required: SYNC_STATUS_REQUIRED.NO_CHANGES,
    newEndpoint: ''
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.required = r.读取变长整数();
        break;
      case 4:
        out.newEndpoint = r.读取字符串();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeSyncCollectionResponse(bytes: Uint8Array): SyncCollectionResponse {
  const r = new 协议读取器(bytes);
  const out: SyncCollectionResponse = {
    hostNumber: 0,
    serverMessage: '',
    required: SYNC_COLLECTION_REQUIRED.NO_CHANGES,
    newEndpoint: '',
    serverMediaUsn: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.hostNumber = r.读取变长整数();
        break;
      case 2:
        out.serverMessage = r.读取字符串();
        break;
      case 3:
        out.required = r.读取变长整数();
        break;
      case 4:
        out.newEndpoint = r.读取字符串();
        break;
      case 5:
        out.serverMediaUsn = r.读取32位整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeMediaSyncProgress(bytes: Uint8Array): MediaSyncProgress {
  const r = new 协议读取器(bytes);
  const out: MediaSyncProgress = {
    checked: '',
    added: '',
    removed: ''
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.checked = r.读取字符串();
        break;
      case 2:
        out.added = r.读取字符串();
        break;
      case 3:
        out.removed = r.读取字符串();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeMediaSyncStatusResponse(bytes: Uint8Array): MediaSyncStatusResponse {
  const r = new 协议读取器(bytes);
  const out: MediaSyncStatusResponse = {
    active: false,
    progress: {
      checked: '',
      added: '',
      removed: ''
    }
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.active = r.读取布尔();
        break;
      case 2:
        out.progress = decodeMediaSyncProgress(r.读取字节());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}
