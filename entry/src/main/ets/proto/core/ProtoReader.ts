// SPDX-License-Identifier: AGPL-3.0-or-later

// Protobuf wire format 读取器（proto3）。
// 规范来源：https://protobuf.dev/programming-guides/encoding/
// int64/uint64 超过 Number.MAX_SAFE_INTEGER 时抛错——Anki 的 id/时间戳远小于此，
// 真遇到说明数据异常，宁可显式失败也不静默丢精度。

import { utf8Decode } from './utf8';
import { WIRE_FIXED32, WIRE_FIXED64, WIRE_LENGTH_DELIMITED, WIRE_VARINT } from './ProtoWriter';

export interface ProtoTag {
  fieldNumber: number;
  wireType: number;
}

export class ProtoReader {
  private pos = 0;
  private readonly bytes: Uint8Array;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
  }

  get done(): boolean {
    return this.pos >= this.bytes.length;
  }

  /** 当前读取位置（配合 sliceFrom 截取字段原始字节，用于保真回写） */
  get offset(): number {
    return this.pos;
  }

  /** 截取 [start, 当前位置) 的原始字节（含 tag），原样保留未建模字段 */
  sliceFrom(start: number): Uint8Array {
    return this.bytes.slice(start, this.pos);
  }

  private readByte(): number {
    if (this.pos >= this.bytes.length) {
      throw new Error('proto: unexpected end of input');
    }
    return this.bytes[this.pos++];
  }

  readTag(): ProtoTag | null {
    if (this.done) {
      return null;
    }
    const key = this.readVarintBig();
    const wireType = Number(key & 0x7n);
    const fieldNumber = Number(key >> 3n);
    if (fieldNumber <= 0) {
      throw new Error('proto: invalid field number 0');
    }
    return { fieldNumber, wireType };
  }

  readVarintBig(): bigint {
    let result = 0n;
    let shift = 0n;
    for (let i = 0; i < 10; i++) {
      const b = this.readByte();
      result |= BigInt(b & 0x7f) << shift;
      if ((b & 0x80) === 0) {
        return result;
      }
      shift += 7n;
    }
    throw new Error('proto: varint exceeds 10 bytes');
  }

  /** varint → number，超出安全整数范围抛错 */
  readVarint(): number {
    const value = this.readVarintBig();
    if (value > BigInt(Number.MAX_SAFE_INTEGER)) {
      throw new Error(`proto: varint ${value} exceeds safe integer range`);
    }
    return Number(value);
  }

  /** int64：按二进制补码解释 */
  readInt64(): number {
    const unsigned = this.readVarintBig();
    const signed = BigInt.asIntN(64, unsigned);
    if (signed > BigInt(Number.MAX_SAFE_INTEGER) || signed < BigInt(-Number.MAX_SAFE_INTEGER)) {
      throw new Error(`proto: int64 ${signed} exceeds safe integer range`);
    }
    return Number(signed);
  }

  /**
   * int32：按二进制补码解释。protobuf 中 int32 负数（如 Anki usn=-1）会被 prost
   * 编码成 10 字节 varint（先 sign-extend 到 64 位再编码），不能直接用 readVarint
   * 读取——否则会因值超过 Number.MAX_SAFE_INTEGER 抛错。这里读完 varint 后用
   * BigInt.asIntN(32, ...) 截到 32 位有符号整数即可。
   */
  readInt32(): number {
    const unsigned = this.readVarintBig();
    const signed = BigInt.asIntN(32, unsigned);
    if (signed > BigInt(2147483647) || signed < BigInt(-2147483648)) {
      throw new Error(`proto: int32 ${signed} out of range`);
    }
    return Number(signed);
  }

  readBool(): boolean {
    return this.readVarint() !== 0;
  }

  /** float（wire type 5，小端 32 位） */
  readFloat(): number {
    if (this.pos + 4 > this.bytes.length) {
      throw new Error('proto: unexpected end of input');
    }
    const buf = new Uint8Array(4);
    buf.set(this.bytes.slice(this.pos, this.pos + 4));
    this.pos += 4;
    return new Float32Array(buf.buffer)[0];
  }

  /** packed repeated int64（wire type 2 载荷） */
  readPackedInt64(): number[] {
    const payload = new ProtoReader(this.readBytes());
    const out: number[] = [];
    while (!payload.done) {
      out.push(payload.readInt64());
    }
    return out;
  }

  /** packed repeated float（wire type 2 载荷，小端 32 位） */
  readPackedFloat(): number[] {
    const payload = new ProtoReader(this.readBytes());
    const out: number[] = [];
    while (!payload.done) {
      out.push(payload.readFloat());
    }
    return out;
  }

  readBytes(): Uint8Array {
    const length = this.readVarint();
    if (this.pos + length > this.bytes.length) {
      throw new Error('proto: length-delimited field exceeds input');
    }
    const out = this.bytes.slice(this.pos, this.pos + length);
    this.pos += length;
    return out;
  }

  readString(): string {
    return utf8Decode(this.readBytes());
  }

  /** 跳过未知字段，保证向前兼容（新版 Anki 加字段不崩） */
  skipField(wireType: number): void {
    switch (wireType) {
      case WIRE_VARINT:
        this.readVarintBig();
        return;
      case WIRE_FIXED64:
        this.advance(8);
        return;
      case WIRE_LENGTH_DELIMITED:
        this.readBytes();
        return;
      case WIRE_FIXED32:
        this.advance(4);
        return;
      default:
        throw new Error(`proto: unsupported wire type ${wireType}`);
    }
  }

  private advance(count: number): void {
    if (this.pos + count > this.bytes.length) {
      throw new Error('proto: unexpected end of input');
    }
    this.pos += count;
  }
}
