// SPDX-License-Identifier: AGPL-3.0-or-later

import { closeBackend, openBackend, runMethodRaw } from 'libjidecards.so';

export class BackendClient {
  private handle: number = 0;

  open(init: Uint8Array): void {
    if (this.handle !== 0) {
      throw new Error('Backend is already open');
    }
    this.handle = openBackend(init);
  }

  run(service: number, method: number, input: Uint8Array): Promise<Uint8Array> {
    if (this.handle === 0) {
      return Promise.reject(new Error('Backend is not open'));
    }
    return runMethodRaw(this.handle, service, method, input);
  }

  close(): void {
    if (this.handle === 0) {
      return;
    }
    const closingHandle: number = this.handle;
    this.handle = 0;
    closeBackend(closingHandle);
  }

  isOpen(): boolean {
    return this.handle !== 0;
  }
}
