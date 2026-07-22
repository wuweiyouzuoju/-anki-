// SPDX-License-Identifier: AGPL-3.0-or-later

// Anki 26.05 BackendSyncService 边界。
// 包装 BackendSyncService 的 9 个 RPC：
//   - SyncLogin：AnkiWeb 登录，返回 SyncAuth（hkey + 可选 endpoint）
//   - SyncStatus：同步前检查（required/newEndpoint）
//   - SyncCollection：执行一次集合同步
//   - FullUploadOrDownload：强制全量上传/下载（upload 决定方向）
//   - SyncMedia：后台启动媒体同步（rslib 对重复启动安全）
//   - MediaSyncStatus：查询媒体同步进度
//   - AbortSync：中止进行中的集合同步
//   - AbortMediaSync：中止进行中的媒体同步
//   - SetCustomCertificate：注入自定义 CA 证书（PEM），返回是否生效
// backend.rs 内部直连 sync.ankiweb.net（或自定义 endpoint），jidecards 不直接处理 HTTP。

import { BackendSession } from './BackendSession';
import { SERVICE, SYNC_METHOD } from './ServiceIds';
import {
  decodeBoolResponse,
  decodeMediaSyncStatusResponse,
  decodeSyncAuth,
  decodeSyncCollectionResponse,
  decodeSyncStatusResponse,
  encodeEmptyRequest,
  encodeFullUploadOrDownloadRequest,
  encodeStringRequest,
  encodeSyncAuth,
  encodeSyncCollectionRequest,
  encodeSyncLoginRequest
} from '../proto/messages/SyncMessages';
import type {
  MediaSyncStatusResponse,
  SyncAuth,
  SyncCollectionResponse,
  SyncStatusResponse
} from '../proto/messages/SyncMessages';

export class SyncService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * AnkiWeb 登录。
   * endpoint 为空串时使用官方 sync.ankiweb.net；返回的 SyncAuth 供后续所有同步 RPC 使用。
   */
  async syncLogin(username: string, password: string, endpoint: string = ''): Promise<SyncAuth> {
    const response = await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.SYNC_LOGIN,
      encodeSyncLoginRequest({ username, password, endpoint })
    );
    return decodeSyncAuth(response);
  }

  /** 同步前检查：required 取值见 SYNC_STATUS_REQUIRED，newEndpoint 非空时需迁移端点。 */
  async syncStatus(auth: SyncAuth): Promise<SyncStatusResponse> {
    const response = await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.SYNC_STATUS,
      encodeSyncAuth(auth)
    );
    return decodeSyncStatusResponse(response);
  }

  /**
   * 执行一次集合同步。
   * syncMedia=true 时同步完成后自动挂起媒体同步；
   * required 取值见 SYNC_COLLECTION_REQUIRED（可能要求全量上传/下载）。
   */
  async syncCollection(auth: SyncAuth, syncMedia: boolean): Promise<SyncCollectionResponse> {
    const response = await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.SYNC_COLLECTION,
      encodeSyncCollectionRequest({ auth, syncMedia })
    );
    return decodeSyncCollectionResponse(response);
  }

  /**
   * 强制全量上传（upload=true）或全量下载（upload=false），调用方须先得到用户确认。
   * serverUsn 为 null 时跳过媒体 usn 记录；响应为 generic.Empty，忽略字节。
   */
  async fullUploadOrDownload(auth: SyncAuth, upload: boolean, serverUsn: number | null): Promise<void> {
    await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.FULL_UPLOAD_OR_DOWNLOAD,
      encodeFullUploadOrDownloadRequest({ auth, upload, serverUsn })
    );
  }

  /** 后台启动媒体同步（rslib 对重复启动安全）；响应为 generic.Empty，忽略字节。 */
  async syncMedia(auth: SyncAuth): Promise<void> {
    await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.SYNC_MEDIA,
      encodeSyncAuth(auth)
    );
  }

  /** 查询媒体同步状态：active 表示进行中，progress 为后端预格式化文本。 */
  async mediaSyncStatus(): Promise<MediaSyncStatusResponse> {
    const response = await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.MEDIA_SYNC_STATUS,
      encodeEmptyRequest()
    );
    return decodeMediaSyncStatusResponse(response);
  }

  /** 中止进行中的集合同步；响应为 generic.Empty，忽略字节。 */
  async abortSync(): Promise<void> {
    await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.ABORT_SYNC,
      encodeEmptyRequest()
    );
  }

  /** 中止进行中的媒体同步；响应为 generic.Empty，忽略字节。 */
  async abortMediaSync(): Promise<void> {
    await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.ABORT_MEDIA_SYNC,
      encodeEmptyRequest()
    );
  }

  /** 注入自定义 CA 证书（PEM 文本），供同步 TLS 校验使用；返回是否生效。 */
  async setCustomCertificate(pem: string): Promise<boolean> {
    const response = await this.session.run(
      SERVICE.BACKEND_SYNC,
      SYNC_METHOD.SET_CUSTOM_CERTIFICATE,
      encodeStringRequest(pem)
    );
    return decodeBoolResponse(response);
  }
}
