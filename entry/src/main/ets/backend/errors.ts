// 后端错误类型与 NAPI 错误映射。纯逻辑、无桥接依赖，可独立单元测试。

import { decodeBackendError } from '../proto/messages/BackendMessages';
import { NATIVE_STATUS } from './ServiceIds';

/** 类型化的后端错误：kind 与 backend.proto BackendError.Kind 对应（0=INVALID_INPUT … 5=DB_ERROR） */
export class BackendError extends Error {
  readonly kind: number;
  readonly context: string;
  readonly nativeStatus: number;

  constructor(message: string, kind: number, context: string, nativeStatus: number) {
    super(message);
    this.name = 'BackendError';
    this.kind = kind;
    this.context = context;
    this.nativeStatus = nativeStatus;
  }
}

/** NAPI 桥抛出的错误形态（native_module.cpp CreateNativeError） */
export interface NativeErrorShape {
  nativeStatus?: number;
  details?: Uint8Array;
  message?: string;
}

/** 把 NAPI 桥错误映射为 BackendError；BACKEND_ERROR 时 details 是 BackendError protobuf 字节 */
export function mapNativeError(caught: unknown): BackendError {
  const shape = caught as NativeErrorShape;
  const status = typeof shape?.nativeStatus === 'number' ? shape.nativeStatus : NATIVE_STATUS.NATIVE_FATAL;
  if (status === NATIVE_STATUS.BACKEND_ERROR && shape.details instanceof Uint8Array && shape.details.length > 0) {
    try {
      const info = decodeBackendError(shape.details);
      return new BackendError(info.message, info.kind, info.context, status);
    } catch {
      // details 解码失败不应掩盖原始错误，落到通用分支
    }
  }
  const message = typeof shape?.message === 'string' ? shape.message : 'unknown native error';
  return new BackendError(message, 0, '', status);
}
