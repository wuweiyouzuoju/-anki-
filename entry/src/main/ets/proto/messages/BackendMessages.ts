// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface BackendInit {
  preferredLangs: string[];
  localeFolderPath: string;
  server: boolean;
}

export function encodeBackendInit(init: BackendInit): Uint8Array {
  const w = new 协议写入器();
  for (const lang of init.preferredLangs) {
    if (lang !== '') {
      w.写入字符串(1, lang);
    }
  }
  if (init.localeFolderPath !== '') {
    w.写入字符串(2, init.localeFolderPath);
  }
  if (init.server) {
    w.写入布尔(3, true);
  }
  return w.转为字节();
}

export interface BackendErrorInfo {
  message: string;
  kind: number;
  context: string;
}

export function decodeBackendError(bytes: Uint8Array): BackendErrorInfo {
  const r = new 协议读取器(bytes);
  const info: BackendErrorInfo = { message: '', kind: 0, context: '' };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        info.message = r.读取字符串();
        break;
      case 2:
        info.kind = r.读取变长整数();
        break;
      case 4:
        info.context = r.读取字符串();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return info;
}
