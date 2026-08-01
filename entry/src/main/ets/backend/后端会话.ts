// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端客户端 } from './后端客户端';
import { 集合方法, 服务号, 原生状态 } from './服务索引';
import { 后端错误, 映射原生错误 } from './错误类型';
import { encodeBackendInit } from '../proto/messages/BackendMessages';
import { encodeCloseCollectionRequest, encodeOpenCollectionRequest } from '../proto/messages/CollectionMessages';

export type 会话状态 = 'closed' | 'collectionClosed' | 'ready';

export class 后端会话 {
  private static 实例: 后端会话 | null = null;

  static 获取实例(): 后端会话 {
    if (后端会话.实例 === null) {
      后端会话.实例 = new 后端会话();
    }
    return 后端会话.实例;
  }

  private readonly 客户端 = new 后端客户端();
  private 状态: 会话状态 = 'closed';
  private 打开中: Promise<void> | null = null;

  确保已打开(文件目录: string): Promise<void> {
    if (this.状态 === 'ready') {
      return Promise.resolve();
    }
    if (this.打开中 !== null) {
      return this.打开中;
    }
    this.打开中 = this.内部打开(文件目录)
      .then(() => {
        this.状态 = 'ready';
      })
      .catch((e: unknown) => {
        this.客户端.关闭();
        this.状态 = 'closed';
        throw e;
      })
      .finally(() => {
        this.打开中 = null;
      });
    return this.打开中;
  }

  private async 内部打开(文件目录: string): Promise<void> {
    if (!this.客户端.是否已打开()) {
      const init = encodeBackendInit({ preferredLangs: ['zh-Hans', 'en'], localeFolderPath: '', server: false });
      try {
        this.客户端.打开(init);
      } catch (e: unknown) {
        throw 映射原生错误(e);
      }
    }
    const request = encodeOpenCollectionRequest({
      collectionPath: `${文件目录}/collection.anki2`,
      mediaFolderPath: `${文件目录}/collection.media`,
      mediaDbPath: `${文件目录}/collection.mdb`
    });
    await this.原始调用(服务号.后端集合, 集合方法.打开, request);
  }

  是否就绪(): boolean {
    return this.状态 === 'ready';
  }

  async 调用(服务号: number, 方法号: number, 输入字节: Uint8Array): Promise<Uint8Array> {
    if (!this.是否就绪()) {
      throw new 后端错误('backend session is not ready', 0, '确保已打开', 原生状态.原生致命错误);
    }
    return this.原始调用(服务号, 方法号, 输入字节);
  }

  async 关闭集合(): Promise<void> {
    if (!this.是否就绪()) {
      throw new 后端错误('backend session is not ready', 0, '确保已打开', 原生状态.原生致命错误);
    }
    await this.原始调用(
      服务号.后端集合,
      集合方法.关闭,
      encodeCloseCollectionRequest(false)
    );
    this.状态 = 'collectionClosed';
  }

  async 标记集合已消费(): Promise<void> {
    if (this.状态 !== 'ready') {
      return;
    }
    this.状态 = 'collectionClosed';
  }

  async 在集合关闭下调用(服务号: number, 方法号: number, 输入字节: Uint8Array): Promise<Uint8Array> {
    if (this.状态 !== 'collectionClosed') {
      throw new 后端错误('collection must be closed', 0, '关闭集合', 原生状态.原生致命错误);
    }
    return this.原始调用(服务号, 方法号, 输入字节);
  }

  private async 原始调用(服务号: number, 方法号: number, 输入字节: Uint8Array): Promise<Uint8Array> {
    try {
      return await this.客户端.调用原始(服务号, 方法号, 输入字节);
    } catch (e: unknown) {
      throw 映射原生错误(e);
    }
  }

  关闭(): void {
    this.客户端.关闭();
    this.状态 = 'closed';
  }
}
