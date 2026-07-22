// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.ankiweb.proto 消息编解码（Anki 26.05）。
// 仅覆盖本项目使用的字段，与 prost 编码对齐：proto3 默认值省略。

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

/** GetAddonInfoRequest：客户端版本 + 最多 25 个 addon id */
export interface GetAddonInfoRequest {
  clientVersion: number;
  addonIds: number[];
}

/** AddonInfo：单个 addon 的元信息 */
export interface AddonInfo {
  id: number;
  modified: number;       // int64
  minVersion: number;
  maxVersion: number;
}

/** GetAddonInfoResponse：addon 列表（请求里没有的 addon 不在此列表中） */
export interface GetAddonInfoResponse {
  info: AddonInfo[];
}

/** CheckForUpdateRequest：客户端自报信息 */
export interface CheckForUpdateRequest {
  version: number;
  buildhash: string;
  os: string;
  installId: number;      // int64
  lastMessageId: number;
}

/** CheckForUpdateResponse：optional 字段可能不存在 */
export interface CheckForUpdateResponse {
  newVersion: string;      // optional，不存在时为空串
  currentTime: number;    // int64
  message: string;        // optional，不存在时为空串
  lastMessageId: number;
}

// ---- 编码 ----

export function encodeGetAddonInfoRequest(req: GetAddonInfoRequest): Uint8Array {
  const w = new ProtoWriter();
  if (req.clientVersion !== 0) {
    w.writeVarint(1, req.clientVersion);
  }
  if (req.addonIds.length > 0) {
    // packed repeated uint32：field 2 wire type 2，payload 是连续 raw varint（无 tag），
    // 与 prost 的 packed 默认编码一致。ProtoWriter.writeVarint 会写 tag，不适合拼 packed payload，
    // 因此单独手写一份 uint32 varint 拼接。
    w.writeBytes(2, encodePackedUint32(req.addonIds));
  }
  return w.toBytes();
}

/** 把 uint32 数组编成 packed payload（连续 varint，无 tag） */
function encodePackedUint32(values: number[]): Uint8Array {
  const bytes: number[] = [];
  for (const v of values) {
    let n = v >= 0 ? v : 0;
    // uint32 最大 5 字节
    while (n > 0x7f) {
      bytes.push((n & 0x7f) | 0x80);
      n >>>= 7;
    }
    bytes.push(n);
  }
  return new Uint8Array(bytes);
}

export function encodeCheckForUpdateRequest(req: CheckForUpdateRequest): Uint8Array {
  const w = new ProtoWriter();
  if (req.version !== 0) {
    w.writeVarint(1, req.version);
  }
  if (req.buildhash !== '') {
    w.writeString(2, req.buildhash);
  }
  if (req.os !== '') {
    w.writeString(3, req.os);
  }
  if (req.installId !== 0) {
    w.writeInt64(4, req.installId);
  }
  if (req.lastMessageId !== 0) {
    w.writeVarint(5, req.lastMessageId);
  }
  return w.toBytes();
}

// ---- 解码 ----

export function decodeAddonInfo(bytes: Uint8Array): AddonInfo {
  const r = new ProtoReader(bytes);
  const out: AddonInfo = {
    id: 0,
    modified: 0,
    minVersion: 0,
    maxVersion: 0
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.id = r.readVarint();
        break;
      case 2:
        out.modified = r.readInt64();
        break;
      case 3:
        out.minVersion = r.readVarint();
        break;
      case 4:
        out.maxVersion = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeGetAddonInfoResponse(bytes: Uint8Array): GetAddonInfoResponse {
  const r = new ProtoReader(bytes);
  const out: GetAddonInfoResponse = { info: [] };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.info.push(decodeAddonInfo(r.readBytes()));
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeCheckForUpdateResponse(bytes: Uint8Array): CheckForUpdateResponse {
  const r = new ProtoReader(bytes);
  const out: CheckForUpdateResponse = {
    newVersion: '',
    currentTime: 0,
    message: '',
    lastMessageId: 0
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.newVersion = r.readString();
        break;
      case 2:
        out.currentTime = r.readInt64();
        break;
      case 3:
        out.message = r.readString();
        break;
      case 4:
        out.lastMessageId = r.readVarint();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}
