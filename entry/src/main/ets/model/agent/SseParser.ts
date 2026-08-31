// SPDX-License-Identifier: AGPL-3.0-or-later

/** 不依赖 HarmonyOS Kit 的增量 SSE 解析器。传输层负责把原始字节按到达顺序交给它。 */

export interface SseMessage {
  event: string;
  data: string;
  id: string;
  done: boolean;
}

function continuation(value: number): boolean {
  return value >= 0x80 && value <= 0xBF;
}

function appendCodePoint(value: number): string {
  if (value <= 0xFFFF) {
    return String.fromCharCode(value);
  }
  const adjusted: number = value - 0x10000;
  const high: number = 0xD800 + (adjusted >> 10);
  const low: number = 0xDC00 + (adjusted & 0x3FF);
  return String.fromCharCode(high, low);
}

/**
 * 在完整 SSE 行上解码 UTF-8。换行字节不会出现在 UTF-8 多字节字符内部，
 * 因而先按字节找行边界可以自然处理跨网络分片的字符。
 */
function decodeUtf8(bytes: Uint8Array): string {
  let output: string = '';
  let index: number = 0;
  while (index < bytes.length) {
    const first: number = bytes[index];
    if (first <= 0x7F) {
      output += String.fromCharCode(first);
      index += 1;
      continue;
    }
    if (first >= 0xC2 && first <= 0xDF && index + 1 < bytes.length) {
      const second: number = bytes[index + 1];
      if (continuation(second)) {
        output += appendCodePoint(((first & 0x1F) << 6) | (second & 0x3F));
        index += 2;
        continue;
      }
    }
    if (first >= 0xE0 && first <= 0xEF && index + 2 < bytes.length) {
      const second: number = bytes[index + 1];
      const third: number = bytes[index + 2];
      const validSecond: boolean = continuation(second) &&
        !(first === 0xE0 && second < 0xA0) &&
        !(first === 0xED && second > 0x9F);
      if (validSecond && continuation(third)) {
        output += appendCodePoint(
          ((first & 0x0F) << 12) | ((second & 0x3F) << 6) | (third & 0x3F)
        );
        index += 3;
        continue;
      }
    }
    if (first >= 0xF0 && first <= 0xF4 && index + 3 < bytes.length) {
      const second: number = bytes[index + 1];
      const third: number = bytes[index + 2];
      const fourth: number = bytes[index + 3];
      const validSecond: boolean = continuation(second) &&
        !(first === 0xF0 && second < 0x90) &&
        !(first === 0xF4 && second > 0x8F);
      if (validSecond && continuation(third) && continuation(fourth)) {
        output += appendCodePoint(
          ((first & 0x07) << 18) | ((second & 0x3F) << 12) |
          ((third & 0x3F) << 6) | (fourth & 0x3F)
        );
        index += 4;
        continue;
      }
    }
    output += '\uFFFD';
    index += 1;
  }
  return output;
}

function concatenate(left: Uint8Array, right: Uint8Array): Uint8Array {
  if (left.length === 0) {
    return right.slice();
  }
  const combined: Uint8Array = new Uint8Array(left.length + right.length);
  combined.set(left, 0);
  combined.set(right, left.length);
  return combined;
}

export class IncrementalSseParser {
  private pending: Uint8Array = new Uint8Array(0);
  private eventName: string = '';
  private eventId: string = '';
  private dataLines: string[] = [];
  private hasData: boolean = false;
  private firstLine: boolean = true;

  push(chunk: Uint8Array): SseMessage[] {
    if (chunk.length === 0) {
      return [];
    }
    this.pending = concatenate(this.pending, chunk);
    const messages: SseMessage[] = [];
    let lineStart: number = 0;
    let index: number = 0;
    while (index < this.pending.length) {
      if (this.pending[index] === 0x0A) {
        let lineEnd: number = index;
        if (lineEnd > lineStart && this.pending[lineEnd - 1] === 0x0D) {
          lineEnd -= 1;
        }
        this.acceptLine(decodeUtf8(this.pending.slice(lineStart, lineEnd)), messages);
        lineStart = index + 1;
      }
      index += 1;
    }
    this.pending = this.pending.slice(lineStart);
    return messages;
  }

  finish(): SseMessage[] {
    const messages: SseMessage[] = [];
    if (this.pending.length > 0) {
      let end: number = this.pending.length;
      if (this.pending[end - 1] === 0x0D) {
        end -= 1;
      }
      this.acceptLine(decodeUtf8(this.pending.slice(0, end)), messages);
      this.pending = new Uint8Array(0);
    }
    this.dispatch(messages);
    return messages;
  }

  reset(): void {
    this.pending = new Uint8Array(0);
    this.eventName = '';
    this.eventId = '';
    this.dataLines = [];
    this.hasData = false;
    this.firstLine = true;
  }

  private acceptLine(rawLine: string, messages: SseMessage[]): void {
    let line: string = rawLine;
    if (this.firstLine) {
      this.firstLine = false;
      if (line.length > 0 && line.charCodeAt(0) === 0xFEFF) {
        line = line.slice(1);
      }
    }
    if (line.length === 0) {
      this.dispatch(messages);
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    const colon: number = line.indexOf(':');
    const field: string = colon < 0 ? line : line.slice(0, colon);
    let value: string = colon < 0 ? '' : line.slice(colon + 1);
    if (value.startsWith(' ')) {
      value = value.slice(1);
    }
    if (field === 'data') {
      this.dataLines.push(value);
      this.hasData = true;
    } else if (field === 'event') {
      this.eventName = value;
    } else if (field === 'id' && value.indexOf('\u0000') < 0) {
      this.eventId = value;
    }
  }

  private dispatch(messages: SseMessage[]): void {
    if (this.hasData) {
      const joined: string = this.dataLines.join('\n');
      const done: boolean = joined.trim() === '[DONE]';
      messages.push({
        event: this.eventName,
        data: done ? '' : joined,
        id: this.eventId,
        done: done
      });
    }
    this.eventName = '';
    this.eventId = '';
    this.dataLines = [];
    this.hasData = false;
  }
}
