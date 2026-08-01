// SPDX-License-Identifier: AGPL-3.0-or-later

import { closeBackend, openBackend, runMethodRaw } from 'libjidecards.so';

export class 后端客户端 {
  private 句柄: number = 0;

  打开(初始化字节: Uint8Array): void {
    if (this.句柄 !== 0) {
      throw new Error('Backend is already open');
    }
    this.句柄 = openBackend(初始化字节);
  }

  调用原始(服务号: number, 方法号: number, 输入字节: Uint8Array): Promise<Uint8Array> {
    if (this.句柄 === 0) {
      return Promise.reject(new Error('Backend is not open'));
    }
    return runMethodRaw(this.句柄, 服务号, 方法号, 输入字节);
  }

  关闭(): void {
    if (this.句柄 === 0) {
      return;
    }
    const 待关闭句柄: number = this.句柄;
    this.句柄 = 0;
    closeBackend(待关闭句柄);
  }

  是否已打开(): boolean {
    return this.句柄 !== 0;
  }
}
