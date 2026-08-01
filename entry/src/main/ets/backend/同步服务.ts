// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 服务号, 同步方法 } from './服务索引';
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

export class 同步服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 同步登录(用户名: string, 密码: string, 端点: string = ''): Promise<SyncAuth> {
    const 响应字节 = await this.会话.调用(
      服务号.后端同步,
      同步方法.同步登录,
      encodeSyncLoginRequest({ username: 用户名, password: 密码, endpoint: 端点 })
    );
    return decodeSyncAuth(响应字节);
  }

  async 同步状态检查(凭证: SyncAuth): Promise<SyncStatusResponse> {
    const 响应字节 = await this.会话.调用(
      服务号.后端同步,
      同步方法.同步状态,
      encodeSyncAuth(凭证)
    );
    return decodeSyncStatusResponse(响应字节);
  }

  async 同步集合(凭证: SyncAuth, 是否同步媒体: boolean): Promise<SyncCollectionResponse> {
    const 响应字节 = await this.会话.调用(
      服务号.后端同步,
      同步方法.同步集合,
      encodeSyncCollectionRequest({ auth: 凭证, syncMedia: 是否同步媒体 })
    );
    return decodeSyncCollectionResponse(响应字节);
  }

  async 全量上传或下载(凭证: SyncAuth, 是否上传: boolean, 服务器USN: number | null): Promise<void> {
    await this.会话.调用(
      服务号.后端同步,
      同步方法.全量上传或下载,
      encodeFullUploadOrDownloadRequest({ auth: 凭证, upload: 是否上传, serverUsn: 服务器USN })
    );
  }

  async 同步媒体(凭证: SyncAuth): Promise<void> {
    await this.会话.调用(
      服务号.后端同步,
      同步方法.同步媒体,
      encodeSyncAuth(凭证)
    );
  }

  async 媒体同步状态(): Promise<MediaSyncStatusResponse> {
    const 响应字节 = await this.会话.调用(
      服务号.后端同步,
      同步方法.媒体同步状态,
      encodeEmptyRequest()
    );
    return decodeMediaSyncStatusResponse(响应字节);
  }

  async 中止同步(): Promise<void> {
    await this.会话.调用(
      服务号.后端同步,
      同步方法.中止同步,
      encodeEmptyRequest()
    );
  }

  async 中止媒体同步(): Promise<void> {
    await this.会话.调用(
      服务号.后端同步,
      同步方法.中止媒体同步,
      encodeEmptyRequest()
    );
  }

  async 设置自定义证书(PEM文本: string): Promise<boolean> {
    const 响应字节 = await this.会话.调用(
      服务号.后端同步,
      同步方法.设置自定义证书,
      encodeStringRequest(PEM文本)
    );
    return decodeBoolResponse(响应字节);
  }
}
