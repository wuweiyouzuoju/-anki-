// SPDX-License-Identifier: AGPL-3.0-or-later

import { decodeBackendError } from '../proto/messages/BackendMessages';
import { 原生状态 } from './服务索引';

export class 后端错误 extends Error {
  readonly kind: number;
  readonly context: string;
  readonly nativeStatus: number;

  constructor(message: string, kind: number, context: string, nativeStatus: number) {
    super(message);
    this.name = '后端错误';
    this.kind = kind;
    this.context = context;
    this.nativeStatus = nativeStatus;
  }
}

export interface 原生错误形态 {
  nativeStatus?: number;
  details?: Uint8Array;
  message?: string;
}

export function 映射原生错误(caught: unknown): 后端错误 {
  const shape = caught as 原生错误形态;
  const status = typeof shape?.nativeStatus === 'number' ? shape.nativeStatus : 原生状态.原生致命错误;
  if (status === 原生状态.后端错误 && shape.details instanceof Uint8Array && shape.details.length > 0) {
    try {
      const info = decodeBackendError(shape.details);
      return new 后端错误(info.message, info.kind, info.context, status);
    } catch {
    }
  }
  const message = typeof shape?.message === 'string' ? shape.message : 'unknown native error';
  return new 后端错误(message, 0, '', status);
}
