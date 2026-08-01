// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 卡片渲染方法, 服务号 } from './服务索引';
import type { RenderedCard } from '../proto/messages/CardRenderingMessages';
import {
  decodeExtractAvTagsResponse,
  decodeRenderCardResponse,
  encodeExtractAvTagsRequest,
  encodeRenderExistingCardRequest
} from '../proto/messages/CardRenderingMessages';
import type { TtsItem } from '../proto/messages/CardRenderingMessages';

export class 卡片渲染服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 渲染既有卡片(卡片ID: number): Promise<RenderedCard> {
    const 请求字节: Uint8Array = encodeRenderExistingCardRequest(卡片ID);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端卡片渲染, 卡片渲染方法.渲染既有卡片, 请求字节);
    return decodeRenderCardResponse(响应字节);
  }

  async 提取音频文件(HTML文本: string, 是否正面: boolean): Promise<string[]> {
    const 请求字节: Uint8Array = encodeExtractAvTagsRequest(HTML文本, 是否正面);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端卡片渲染, 卡片渲染方法.提取音视频标签, 请求字节);
    return decodeExtractAvTagsResponse(响应字节).soundFiles;
  }

  async 提取TTS项(HTML文本: string, 是否正面: boolean): Promise<TtsItem[]> {
    const 请求字节: Uint8Array = encodeExtractAvTagsRequest(HTML文本, 是否正面);
    const 响应字节: Uint8Array = await this.会话.调用(
      服务号.后端卡片渲染, 卡片渲染方法.提取音视频标签, 请求字节);
    return decodeExtractAvTagsResponse(响应字节).ttsItems;
  }
}
