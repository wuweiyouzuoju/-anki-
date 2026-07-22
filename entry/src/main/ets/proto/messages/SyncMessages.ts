// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.sync.proto 消息编解码（Anki 26.05）。
// 仅覆盖本项目使用的字段，与 prost 编码对齐：proto3 默认值省略。
// 字段定义来源：third_party/anki/proto/anki/sync.proto

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

/** SyncStatusResponse.required 取值（sync.proto 中无 field 2/3） */
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

/** SyncCollectionResponse.required 取值 */
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

/** SyncAuth：登录凭证 + 可选自定义端点 + 可选 IO 超时 */
export interface SyncAuth {
  hkey: string;
  endpoint: string;       // optional，不存在时为空串
  ioTimeoutSecs: number;  // optional uint32，不存在时为 0
}

/** SyncLoginRequest：用户名 + 密码 + 可选自定义端点 */
export interface SyncLoginRequest {
  username: string;
  password: string;
  endpoint: string;       // optional，不存在时为空串
}

/** SyncStatusResponse：同步前检查（proto 中 field 2/3 已废弃，解码需跳过未知字段） */
export interface SyncStatusResponse {
  required: number;       // SYNC_STATUS_REQUIRED
  newEndpoint: string;    // optional，不存在时为空串
}

/** SyncCollectionRequest：auth 嵌套消息 + 是否同步媒体 */
export interface SyncCollectionRequest {
  auth: SyncAuth;
  syncMedia: boolean;
}

/** SyncCollectionResponse：注意 server_media_usn 是 int32，负数按 10 字节 sign-extend varint 编码 */
export interface SyncCollectionResponse {
  hostNumber: number;
  serverMessage: string;
  required: number;       // SYNC_COLLECTION_REQUIRED
  newEndpoint: string;    // optional，不存在时为空串
  serverMediaUsn: number; // int32
}

/** MediaSyncStatusResponse：媒体同步是否进行中 + 进度 */
export interface MediaSyncStatusResponse {
  active: boolean;
  progress: MediaSyncProgress;
}

/** MediaSyncProgress：后端预格式化的进度文本 */
export interface MediaSyncProgress {
  checked: string;
  added: string;
  removed: string;
}

/** FullUploadOrDownloadRequest：server_usn 为 optional int32，null 表示不提供（跳过媒体同步） */
export interface FullUploadOrDownloadRequest {
  auth: SyncAuth;
  upload: boolean;
  serverUsn: number | null; // optional int32，null 不编码
}

// ---- 编码 ----

export function encodeSyncAuth(auth: SyncAuth): Uint8Array {
  const w = new ProtoWriter();
  if (auth.hkey !== '') {
    w.writeString(1, auth.hkey);
  }
  if (auth.endpoint !== '') {
    w.writeString(2, auth.endpoint);
  }
  if (auth.ioTimeoutSecs !== 0) {
    w.writeVarint(3, auth.ioTimeoutSecs);
  }
  return w.toBytes();
}

export function encodeSyncLoginRequest(req: SyncLoginRequest): Uint8Array {
  const w = new ProtoWriter();
  if (req.username !== '') {
    w.writeString(1, req.username);
  }
  if (req.password !== '') {
    w.writeString(2, req.password);
  }
  if (req.endpoint !== '') {
    w.writeString(3, req.endpoint);
  }
  return w.toBytes();
}

export function encodeSyncCollectionRequest(req: SyncCollectionRequest): Uint8Array {
  const w = new ProtoWriter();
  const authBytes = encodeSyncAuth(req.auth);
  if (authBytes.length > 0) {
    w.writeBytes(1, authBytes);
  }
  if (req.syncMedia) {
    w.writeBool(2, req.syncMedia);
  }
  return w.toBytes();
}

export function encodeMediaSyncProgress(progress: MediaSyncProgress): Uint8Array {
  const w = new ProtoWriter();
  if (progress.checked !== '') {
    w.writeString(1, progress.checked);
  }
  if (progress.added !== '') {
    w.writeString(2, progress.added);
  }
  if (progress.removed !== '') {
    w.writeString(3, progress.removed);
  }
  return w.toBytes();
}

export function encodeFullUploadOrDownloadRequest(req: FullUploadOrDownloadRequest): Uint8Array {
  const w = new ProtoWriter();
  const authBytes = encodeSyncAuth(req.auth);
  if (authBytes.length > 0) {
    w.writeBytes(1, authBytes);
  }
  if (req.upload) {
    w.writeBool(2, req.upload);
  }
  if (req.serverUsn !== null) {
    // int32：负数按 prost 规则先 sign-extend 到 64 位再写 varint（位模式与 writeInt64 相同）；
    // 正数直接 varint。
    if (req.serverUsn < 0) {
      w.writeInt64(3, req.serverUsn);
    } else {
      w.writeVarint(3, req.serverUsn);
    }
  }
  return w.toBytes();
}

// ---- 内联 generic 消息（generic.proto 的 Empty/String/Bool） ----

/** generic.Empty：空请求体 */
export function encodeEmptyRequest(): Uint8Array {
  return new Uint8Array(0);
}

/** generic.String：仅一个 field 1 string */
export function encodeStringRequest(value: string): Uint8Array {
  const w = new ProtoWriter();
  if (value !== '') {
    w.writeString(1, value);
  }
  return w.toBytes();
}

/** generic.Bool：仅一个 field 1 bool */
export function decodeBoolResponse(bytes: Uint8Array): boolean {
  const r = new ProtoReader(bytes);
  let value = false;
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        value = r.readBool();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return value;
}

// ---- 解码 ----

export function decodeSyncAuth(bytes: Uint8Array): SyncAuth {
  const r = new ProtoReader(bytes);
  const out: SyncAuth = {
    hkey: '',
    endpoint: '',
    ioTimeoutSecs: 0
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.hkey = r.readString();
        break;
      case 2:
        out.endpoint = r.readString();
        break;
      case 3:
        out.ioTimeoutSecs = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeSyncStatusResponse(bytes: Uint8Array): SyncStatusResponse {
  const r = new ProtoReader(bytes);
  const out: SyncStatusResponse = {
    required: SYNC_STATUS_REQUIRED.NO_CHANGES,
    newEndpoint: ''
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.required = r.readVarint();
        break;
      case 4:
        out.newEndpoint = r.readString();
        break;
      default:
        // field 2/3 在 proto 中不存在，历史/异常数据出现时跳过
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeSyncCollectionResponse(bytes: Uint8Array): SyncCollectionResponse {
  const r = new ProtoReader(bytes);
  const out: SyncCollectionResponse = {
    hostNumber: 0,
    serverMessage: '',
    required: SYNC_COLLECTION_REQUIRED.NO_CHANGES,
    newEndpoint: '',
    serverMediaUsn: 0
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.hostNumber = r.readVarint();
        break;
      case 2:
        out.serverMessage = r.readString();
        break;
      case 3:
        out.required = r.readVarint();
        break;
      case 4:
        out.newEndpoint = r.readString();
        break;
      case 5:
        // int32：prost 对负数编成 10 字节 sign-extend varint，必须用 readInt32
        out.serverMediaUsn = r.readInt32();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeMediaSyncProgress(bytes: Uint8Array): MediaSyncProgress {
  const r = new ProtoReader(bytes);
  const out: MediaSyncProgress = {
    checked: '',
    added: '',
    removed: ''
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.checked = r.readString();
        break;
      case 2:
        out.added = r.readString();
        break;
      case 3:
        out.removed = r.readString();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeMediaSyncStatusResponse(bytes: Uint8Array): MediaSyncStatusResponse {
  const r = new ProtoReader(bytes);
  const out: MediaSyncStatusResponse = {
    active: false,
    progress: {
      checked: '',
      added: '',
      removed: ''
    }
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.active = r.readBool();
        break;
      case 2:
        out.progress = decodeMediaSyncProgress(r.readBytes());
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}
