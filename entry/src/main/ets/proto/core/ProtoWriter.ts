// Protobuf wire format 写入器（proto3，与 prost 编码对齐）。
// 规范来源：https://protobuf.dev/programming-guides/encoding/
// 设计：只覆盖本项目用到的类型；proto3 默认值由调用方跳过（与 prost 一致）。

import { utf8Encode } from './utf8';

export const WIRE_VARINT = 0;
export const WIRE_FIXED64 = 1;
export const WIRE_LENGTH_DELIMITED = 2;
export const WIRE_FIXED32 = 5;

export class ProtoWriter {
  private bytes: number[] = [];

  private pushVarint(value: bigint): void {
    let v = value;
    while (v > 0x7fn) {
      this.bytes.push(Number((v & 0x7fn) | 0x80n));
      v >>= 7n;
    }
    this.bytes.push(Number(v));
  }

  writeTag(fieldNumber: number, wireType: number): void {
    this.pushVarint(BigInt(fieldNumber * 8 + wireType));
  }

  /** varint 无符号写入（uint32/uint64/bool/enum） */
  writeVarint(fieldNumber: number, value: number): void {
    this.writeTag(fieldNumber, WIRE_VARINT);
    this.pushVarint(BigInt(value >= 0 ? value : 0));
  }

  /** int64：负数按二进制补码编成 10 字节 varint（与 prost 一致） */
  writeInt64(fieldNumber: number, value: number): void {
    this.writeTag(fieldNumber, WIRE_VARINT);
    this.pushVarint(BigInt.asUintN(64, BigInt(value)));
  }

  /** packed repeated int64：proto3 数值型 repeated 的默认编码（与 prost 一致） */
  writePackedInt64(fieldNumber: number, values: number[]): void {
    if (values.length === 0) {
      return;
    }
    const packed = new ProtoWriter();
    for (const value of values) {
      packed.pushVarint(BigInt.asUintN(64, BigInt(value)));
    }
    this.writeBytes(fieldNumber, packed.toBytes());
  }

  writeBool(fieldNumber: number, value: boolean): void {
    this.writeVarint(fieldNumber, value ? 1 : 0);
  }

  /** float（wire type 5，小端 32 位） */
  writeFloat(fieldNumber: number, value: number): void {
    this.writeTag(fieldNumber, WIRE_FIXED32);
    const buf = new Float32Array([value]);
    const bytes = new Uint8Array(buf.buffer);
    for (const b of bytes) {
      this.bytes.push(b);
    }
  }

  /** packed repeated float：proto3 数值型 repeated 的默认编码（与 prost 一致） */
  writePackedFloat(fieldNumber: number, values: number[]): void {
    if (values.length === 0) {
      return;
    }
    const payload = new Uint8Array(values.length * 4);
    for (let i = 0; i < values.length; i++) {
      const buf = new Float32Array([values[i]]);
      payload.set(new Uint8Array(buf.buffer), i * 4);
    }
    this.writeBytes(fieldNumber, payload);
  }

  writeString(fieldNumber: number, value: string): void {
    const encoded = utf8Encode(value);
    this.writeTag(fieldNumber, WIRE_LENGTH_DELIMITED);
    this.pushVarint(BigInt(encoded.length));
    for (const b of encoded) {
      this.bytes.push(b);
    }
  }

  writeBytes(fieldNumber: number, value: Uint8Array): void {
    this.writeTag(fieldNumber, WIRE_LENGTH_DELIMITED);
    this.pushVarint(BigInt(value.length));
    for (const b of value) {
      this.bytes.push(b);
    }
  }

  /** 嵌入子消息：tag + 长度 + 子消息字节 */
  writeMessage(fieldNumber: number, message: ProtoWriter): void {
    this.writeBytes(fieldNumber, message.toBytes());
  }

  /** 原样追加已编码字节（未建模字段保真回写用，配合 ProtoReader.sliceFrom） */
  writeRawBytes(bytes: Uint8Array): void {
    for (const b of bytes) {
      this.bytes.push(b);
    }
  }

  toBytes(): Uint8Array {
    return new Uint8Array(this.bytes);
  }
}
