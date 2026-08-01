// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export interface GetAddonInfoRequest {
  clientVersion: number;
  addonIds: number[];
}

export interface AddonInfo {
  id: number;
  modified: number;
  minVersion: number;
  maxVersion: number;
}

export interface GetAddonInfoResponse {
  info: AddonInfo[];
}

export interface CheckForUpdateRequest {
  version: number;
  buildhash: string;
  os: string;
  installId: number;
  lastMessageId: number;
}

export interface CheckForUpdateResponse {
  newVersion: string;
  currentTime: number;
  message: string;
  lastMessageId: number;
}

export function encodeGetAddonInfoRequest(req: GetAddonInfoRequest): Uint8Array {
  const w = new 协议写入器();
  if (req.clientVersion !== 0) {
    w.写入变长整数(1, req.clientVersion);
  }
  if (req.addonIds.length > 0) {
    w.写入字节(2, encodePackedUint32(req.addonIds));
  }
  return w.转为字节();
}

function encodePackedUint32(values: number[]): Uint8Array {
  const bytes: number[] = [];
  for (const v of values) {
    let n = v >= 0 ? v : 0;
    while (n > 0x7f) {
      bytes.push((n & 0x7f) | 0x80);
      n >>>= 7;
    }
    bytes.push(n);
  }
  return new Uint8Array(bytes);
}

export function encodeCheckForUpdateRequest(req: CheckForUpdateRequest): Uint8Array {
  const w = new 协议写入器();
  if (req.version !== 0) {
    w.写入变长整数(1, req.version);
  }
  if (req.buildhash !== '') {
    w.写入字符串(2, req.buildhash);
  }
  if (req.os !== '') {
    w.写入字符串(3, req.os);
  }
  if (req.installId !== 0) {
    w.写入64位整数(4, req.installId);
  }
  if (req.lastMessageId !== 0) {
    w.写入变长整数(5, req.lastMessageId);
  }
  return w.转为字节();
}

export function decodeAddonInfo(bytes: Uint8Array): AddonInfo {
  const r = new 协议读取器(bytes);
  const out: AddonInfo = {
    id: 0,
    modified: 0,
    minVersion: 0,
    maxVersion: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.id = r.读取变长整数();
        break;
      case 2:
        out.modified = r.读取64位整数();
        break;
      case 3:
        out.minVersion = r.读取变长整数();
        break;
      case 4:
        out.maxVersion = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeGetAddonInfoResponse(bytes: Uint8Array): GetAddonInfoResponse {
  const r = new 协议读取器(bytes);
  const out: GetAddonInfoResponse = { info: [] };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.info.push(decodeAddonInfo(r.读取字节()));
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeCheckForUpdateResponse(bytes: Uint8Array): CheckForUpdateResponse {
  const r = new 协议读取器(bytes);
  const out: CheckForUpdateResponse = {
    newVersion: '',
    currentTime: 0,
    message: '',
    lastMessageId: 0
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.newVersion = r.读取字符串();
        break;
      case 2:
        out.currentTime = r.读取64位整数();
        break;
      case 3:
        out.message = r.读取字符串();
        break;
      case 4:
        out.lastMessageId = r.读取变长整数();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}
