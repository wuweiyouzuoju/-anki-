// UTF-8 编解码（纯逻辑实现）。
// 不依赖 util.TextEncoder / @kit.ArkTS，保证同一份代码既能在 HarmonyOS 运行，
// 也能在 Node 单元测试中直接 import 验证。

export function utf8Encode(text: string): Uint8Array {
  const bytes: number[] = [];
  for (let i = 0; i < text.length; i++) {
    let code: number = text.charCodeAt(i);
    // 代理对：高代理 + 低代理合成完整码点
    if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length) {
      const low: number = text.charCodeAt(i + 1);
      if (low >= 0xdc00 && low <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00);
        i++;
      }
    }
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    } else {
      bytes.push(
        0xf0 | (code >> 18),
        0x80 | ((code >> 12) & 0x3f),
        0x80 | ((code >> 6) & 0x3f),
        0x80 | (code & 0x3f)
      );
    }
  }
  return new Uint8Array(bytes);
}

export function utf8Decode(bytes: Uint8Array): string {
  const codes: number[] = [];
  let i = 0;
  while (i < bytes.length) {
    const first: number = bytes[i];
    if (first < 0x80) {
      codes.push(first);
      i += 1;
    } else if ((first & 0xe0) === 0xc0 && i + 1 < bytes.length) {
      codes.push(((first & 0x1f) << 6) | (bytes[i + 1] & 0x3f));
      i += 2;
    } else if ((first & 0xf0) === 0xe0 && i + 2 < bytes.length) {
      codes.push(
        ((first & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f)
      );
      i += 3;
    } else if ((first & 0xf8) === 0xf0 && i + 3 < bytes.length) {
      const code: number =
        ((first & 0x07) << 18) |
        ((bytes[i + 1] & 0x3f) << 12) |
        ((bytes[i + 2] & 0x3f) << 6) |
        (bytes[i + 3] & 0x3f);
      // 转回 UTF-16 代理对
      codes.push(0xd800 + ((code - 0x10000) >> 10), 0xdc00 + ((code - 0x10000) & 0x3ff));
      i += 4;
    } else {
      // 非法序列：按 U+FFFD 处理并前进一个字节，避免死循环
      codes.push(0xfffd);
      i += 1;
    }
  }
  let text = '';
  const CHUNK = 8192;
  for (let start = 0; start < codes.length; start += CHUNK) {
    text += String.fromCharCode(...codes.slice(start, start + CHUNK));
  }
  return text;
}
