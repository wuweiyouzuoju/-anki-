// CardRenderingService：卡片渲染域的高层调用封装（M7）。
// 职责：RenderExistingCard → 正反面模板节点流 + CSS；不持有 UI 状态。
// 节点流 → HTML 的组装在 model/StudyCardHtmlBuilder（纯函数，可单测）。

import { BackendSession } from './BackendSession';
import { CARD_RENDERING_METHOD, SERVICE } from './ServiceIds';
import type { RenderedCard } from '../proto/messages/CardRenderingMessages';
import {
  decodeExtractAvTagsResponse,
  decodeRenderCardResponse,
  encodeExtractAvTagsRequest,
  encodeRenderExistingCardRequest
} from '../proto/messages/CardRenderingMessages';
import type { TtsItem } from '../proto/messages/CardRenderingMessages';

export class CardRenderingService {
  private readonly session: BackendSession = BackendSession.getInstance();

  /**
   * 渲染既有卡片的正面/背面节点流与模板 CSS。
   * browser=false / partial_render=false（学习页语义，非浏览页）。
   * isEmpty=true 表示卡片内容为空（如字段缺失），调用方可跳过展示。
   */
  async renderExistingCard(cardId: number): Promise<RenderedCard> {
    const request: Uint8Array = encodeRenderExistingCardRequest(cardId);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_CARD_RENDERING, CARD_RENDERING_METHOD.RENDER_EXISTING_CARD, request);
    return decodeRenderCardResponse(response);
  }

  /**
   * 从一侧卡片 HTML 中提取 [sound:] 音频文件名（保持出现顺序）。
   * TTS 标签由后端一并返回，本端不支持，忽略。
   */
  async extractSoundFiles(html: string, questionSide: boolean): Promise<string[]> {
    const request: Uint8Array = encodeExtractAvTagsRequest(html, questionSide);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_CARD_RENDERING, CARD_RENDERING_METHOD.EXTRACT_AV_TAGS, request);
    return decodeExtractAvTagsResponse(response).soundFiles;
  }

  /**
   * 从一侧卡片 HTML 中提取 [anki:tts lang=xxx]text[/anki:tts] 标签内容（保持出现顺序）。
   * 返回的 TTS items 由 TtsPlayer 用 HarmonyOS CoreSpeechKit 本地朗读，与 SoundPlayer 分轨并行。
   */
  async extractTtsItems(html: string, questionSide: boolean): Promise<TtsItem[]> {
    const request: Uint8Array = encodeExtractAvTagsRequest(html, questionSide);
    const response: Uint8Array = await this.session.run(
      SERVICE.BACKEND_CARD_RENDERING, CARD_RENDERING_METHOD.EXTRACT_AV_TAGS, request);
    return decodeExtractAvTagsResponse(response).ttsItems;
  }
}
