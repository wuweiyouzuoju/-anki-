// SPDX-License-Identifier: AGPL-3.0-or-later

import { 协议读取器 } from '../core/ProtoReader';
import { 协议写入器 } from '../core/ProtoWriter';

export function encodeRenderExistingCardRequest(cardId: number): Uint8Array {
  const w = new 协议写入器();
  if (cardId !== 0) {
    w.写入64位整数(1, cardId);
  }
  return w.转为字节();
}

export function encodeExtractAvTagsRequest(text: string, questionSide: boolean): Uint8Array {
  const w = new 协议写入器();
  if (text !== '') {
    w.写入字符串(1, text);
  }
  if (questionSide) {
    w.写入布尔(2, true);
  }
  return w.转为字节();
}

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
  const r = new 协议读取器(bytes);
  let tag;
  while ((tag = r.读取标签()) !== null) {
    if (tag.字段号 === 1) {
      soundFiles.push(r.读取字符串());
    } else if (tag.字段号 === 2) {
      ttsItems.push(decodeTtsTag(r.读取字节()));
    } else {
      r.跳过字段(tag.线类型);
    }
  }
}

function decodeTtsTag(bytes: Uint8Array): TtsItem {
  const r = new 协议读取器(bytes);
  const out: TtsItem = { text: '', language: '' };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.text = r.读取字符串();
        break;
      case 2:
        out.language = r.读取字符串();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

export function decodeExtractAvTagsResponse(bytes: Uint8Array): AvTagsResult {
  const r = new 协议读取器(bytes);
  const out: AvTagsResult = { text: '', soundFiles: [], ttsItems: [] };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.text = r.读取字符串();
        break;
      case 2:
        decodeAvTag(r.读取字节(), out.soundFiles, out.ttsItems);
        break;
      default:
        r.跳过字段(tag.线类型);
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
  text: string | null;
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
  const r = new 协议读取器(bytes);
  const out: TemplateReplacement = { fieldName: '', currentText: '', filters: [] };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.fieldName = r.读取字符串();
        break;
      case 2:
        out.currentText = r.读取字符串();
        break;
      case 3:
        out.filters.push(r.读取字符串());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}

function decodeTemplateNode(bytes: Uint8Array): TemplateNode {
  const r = new 协议读取器(bytes);
  const node: TemplateNode = { text: null, replacement: null };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        node.text = r.读取字符串();
        break;
      case 2:
        node.replacement = decodeReplacement(r.读取字节());
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return node;
}

export function decodeRenderCardResponse(bytes: Uint8Array): RenderedCard {
  const r = new 协议读取器(bytes);
  const out: RenderedCard = {
    questionNodes: [],
    answerNodes: [],
    css: '',
    latexSvg: false,
    isEmpty: false
  };
  let tag;
  while ((tag = r.读取标签()) !== null) {
    switch (tag.字段号) {
      case 1:
        out.questionNodes.push(decodeTemplateNode(r.读取字节()));
        break;
      case 2:
        out.answerNodes.push(decodeTemplateNode(r.读取字节()));
        break;
      case 3:
        out.css = r.读取字符串();
        break;
      case 4:
        out.latexSvg = r.读取布尔();
        break;
      case 5:
        out.isEmpty = r.读取布尔();
        break;
      default:
        r.跳过字段(tag.线类型);
    }
  }
  return out;
}
