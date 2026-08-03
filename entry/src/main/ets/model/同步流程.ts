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

// ========================================================
// @块ID MODEL-SYNC-FLOW-001
// @名称 同步流程-同步状态动作判定
//
// @作用
// 根据 sync/status 响应的 required 字段决定下一步动作（不做 / 普通同步 / 全量同步）。
// 对应 Anki rslib sync 流程中 sync/status 之后的分支决策。
//
// @输入
// 状态响应: SyncStatusResponse（含 required 枚举）。
//
// @输出
// 同步状态动作 字面量：'none' | 'normal' | 'fullSync'。
//
// @业务规则
// 未知 required 值按 'fullSync' 兜底（保守策略：宁可全量对齐，也不静默跳过差异）。
// 字面量值与 Anki 上游 sync.proto 保持一致，不可改写。
//
// @副作用
// 无。
// ========================================================

/** 同步前检查（sync/status）后的下一步动作 */
export type 同步状态动作 = 'none' | 'normal' | 'fullSync';

/**
 * 根据 SyncStatusResponse.required 决定下一步动作。
 * 未知值按 'fullSync' 兜底（保守策略：宁可全量对齐，也不静默跳过差异）。
 */
export function 判定同步动作(状态响应: SyncStatusResponse): 同步状态动作 {
  switch (状态响应.required) {
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

// ========================================================
// @块ID MODEL-SYNC-FLOW-002
// @名称 同步流程-集合同步走向判定
//
// @作用
// 根据 sync/collection 响应的 required 字段判定同步结果走向
// （完成 / 全量同步 / 全量下载 / 全量上传）。
//
// @输入
// 集合响应: SyncCollectionResponse（含 required 枚举）。
//
// @输出
// 集合同步结果走向 字面量：'done' | 'fullSync' | 'fullDownload' | 'fullUpload'。
//
// @业务规则
// NO_CHANGES 与 NORMAL_SYNC 都视为 'done'。
// 未知值按 'fullSync' 兜底（保守策略）。
// 字面量值与 Anki 上游 sync.proto 保持一致，不可改写。
//
// @副作用
// 无。
// ========================================================

/** 集合同步（sync/collection）响应对应的处理结果 */
export type 集合同步结果走向 = 'done' | 'fullSync' | 'fullDownload' | 'fullUpload';

/**
 * 根据 SyncCollectionResponse.required 判定同步结果走向。
 * 未知值按 'fullSync' 兜底（保守策略）。
 */
export function 判定集合同步走向(集合响应: SyncCollectionResponse): 集合同步结果走向 {
  switch (集合响应.required) {
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

// ========================================================
// @块ID MODEL-SYNC-FLOW-003
// @名称 同步流程-端点更新
//
// @作用
// 提取并应用服务端下发的新同步端点（newEndpoint）。
// 空串视为未下发，不修改 auth。
//
// @输入
// 响应: SyncStatusResponse 或 SyncCollectionResponse（提取新端点）。
// 原鉴权: 当前 SyncAuth（应用新端点）。
// 新端点: 服务端下发的新端点 URL（应用新端点）。
//
// @输出
// 提取新端点：返回字符串（可能为空）。
// 应用新端点：返回更新后的 SyncAuth（不可变，不修改原对象）。
//
// @业务规则
// 新端点 为空串时原样返回（引用不变），避免无谓对象创建。
// SyncAuth 的 hkey / ioTimeoutSecs 字段是 Anki 上游协议字段，保留英文。
//
// @副作用
// 无。
// ========================================================

/** 提取服务端下发的新端点；空串表示服务端未下发。 */
export function 提取新端点(响应: SyncStatusResponse | SyncCollectionResponse): string {
  return 响应.newEndpoint;
}

/**
 * 应用服务端下发的新端点，返回更新后的 SyncAuth。
 * 不可变：不修改传入对象；newEndpoint 为空串时原样返回（引用不变）。
 */
export function 应用新端点(原鉴权: SyncAuth, 新端点: string): SyncAuth {
  if (新端点 === '') {
    return 原鉴权;
  }
  const 更新后: SyncAuth = {
    hkey: 原鉴权.hkey,
    endpoint: 新端点,
    ioTimeoutSecs: 原鉴权.ioTimeoutSecs
  };
  return 更新后;
}

// ========================================================
// @块ID MODEL-SYNC-FLOW-004
// @名称 同步流程-错误分类
//
// @作用
// 按错误粗分同步失败原因（鉴权 / 网络 / 其他），驱动 UI 提示与重试策略。
// 优先用 BackendError.kind 数字（来自 protobuf，与文案语言无关）；
// kind 未传时 fallback 到错误消息正则（用于非 BackendError 通道抛的原始 Error）。
//
// @输入
// 错误: 抛出的 Error。
// 错误类别编号?: 可选的 BackendError.kind 数字。
//
// @输出
// 同步错误类别 字面量：'auth' | 'network' | 'other'。
//
// @业务规则
// BackendError.kind 数字（来自 anki_proto::backend::BackendError.Kind 枚举）：
//   6 = NETWORK_ERROR → 'network'
//   7 = SYNC_AUTH_ERROR → 'auth'
//   其他（含 8=SYNC_OTHER_ERROR、23=SYNC_SERVER_MESSAGE）→ 'other'，UI 会显示后端原始 message。
// 正则 fallback：中文消息不含英文 "network" 关键字，正则会误判，因此优先用 kind。
// 字面量值 'auth'/'network'/'other' 是内部 type union 值，保持英文与上游语义一致。
//
// @副作用
// 无。
// ========================================================

/** 同步失败的粗分类：驱动 UI 提示与重试策略 */
export type 同步错误类别 = 'auth' | 'network' | 'other';

// BackendError.kind 数字（来自 anki_proto::backend::BackendError.Kind 枚举）
// 优先用 kind 分类，避免依赖本地化文案语言（中文消息不含英文 "network" 关键字，正则会误判）
const 错误类别_网络错误: number = 6;
const 错误类别_同步鉴权错误: number = 7;

// 认证失败：HTTP 401 或后端鉴权错误文案（fallback：非 BackendError 通道抛的原始 Error）
const 鉴权错误正则: RegExp = /401|unauthorized|authentication|auth/i;
// 网络/传输失败：连接、超时、DNS、TLS 等
const 网络错误正则: RegExp = /network|timeout|timed out|connection|connect|dns|tls|certificate|ssl|eof/i;

/**
 * 按错误粗分同步失败原因。
 * 优先用 BackendError.kind 数字（来自 protobuf，与文案语言无关）；
 * kind 未传时 fallback 到错误消息正则（用于非 BackendError 通道抛的原始 Error）。
 */
export function 分类同步错误(错误: Error, 错误类别编号?: number): 同步错误类别 {
  if (typeof 错误类别编号 === 'number') {
    if (错误类别编号 === 错误类别_网络错误) {
      return 'network';
    }
    if (错误类别编号 === 错误类别_同步鉴权错误) {
      return 'auth';
    }
    // SYNC_SERVER_MESSAGE(23) / SYNC_OTHER_ERROR(8) 等走 'other'，UI 会显示后端原始 message
  }
  const 消息: string = 错误.message;
  if (鉴权错误正则.test(消息)) {
    return 'auth';
  }
  if (网络错误正则.test(消息)) {
    return 'network';
  }
  return 'other';
}
