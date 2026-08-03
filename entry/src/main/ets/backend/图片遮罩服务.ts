// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID BACKEND-SVC-IMAGEOCCLUSION-001
// @名称 图片遮罩服务边界
//
// @作用
// 包装后端图片遮罩服务的 2 个 RPC：获取图片遮罩字段 / 添加图片遮罩笔记类型。
// 编解码 + 经 后端会话 调用；不持有 UI 状态。
// 不直接封装 AddImageOcclusionNote 单独 RPC——前端走「媒体服务写图 + 笔记服务.添加笔记」通用路径。
//
// @输入
// 获取图片遮罩字段：notetypeId（笔记类型 ID，number）
// 添加图片遮罩笔记类型：无
//
// @输出
// 获取图片遮罩字段：Promise<图片遮罩字段索引>（遮罩/图片/标题/额外 4 个字段索引）
// 添加图片遮罩笔记类型：Promise<void>
//
// @业务规则
// AddImageOcclusionNotetype 入参为 generic.Empty，传空字节。
// 字段索引映射：proto occlusions→遮罩、image→图片、header→标题、back_extra→额外。
//
// @副作用
// 通过 后端会话 间接调用 NAPI 桥；添加图片遮罩笔记类型 会修改 Anki collection（幂等）。
// ========================================================

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

/** 图片遮盖建卡流程的后端边界；只封装「获取字段索引」与「确保笔记类型存在」两个能力。 */
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
