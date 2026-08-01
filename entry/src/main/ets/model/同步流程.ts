// SPDX-License-Identifier: AGPL-3.0-or-later

import {
  SYNC_COLLECTION_REQUIRED,
  SYNC_STATUS_REQUIRED
} from '../proto/messages/SyncMessages';
import type {
  SyncAuth,
  SyncCollectionResponse,
  SyncStatusResponse
} from '../proto/messages/SyncMessages';

export type 同步状态动作 = 'none' | 'normal' | 'fullSync';

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

export type 集合同步结果走向 = 'done' | 'fullSync' | 'fullDownload' | 'fullUpload';

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

export function 提取新端点(响应: SyncStatusResponse | SyncCollectionResponse): string {
  return 响应.newEndpoint;
}

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

export type 同步错误类别 = 'auth' | 'network' | 'other';

const 错误类别_网络错误: number = 6;
const 错误类别_同步鉴权错误: number = 7;

const 鉴权错误正则: RegExp = /401|unauthorized|authentication|auth/i;
const 网络错误正则: RegExp = /network|timeout|timed out|connection|connect|dns|tls|certificate|ssl|eof/i;

export function 分类同步错误(错误: Error, 错误类别编号?: number): 同步错误类别 {
  if (typeof 错误类别编号 === 'number') {
    if (错误类别编号 === 错误类别_网络错误) {
      return 'network';
    }
    if (错误类别编号 === 错误类别_同步鉴权错误) {
      return 'auth';
    }
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
