// SPDX-License-Identifier: AGPL-3.0-or-later

import { UTF8解码 } from './utf8';
import { 线类型_定长32, 线类型_定长64, 线类型_长度分隔, 线类型_变长整数 } from './ProtoWriter';

export interface 协议标签 {
  字段号: number;
  线类型: number;
}

export class 协议读取器 {
  private 位置 = 0;
  private readonly 字节流: Uint8Array;

  constructor(字节流: Uint8Array) {
    this.字节流 = 字节流;
  }

  get 已读完(): boolean {
    return this.位置 >= this.字节流.length;
  }

  get 当前位置(): number {
    return this.位置;
  }

  截取片段(起点: number): Uint8Array {
    return this.字节流.slice(起点, this.位置);
  }

  private 读取单字节(): number {
    if (this.位置 >= this.字节流.length) {
      throw new Error('proto: unexpected end of input');
    }
    return this.字节流[this.位置++];
  }

  读取标签(): 协议标签 | null {
    if (this.已读完) {
      return null;
    }
    const 键 = this.读取大变长整数();
    const 线类型 = Number(键 & 0x7n);
    const 字段号 = Number(键 >> 3n);
    if (字段号 <= 0) {
      throw new Error('proto: invalid field number 0');
    }
    return { 字段号, 线类型 };
  }

  读取大变长整数(): bigint {
    let 结果 = 0n;
    let 位移 = 0n;
    for (let i = 0; i < 10; i++) {
      const b = this.读取单字节();
      结果 |= BigInt(b & 0x7f) << 位移;
      if ((b & 0x80) === 0) {
        return 结果;
      }
      位移 += 7n;
    }
    throw new Error('proto: varint exceeds 10 bytes');
  }

  读取变长整数(): number {
    const 值 = this.读取大变长整数();
    if (值 > BigInt(Number.MAX_SAFE_INTEGER)) {
      throw new Error(`proto: varint ${值} exceeds safe integer range`);
    }
    return Number(值);
  }

  读取64位整数(): number {
    const 无符号 = this.读取大变长整数();
    const 有符号 = BigInt.asIntN(64, 无符号);
    if (有符号 > BigInt(Number.MAX_SAFE_INTEGER) || 有符号 < BigInt(-Number.MAX_SAFE_INTEGER)) {
      throw new Error(`proto: int64 ${有符号} exceeds safe integer range`);
    }
    return Number(有符号);
  }

  读取32位整数(): number {
    const 无符号 = this.读取大变长整数();
    const 有符号 = BigInt.asIntN(32, 无符号);
    if (有符号 > BigInt(2147483647) || 有符号 < BigInt(-2147483648)) {
      throw new Error(`proto: int32 ${有符号} out of range`);
    }
    return Number(有符号);
  }

  读取布尔(): boolean {
    return this.读取变长整数() !== 0;
  }

  读取浮点(): number {
    if (this.位置 + 4 > this.字节流.length) {
      throw new Error('proto: unexpected end of input');
    }
    const 缓冲 = new Uint8Array(4);
    缓冲.set(this.字节流.slice(this.位置, this.位置 + 4));
    this.位置 += 4;
    return new Float32Array(缓冲.buffer)[0];
  }

  读取打包64位整数(): number[] {
    const 载荷 = new 协议读取器(this.读取字节());
    const 输出: number[] = [];
    while (!载荷.已读完) {
      输出.push(载荷.读取64位整数());
    }
    return 输出;
  }

  读取打包浮点(): number[] {
    const 载荷 = new 协议读取器(this.读取字节());
    const 输出: number[] = [];
    while (!载荷.已读完) {
      输出.push(载荷.读取浮点());
    }
    return 输出;
  }

  读取字节(): Uint8Array {
    const 长度 = this.读取变长整数();
    if (this.位置 + 长度 > this.字节流.length) {
      throw new Error('proto: length-delimited field exceeds input');
    }
    const 输出 = this.字节流.slice(this.位置, this.位置 + 长度);
    this.位置 += 长度;
    return 输出;
  }

  读取字符串(): string {
    return UTF8解码(this.读取字节());
  }

  跳过字段(线类型: number): void {
    switch (线类型) {
      case 线类型_变长整数:
        this.读取大变长整数();
        return;
      case 线类型_定长64:
        this.前进(8);
        return;
      case 线类型_长度分隔:
        this.读取字节();
        return;
      case 线类型_定长32:
        this.前进(4);
        return;
      default:
        throw new Error(`proto: unsupported wire type ${线类型}`);
    }
  }

  private 前进(数量: number): void {
    if (this.位置 + 数量 > this.字节流.length) {
      throw new Error('proto: unexpected end of input');
    }
    this.位置 += 数量;
  }
}
