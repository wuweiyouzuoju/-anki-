// SPDX-License-Identifier: AGPL-3.0-or-later

// BackendSession：Rust backend 句柄与 collection 生命周期的唯一管理者。
// 职责：幂等打开（backend → collection）、统一错误类型化、为高层服务提供 run 通道。
// 不持有任何 UI 状态；UI 通过 isReady() 感知就绪。

import { BackendClient } from './BackendClient';
import { COLLECTION_METHOD, SERVICE, NATIVE_STATUS } from './ServiceIds';
import { BackendError, mapNativeError } from './errors';
import { encodeBackendInit } from '../proto/messages/BackendMessages';
import { encodeCloseCollectionRequest, encodeOpenCollectionRequest } from '../proto/messages/CollectionMessages';

export type SessionState = 'closed' | 'collectionClosed' | 'ready';

export class BackendSession {
  private static instance: BackendSession | null = null;

  static getInstance(): BackendSession {
    if (BackendSession.instance === null) {
      BackendSession.instance = new BackendSession();
    }
    return BackendSession.instance;
  }

  private readonly client = new BackendClient();
  private state: SessionState = 'closed';
  private opening: Promise<void> | null = null;

  /**
   * 幂等打开：先开 backend（BackendInit），再开 collection。
   * 并发调用共享同一次打开过程；失败后可重试。
   * filesDir 为应用沙箱文件目录（context.filesDir）。
   */
  ensureOpen(filesDir: string): Promise<void> {
    if (this.state === 'ready') {
      return Promise.resolve();
    }
    if (this.opening !== null) {
      return this.opening;
    }
    this.opening = this.openInternal(filesDir)
      .then(() => {
        this.state = 'ready';
      })
      .catch((e: unknown) => {
        // 打开失败：关闭半初始化的句柄，允许下次重试
        this.client.close();
        this.state = 'closed';
        throw e;
      })
      .finally(() => {
        this.opening = null;
      });
    return this.opening;
  }

  private async openInternal(filesDir: string): Promise<void> {
    if (!this.client.isOpen()) {
      // server=false：本地库模式；26.05 允许空 locale 目录无翻译运行
      const init = encodeBackendInit({ preferredLangs: ['zh-Hans', 'en'], localeFolderPath: '', server: false });
      try {
        this.client.open(init);
      } catch (e: unknown) {
        throw mapNativeError(e);
      }
    }
    // Anki 存储约定：collection.anki2 / collection.media / collection.mdb（with_extension 规则）
    const request = encodeOpenCollectionRequest({
      collectionPath: `${filesDir}/collection.anki2`,
      mediaFolderPath: `${filesDir}/collection.media`,
      mediaDbPath: `${filesDir}/collection.mdb`
    });
    await this.runRaw(SERVICE.BACKEND_COLLECTION, COLLECTION_METHOD.OPEN, request);
  }

  /** 已打开 backend 且 collection 就绪 */
  isReady(): boolean {
    return this.state === 'ready';
  }

  /** 高层服务的统一调用通道：错误一律类型化为 BackendError */
  async run(service: number, method: number, input: Uint8Array): Promise<Uint8Array> {
    if (!this.isReady()) {
      throw new BackendError('backend session is not ready', 0, 'ensureOpen', NATIVE_STATUS.NATIVE_FATAL);
    }
    return this.runRaw(service, method, input);
  }

  /**
   * Closes only the Anki collection, retaining the initialized native backend.
   * This is required by BackendImportExportService.ImportCollectionPackage,
   * whose Anki 26.05 implementation takes lock_closed_collection().
   */
  async closeCollection(): Promise<void> {
    if (!this.isReady()) {
      throw new BackendError('backend session is not ready', 0, 'ensureOpen', NATIVE_STATUS.NATIVE_FATAL);
    }
    await this.runRaw(
      SERVICE.BACKEND_COLLECTION,
      COLLECTION_METHOD.CLOSE,
      encodeCloseCollectionRequest(false)
    );
    this.state = 'collectionClosed';
  }

  /** Dispatches only operations explicitly valid with the collection closed. */
  async runWithClosedCollection(service: number, method: number, input: Uint8Array): Promise<Uint8Array> {
    if (this.state !== 'collectionClosed') {
      throw new BackendError('collection must be closed', 0, 'closeCollection', NATIVE_STATUS.NATIVE_FATAL);
    }
    return this.runRaw(service, method, input);
  }

  private async runRaw(service: number, method: number, input: Uint8Array): Promise<Uint8Array> {
    try {
      return await this.client.run(service, method, input);
    } catch (e: unknown) {
      throw mapNativeError(e);
    }
  }

  /** 关闭 collection 与 backend 句柄；之后可再次 ensureOpen */
  close(): void {
    this.client.close();
    this.state = 'closed';
  }
}
