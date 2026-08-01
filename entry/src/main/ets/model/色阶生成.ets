// SPDX-License-Identifier: AGPL-3.0-or-later

interface HSV颜色 {
  色相: number;
  饱和度: number;
  明度: number;
}

export type 色阶数组 = string[];

export interface 语义色集合 {
  主色: string;
  主色悬停: string;
  主色按下: string;
  按钮背景主色: string;
  按钮背景按下: string;
  主色容器: string;
  主色容器悬停: string;
  主色边框: string;
  主色图标: string;
  主色文字: string;
}

export interface 完整色阶 {
  色阶: 色阶数组;
  语义: 语义色集合;
}

function 十六进制转RGB(hex: string): [number, number, number] {
  let 规范化: string = hex.trim();
  if (规范化.startsWith('#')) {
    规范化 = 规范化.slice(1);
  }
  if (规范化.length === 3) {
    规范化 = 规范化.split('').map((c: string): string => c + c).join('');
  }
  const r: number = parseInt(规范化.slice(0, 2), 16);
  const g: number = parseInt(规范化.slice(2, 4), 16);
  const b: number = parseInt(规范化.slice(4, 6), 16);
  return [r, g, b];
}

function RGB转十六进制(r: number, g: number, b: number): string {
  const 转换 = (n: number): string => {
    const 限定: number = Math.max(0, Math.min(255, Math.round(n)));
    const s: string = 限定.toString(16);
    return s.length === 1 ? '0' + s : s;
  };
  return '#' + 转换(r) + 转换(g) + 转换(b);
}

function sRGB通道转线性亮度(c: number): number {
  const cs: number = c / 255;
  return cs <= 0.03928 ? cs / 12.92 : Math.pow((cs + 0.055) / 1.055, 2.4);
}

function 相对亮度(hex: string): number {
  const rgb: [number, number, number] = 十六进制转RGB(hex);
  return 0.2126 * sRGB通道转线性亮度(rgb[0])
    + 0.7152 * sRGB通道转线性亮度(rgb[1])
    + 0.0722 * sRGB通道转线性亮度(rgb[2]);
}

function 对比度(a: string, b: string): number {
  const 亮a: number = 相对亮度(a);
  const 亮b: number = 相对亮度(b);
  const 较亮: number = Math.max(亮a, 亮b);
  const 较暗: number = Math.min(亮a, 亮b);
  return (较亮 + 0.05) / (较暗 + 0.05);
}

function 选取白字达标档索引(色阶: 色阶数组, 起始索引: number): number {
  for (let i: number = 起始索引; i < 色阶.length; i++) {
    if (对比度('#FFFFFF', 色阶[i]) >= 4.5) {
      return i;
    }
  }
  return 色阶.length - 1;
}

function RGB转HSV(r: number, g: number, b: number): HSV颜色 {
  const rf: number = r / 255;
  const gf: number = g / 255;
  const bf: number = b / 255;
  const 最大: number = Math.max(rf, gf, bf);
  const 最小: number = Math.min(rf, gf, bf);
  const 差值: number = 最大 - 最小;
  let h: number = 0;
  if (差值 > 0) {
    if (最大 === rf) {
      h = ((gf - bf) / 差值) % 6;
    } else if (最大 === gf) {
      h = (bf - rf) / 差值 + 2;
    } else {
      h = (rf - gf) / 差值 + 4;
    }
    h *= 60;
    if (h < 0) {
      h += 360;
    }
  }
  const s: number = 最大 === 0 ? 0 : (差值 / 最大) * 100;
  const v: number = 最大 * 100;
  return { 色相: h, 饱和度: s, 明度: v };
}

function HSV转RGB(h: number, s: number, v: number): [number, number, number] {
  const sf: number = s / 100;
  const vf: number = v / 100;
  const c: number = vf * sf;
  const hp: number = h / 60;
  const x: number = c * (1 - Math.abs(hp % 2 - 1));
  const m: number = vf - c;
  let r: number = 0;
  let g: number = 0;
  let b: number = 0;
  if (hp >= 0 && hp < 1) {
    r = c; g = x; b = 0;
  } else if (hp < 2) {
    r = x; g = c; b = 0;
  } else if (hp < 3) {
    r = 0; g = c; b = x;
  } else if (hp < 4) {
    r = 0; g = x; b = c;
  } else if (hp < 5) {
    r = x; g = 0; b = c;
  } else {
    r = c; g = 0; b = x;
  }
  return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
}

const 色相步长: number = 2;
const 浅色段饱和度步长: number = 16;
const 深色段饱和度步长: number = 5;
const 深色段末档饱和度步长: number = 16;
const 浅色段明度步长: number = 5;
const 深色段明度步长: number = 15;
const 深色段末档明度步长: number = 5;
const 浅色段档数: number = 5;
const 深色段档数: number = 4;

function 偏移色相(hsv: HSV颜色, i: number, 浅色段: boolean): number {
  const 是暖色: boolean = hsv.色相 <= 60 || hsv.色相 >= 240;
  let h: number;
  if (是暖色) {
    h = 浅色段 ? hsv.色相 + 色相步长 * i : hsv.色相 - 色相步长 * i;
  } else {
    h = 浅色段 ? hsv.色相 - 色相步长 * i : hsv.色相 + 色相步长 * i;
  }
  if (h < 0) {
    h += 360;
  }
  if (h >= 360) {
    h -= 360;
  }
  return h;
}

function 偏移饱和度(hsv: HSV颜色, i: number, 浅色段: boolean): number {
  let s: number;
  if (浅色段) {
    s = hsv.饱和度 - 浅色段饱和度步长 * i;
  } else if (i === 深色段档数) {
    s = hsv.饱和度 + 深色段末档饱和度步长;
  } else {
    s = hsv.饱和度 + 深色段饱和度步长 * i;
  }
  return Math.max(0, Math.min(100, s));
}

function 偏移明度(hsv: HSV颜色, i: number, 浅色段: boolean): number {
  let v: number;
  if (浅色段) {
    v = hsv.明度 + 浅色段明度步长 * i;
  } else if (i === 深色段档数) {
    v = hsv.明度 - 深色段末档明度步长;
  } else {
    v = hsv.明度 - 深色段明度步长 * i;
  }
  return Math.max(0, Math.min(100, v));
}

export function 生成色阶(种子hex: string): 色阶数组 {
  const 种子rgb: [number, number, number] = 十六进制转RGB(种子hex);
  const 种子: HSV颜色 = RGB转HSV(种子rgb[0], 种子rgb[1], 种子rgb[2]);
  const 色阶: string[] = [];

  for (let i: number = 浅色段档数; i >= 1; i--) {
    const h: number = 偏移色相(种子, i, true);
    const s: number = 偏移饱和度(种子, i, true);
    const v: number = 偏移明度(种子, i, true);
    const rgb: [number, number, number] = HSV转RGB(h, s, v);
    色阶.push(RGB转十六进制(rgb[0], rgb[1], rgb[2]));
  }

  色阶.push(种子hex);

  for (let i: number = 1; i <= 深色段档数; i++) {
    const h: number = 偏移色相(种子, i, false);
    const s: number = 偏移饱和度(种子, i, false);
    const v: number = 偏移明度(种子, i, false);
    const rgb: [number, number, number] = HSV转RGB(h, s, v);
    色阶.push(RGB转十六进制(rgb[0], rgb[1], rgb[2]));
  }

  return 色阶;
}

export function 构建完整色阶(种子hex: string, 是否深色: boolean): 完整色阶 {
  const 色阶: 色阶数组 = 生成色阶(种子hex);
  if (是否深色) {
    const 按钮档索引: number = 选取白字达标档索引(色阶, 4);
    const 按钮按下档索引: number = Math.min(按钮档索引 + 1, 色阶.length - 1);
    return {
      色阶,
      语义: {
        主色: 色阶[4],
        主色悬停: 色阶[3],
        主色按下: 色阶[5],
        按钮背景主色: 色阶[按钮档索引],
        按钮背景按下: 色阶[按钮按下档索引],
        主色容器: 色阶[9],
        主色容器悬停: 色阶[8],
        主色边框: 色阶[6],
        主色图标: 色阶[4],
        主色文字: 色阶[4]
      }
    };
  }
  const 按钮档索引浅色: number = 选取白字达标档索引(色阶, 5);
  const 按钮按下档索引浅色: number = Math.min(按钮档索引浅色 + 1, 色阶.length - 1);
  return {
    色阶,
    语义: {
      主色: 色阶[5],
      主色悬停: 色阶[4],
      主色按下: 色阶[6],
      按钮背景主色: 色阶[按钮档索引浅色],
      按钮背景按下: 色阶[按钮按下档索引浅色],
      主色容器: 色阶[1],
      主色容器悬停: 色阶[2],
      主色边框: 色阶[2],
      主色图标: 色阶[5],
      主色文字: 色阶[6]
    }
  };
}
