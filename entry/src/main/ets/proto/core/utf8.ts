// SPDX-License-Identifier: AGPL-3.0-or-later

export function UTF8编码(文本: string): Uint8Array {
  const 字节列表: number[] = [];
  for (let i = 0; i < 文本.length; i++) {
    let 码点: number = 文本.charCodeAt(i);
    if (码点 >= 0xd800 && 码点 <= 0xdbff && i + 1 < 文本.length) {
      const 低代理: number = 文本.charCodeAt(i + 1);
      if (低代理 >= 0xdc00 && 低代理 <= 0xdfff) {
        码点 = 0x10000 + ((码点 - 0xd800) << 10) + (低代理 - 0xdc00);
        i++;
      }
    }
    if (码点 < 0x80) {
      字节列表.push(码点);
    } else if (码点 < 0x800) {
      字节列表.push(0xc0 | (码点 >> 6), 0x80 | (码点 & 0x3f));
    } else if (码点 < 0x10000) {
      字节列表.push(0xe0 | (码点 >> 12), 0x80 | ((码点 >> 6) & 0x3f), 0x80 | (码点 & 0x3f));
    } else {
      字节列表.push(
        0xf0 | (码点 >> 18),
        0x80 | ((码点 >> 12) & 0x3f),
        0x80 | ((码点 >> 6) & 0x3f),
        0x80 | (码点 & 0x3f)
      );
    }
  }
  return new Uint8Array(字节列表);
}

export function UTF8解码(字节: Uint8Array): string {
  const 码点列表: number[] = [];
  let i = 0;
  while (i < 字节.length) {
    const 首字节: number = 字节[i];
    if (首字节 < 0x80) {
      码点列表.push(首字节);
      i += 1;
    } else if ((首字节 & 0xe0) === 0xc0 && i + 1 < 字节.length) {
      码点列表.push(((首字节 & 0x1f) << 6) | (字节[i + 1] & 0x3f));
      i += 2;
    } else if ((首字节 & 0xf0) === 0xe0 && i + 2 < 字节.length) {
      码点列表.push(
        ((首字节 & 0x0f) << 12) | ((字节[i + 1] & 0x3f) << 6) | (字节[i + 2] & 0x3f)
      );
      i += 3;
    } else if ((首字节 & 0xf8) === 0xf0 && i + 3 < 字节.length) {
      const 码点: number =
        ((首字节 & 0x07) << 18) |
        ((字节[i + 1] & 0x3f) << 12) |
        ((字节[i + 2] & 0x3f) << 6) |
        (字节[i + 3] & 0x3f);
      码点列表.push(0xd800 + ((码点 - 0x10000) >> 10), 0xdc00 + ((码点 - 0x10000) & 0x3ff));
      i += 4;
    } else {
      码点列表.push(0xfffd);
      i += 1;
    }
  }
  let 文本 = '';
  const 分块大小 = 8192;
  for (let 起点 = 0; 起点 < 码点列表.length; 起点 += 分块大小) {
    文本 += String.fromCharCode(...码点列表.slice(起点, 起点 + 分块大小));
  }
  return 文本;
}
