// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AnkiWeb 云同步流程的纯决策逻辑（M10-T14）。
//
// 本模块是 model 层纯函数集合：只依据 SyncMessages 的响应与常量做决策，
// 不发起网络请求、不读写存储、不依赖任何 @kit.* 模块，可被 Node 单测直接加载。
// 决策语义对齐 Anki 26.05 rslib 的 sync 流程（sync.proto 中 required / new_endpoint 字段）。

import {
  SYNC_COLLECTION_REQUIRED,
  SYNC_STATUS_REQUIRED
} from '../proto/messages/SyncMessages';
import type {
  SyncAuth,
  SyncCollectionResponse,
  SyncStatusResponse
} from '../proto/messages/SyncMessages';

/** 同步前检查（sync/status）后的下一步动作 */
export type SyncStatusAction = 'none' | 'normal' | 'fullSync';

/**
 * 根据 SyncStatusResponse.required 决定下一步动作。
 * 未知值按 'fullSync' 兜底（保守策略：宁可全量对齐，也不静默跳过差异）。
 */
export function decideSyncAction(status: SyncStatusResponse): SyncStatusAction {
  switch (status.required) {
    case SYNC_STATUS_REQUIRED.NO_CHANGES:
      return 'none';
    case SYNC_STATUS_REQUIRED.NORMAL_SYNC:
      return 'normal';
    case SYNC_STATUS_REQUIRED.FULL_SYNC:
      return 'fullSync';
    default:
      return 'fullSync';
  }
}

/** 集合同步（sync/collection）响应对应的处理结果 */
export type CollectionOutcome = 'done' | 'fullSync' | 'fullDownload' | 'fullUpload';

/**
 * 根据 SyncCollectionResponse.required 判定同步结果走向。
 * 未知值按 'fullSync' 兜底（保守策略）。
 */
export function decideCollectionOutcome(resp: SyncCollectionResponse): CollectionOutcome {
  switch (resp.required) {
    case SYNC_COLLECTION_REQUIRED.NO_CHANGES:
    case SYNC_COLLECTION_REQUIRED.NORMAL_SYNC:
      return 'done';
    case SYNC_COLLECTION_REQUIRED.FULL_DOWNLOAD:
      return 'fullDownload';
    case SYNC_COLLECTION_REQUIRED.FULL_UPLOAD:
      return 'fullUpload';
    case SYNC_COLLECTION_REQUIRED.FULL_SYNC:
      return 'fullSync';
    default:
      return 'fullSync';
  }
}

/** 提取服务端下发的新端点；空串表示服务端未下发。 */
export function extractNewEndpoint(resp: SyncStatusResponse | SyncCollectionResponse): string {
  return resp.newEndpoint;
}

/**
 * 应用服务端下发的新端点，返回更新后的 SyncAuth。
 * 不可变：不修改传入对象；newEndpoint 为空串时原样返回（引用不变）。
 */
export function applyNewEndpoint(auth: SyncAuth, newEndpoint: string): SyncAuth {
  if (newEndpoint === '') {
    return auth;
  }
  const updated: SyncAuth = {
    hkey: auth.hkey,
    endpoint: newEndpoint,
    ioTimeoutSecs: auth.ioTimeoutSecs
  };
  return updated;
}

/** 同步失败的粗分类：驱动 UI 提示与重试策略 */
export type SyncErrorKind = 'auth' | 'network' | 'other';

// BackendError.kind 数字（来自 anki_proto::backend::BackendError.Kind 枚举）
// 优先用 kind 分类，避免依赖本地化文案语言（中文消息不含英文 "network" 关键字，正则会误判）
const KIND_NETWORK_ERROR: number = 6;
const KIND_SYNC_AUTH_ERROR: number = 7;

// 认证失败：HTTP 401 或后端鉴权错误文案（fallback：非 BackendError 通道抛的原始 Error）
const AUTH_ERROR_PATTERN: RegExp = /401|unauthorized|authentication|auth/i;
// 网络/传输失败：连接、超时、DNS、TLS 等
const NETWORK_ERROR_PATTERN: RegExp = /network|timeout|timed out|connection|connect|dns|tls|certificate|ssl|eof/i;

/**
 * 按错误粗分同步失败原因。
 * 优先用 BackendError.kind 数字（来自 protobuf，与文案语言无关）；
 * kind 未传时 fallback 到错误消息正则（用于非 BackendError 通道抛的原始 Error）。
 */
export function classifySyncError(err: Error, kind?: number): SyncErrorKind {
  if (typeof kind === 'number') {
    if (kind === KIND_NETWORK_ERROR) {
      return 'network';
    }
    if (kind === KIND_SYNC_AUTH_ERROR) {
      return 'auth';
    }
    // SYNC_SERVER_MESSAGE(23) / SYNC_OTHER_ERROR(8) 等走 'other'，UI 会显示后端原始 message
  }
  const message: string = err.message;
  if (AUTH_ERROR_PATTERN.test(message)) {
    return 'auth';
  }
  if (NETWORK_ERROR_PATTERN.test(message)) {
    return 'network';
  }
  return 'other';
}
