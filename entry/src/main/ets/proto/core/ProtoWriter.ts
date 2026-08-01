// SPDX-License-Identifier: AGPL-3.0-or-later

import { UTF8编码 } from './utf8';

export const 线类型_变长整数 = 0;
export const 线类型_定长64 = 1;
export const 线类型_长度分隔 = 2;
export const 线类型_定长32 = 5;

export class 协议写入器 {
  private 字节流: number[] = [];

  private 压入变长整数(值: bigint): void {
    let v = 值;
    while (v > 0x7fn) {
      this.字节流.push(Number((v & 0x7fn) | 0x80n));
      v >>= 7n;
    }
    this.字节流.push(Number(v));
  }

  写入标签(字段号: number, 线类型: number): void {
    this.压入变长整数(BigInt(字段号 * 8 + 线类型));
  }

  写入变长整数(字段号: number, 值: number): void {
    this.写入标签(字段号, 线类型_变长整数);
    this.压入变长整数(BigInt(值 >= 0 ? 值 : 0));
  }

  写入64位整数(字段号: number, 值: number): void {
    this.写入标签(字段号, 线类型_变长整数);
    this.压入变长整数(BigInt.asUintN(64, BigInt(值)));
  }

  写入打包64位整数(字段号: number, 值列表: number[]): void {
    if (值列表.length === 0) {
      return;
    }
    const 打包器 = new 协议写入器();
    for (const 值 of 值列表) {
      打包器.压入变长整数(BigInt.asUintN(64, BigInt(值)));
    }
    this.写入字节(字段号, 打包器.转为字节());
  }

  写入布尔(字段号: number, 值: boolean): void {
    this.写入变长整数(字段号, 值 ? 1 : 0);
  }

  写入浮点(字段号: number, 值: number): void {
    this.写入标签(字段号, 线类型_定长32);
    const 缓冲 = new Float32Array([值]);
    const 字节 = new Uint8Array(缓冲.buffer);
    for (const b of 字节) {
      this.字节流.push(b);
    }
  }

  写入打包浮点(字段号: number, 值列表: number[]): void {
    if (值列表.length === 0) {
      return;
    }
    const 载荷 = new Uint8Array(值列表.length * 4);
    for (let i = 0; i < 值列表.length; i++) {
      const 缓冲 = new Float32Array([值列表[i]]);
      载荷.set(new Uint8Array(缓冲.buffer), i * 4);
    }
    this.写入字节(字段号, 载荷);
  }

  写入字符串(字段号: number, 值: string): void {
    const 编码 = UTF8编码(值);
    this.写入标签(字段号, 线类型_长度分隔);
    this.压入变长整数(BigInt(编码.length));
    for (const b of 编码) {
      this.字节流.push(b);
    }
  }

  写入字节(字段号: number, 值: Uint8Array): void {
    this.写入标签(字段号, 线类型_长度分隔);
    this.压入变长整数(BigInt(值.length));
    for (const b of 值) {
      this.字节流.push(b);
    }
  }

  写入子消息(字段号: number, 消息: 协议写入器): void {
    this.写入字节(字段号, 消息.转为字节());
  }

  写入原始字节(字节: Uint8Array): void {
    for (const b of 字节) {
      this.字节流.push(b);
    }
  }

  转为字节(): Uint8Array {
    return new Uint8Array(this.字节流);
  }
}
