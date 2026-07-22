// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.backend.BackendInit / BackendError 编解码。
// 字段来源：third_party/anki/proto/anki/backend.proto（Anki 26.05）

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

export interface BackendInit {
  preferredLangs: string[];
  localeFolderPath: string;
  server: boolean;
}

export function encodeBackendInit(init: BackendInit): Uint8Array {
  const w = new ProtoWriter();
  for (const lang of init.preferredLangs) {
    if (lang !== '') {
      w.writeString(1, lang);
    }
  }
  if (init.localeFolderPath !== '') {
    w.writeString(2, init.localeFolderPath);
  }
  if (init.server) {
    w.writeBool(3, true);
  }
  return w.toBytes();
}

export interface BackendErrorInfo {
  message: string;
  kind: number;
  context: string;
}

export function decodeBackendError(bytes: Uint8Array): BackendErrorInfo {
  const r = new ProtoReader(bytes);
  const info: BackendErrorInfo = { message: '', kind: 0, context: '' };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        info.message = r.readString();
        break;
      case 2:
        info.kind = r.readVarint();
        break;
      case 4:
        info.context = r.readString();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return info;
}
