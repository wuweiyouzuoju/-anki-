// SPDX-License-Identifier: AGPL-3.0-or-later

// anki.card_rendering 渲染链路消息编解码。
// 字段来源：third_party/anki/proto/anki/card_rendering.proto（Anki 26.05）
//
// RenderCardResponse 返回的是模板节点流（文本/字段替换交替），不是最终 HTML；
// 节点 → HTML 的组装属于渲染层（M7 ArkWeb 页面），本文件只做纯编解码。

import { ProtoReader } from '../core/ProtoReader';
import { ProtoWriter } from '../core/ProtoWriter';

export function encodeRenderExistingCardRequest(cardId: number): Uint8Array {
  const w = new ProtoWriter();
  if (cardId !== 0) {
    w.writeInt64(1, cardId);
  }
  // browser=false、partial_render=false 为 proto3 默认值，按 prost 约定不写字段
  return w.toBytes();
}

/** ExtractAvTagsRequest：card_rendering.proto 字段 1=text, 2=question_side */
export function encodeExtractAvTagsRequest(text: string, questionSide: boolean): Uint8Array {
  const w = new ProtoWriter();
  if (text !== '') {
    w.writeString(1, text);
  }
  if (questionSide) {
    w.writeBool(2, true);
  }
  return w.toBytes();
}

/** ExtractAvTagsResponse 的解码结果：
 *  - soundFiles: [sound:xxx.mp3] 标签文件名（AVPlayer 播放）
 *  - ttsItems: [anki:tts lang=xxx]text[/anki:tts] 标签内容（CoreSpeechKit 朗读）
 */
export interface AvTagsResult {
  text: string;
  soundFiles: string[];
  ttsItems: TtsItem[];
}

export interface TtsItem {
  text: string;
  language: string;
}

function decodeAvTag(bytes: Uint8Array, soundFiles: string[], ttsItems: TtsItem[]): void {
  const r = new ProtoReader(bytes);
  let tag;
  while ((tag = r.readTag()) !== null) {
    if (tag.fieldNumber === 1) {
      // sound_or_video: string
      soundFiles.push(r.readString());
    } else if (tag.fieldNumber === 2) {
      // TTSTag: { text=1, lang=2, voices=3, speed=4, other_fields=5 }
      ttsItems.push(decodeTtsTag(r.readBytes()));
    } else {
      r.skipField(tag.wireType);
    }
  }
}

function decodeTtsTag(bytes: Uint8Array): TtsItem {
  const r = new ProtoReader(bytes);
  const out: TtsItem = { text: '', language: '' };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.text = r.readString();
        break;
      case 2:
        out.language = r.readString();
        break;
      default:
        // 3=voices(repeated string), 4=speed(float), 5=other_fields(map) — 本端不使用
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export function decodeExtractAvTagsResponse(bytes: Uint8Array): AvTagsResult {
  const r = new ProtoReader(bytes);
  const out: AvTagsResult = { text: '', soundFiles: [], ttsItems: [] };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.text = r.readString();
        break;
      case 2:
        decodeAvTag(r.readBytes(), out.soundFiles, out.ttsItems);
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

export interface TemplateReplacement {
  fieldName: string;
  currentText: string;
  filters: string[];
}

export interface TemplateNode {
  /** 文本节点内容；replacement 节点时为 null */
  text: string | null;
  /** 字段替换节点；text 节点时为 null */
  replacement: TemplateReplacement | null;
}

export interface RenderedCard {
  questionNodes: TemplateNode[];
  answerNodes: TemplateNode[];
  css: string;
  latexSvg: boolean;
  isEmpty: boolean;
}

function decodeReplacement(bytes: Uint8Array): TemplateReplacement {
  const r = new ProtoReader(bytes);
  const out: TemplateReplacement = { fieldName: '', currentText: '', filters: [] };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.fieldName = r.readString();
        break;
      case 2:
        out.currentText = r.readString();
        break;
      case 3:
        out.filters.push(r.readString());
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}

function decodeTemplateNode(bytes: Uint8Array): TemplateNode {
  const r = new ProtoReader(bytes);
  const node: TemplateNode = { text: null, replacement: null };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        node.text = r.readString();
        break;
      case 2:
        node.replacement = decodeReplacement(r.readBytes());
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return node;
}

export function decodeRenderCardResponse(bytes: Uint8Array): RenderedCard {
  const r = new ProtoReader(bytes);
  const out: RenderedCard = {
    questionNodes: [],
    answerNodes: [],
    css: '',
    latexSvg: false,
    isEmpty: false
  };
  let tag;
  while ((tag = r.readTag()) !== null) {
    switch (tag.fieldNumber) {
      case 1:
        out.questionNodes.push(decodeTemplateNode(r.readBytes()));
        break;
      case 2:
        out.answerNodes.push(decodeTemplateNode(r.readBytes()));
        break;
      case 3:
        out.css = r.readString();
        break;
      case 4:
        out.latexSvg = r.readBool();
        break;
      case 5:
        out.isEmpty = r.readBool();
        break;
      default:
        r.skipField(tag.wireType);
    }
  }
  return out;
}
