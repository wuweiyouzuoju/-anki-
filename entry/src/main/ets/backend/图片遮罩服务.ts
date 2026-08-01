// SPDX-License-Identifier: AGPL-3.0-or-later

import { 后端会话 } from './后端会话';
import { 图片遮罩方法, 服务号 } from './服务索引';
import {
  decodeGetImageOcclusionFieldsResponse,
  encodeGetImageOcclusionFieldsRequest
} from '../proto/messages/ImageOcclusionMessages';

export interface 图片遮罩字段索引 {
  遮罩: number;
  图片: number;
  标题: number;
  额外: number;
}

export class 图片遮罩服务 {
  private readonly 会话: 后端会话 = 后端会话.获取实例();

  async 获取图片遮罩字段(notetypeId: number): Promise<图片遮罩字段索引> {
    const 响应字节 = await this.会话.调用(
      服务号.后端图片遮罩, 图片遮罩方法.获取图片遮罩字段,
      encodeGetImageOcclusionFieldsRequest(notetypeId));
    const fields = decodeGetImageOcclusionFieldsResponse(响应字节);
    return {
      遮罩: fields.occlusions,
      图片: fields.image,
      标题: fields.header,
      额外: fields.backExtra
    };
  }

  async 添加图片遮罩笔记类型(): Promise<void> {
    await this.会话.调用(
      服务号.后端图片遮罩, 图片遮罩方法.添加图片遮罩笔记类型, new Uint8Array(0));
  }
}
