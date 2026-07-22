// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * 色阶生成工具（借鉴 ArcoDesign 色板算法，自行实现）。
 *
 * 灵感来源：ArcoDesign 色板生成算法（https://arco.design/palette/list）
 * 思路：从种子色（shade 6）出发，向浅向深各派生 5/4 档共 10 档色阶；
 *      每档通过 HSV 空间小幅调整色相/饱和度/明度，使色阶视觉过渡自然。
 * 本文件为借鉴思路重写，未直接复制 ArcoDesign 源码。
 *
 * 输出索引约定：
 * - shades[0] = shade 1（最浅，用于 container 背景等大面积极浅色）
 * - shades[5] = shade 6（种子色，primary 主色）
 * - shades[9] = shade 10（最深，用于深色模式 container 等）
 */

/** HSV 颜色（h:0-360, s:0-100, v:0-100）。 */
interface HsvColor {
  h: number;
  s: number;
  v: number;
}

/** 10 档色阶（索引 0=最浅，9=最深）。 */
export type ShadeScale = string[];

/** 由种子色派生的一组语义色（已根据 isDark 选档，可直接用于 UI 绑定）。 */
export interface SemanticColors {
  /** 主色（按钮、进度条、强调） */
  primary: string;
  /** hover 态（比 primary 略浅） */
  primaryHover: string;
  /** active/pressed 态（比 primary 略深） */
  primaryActive: string;
  /** 主色容器背景（极浅/极深，用作选中行底色、tag 底色等） */
  primaryContainer: string;
  /** 主色容器 hover 背景 */
  primaryContainerHover: string;
  /** 主色边框（选中边框、强调边框） */
  primaryBorder: string;
  /** 主色图标（与 primary 一致或略深，保证小尺寸清晰） */
  primaryIcon: string;
  /** 在浅色背景上的主色文字（比 primary 略深，保证 AA 对比度） */
  primaryText: string;
}

/** 完整色阶 + 语义色（一个主题在浅色或深色模式下的完整主色派生系）。 */
export interface ColorScale {
  shades: ShadeScale;
  semantic: SemanticColors;
}

// ===== Hex / RGB / HSV 互转（无依赖纯函数） =====

function hexToRgb(hex: string): [number, number, number] {
  let normalized: string = hex.trim();
  if (normalized.startsWith('#')) {
    normalized = normalized.slice(1);
  }
  if (normalized.length === 3) {
    // #abc → #aabbcc
    normalized = normalized.split('').map((c: string): string => c + c).join('');
  }
  const r: number = parseInt(normalized.slice(0, 2), 16);
  const g: number = parseInt(normalized.slice(2, 4), 16);
  const b: number = parseInt(normalized.slice(4, 6), 16);
  return [r, g, b];
}

function rgbToHex(r: number, g: number, b: number): string {
  const toHex = (n: number): string => {
    const clamped: number = Math.max(0, Math.min(255, Math.round(n)));
    const s: string = clamped.toString(16);
    return s.length === 1 ? '0' + s : s;
  };
  return '#' + toHex(r) + toHex(g) + toHex(b);
}

function rgbToHsv(r: number, g: number, b: number): HsvColor {
  const rf: number = r / 255;
  const gf: number = g / 255;
  const bf: number = b / 255;
  const max: number = Math.max(rf, gf, bf);
  const min: number = Math.min(rf, gf, bf);
  const delta: number = max - min;
  let h: number = 0;
  if (delta > 0) {
    if (max === rf) {
      h = ((gf - bf) / delta) % 6;
    } else if (max === gf) {
      h = (bf - rf) / delta + 2;
    } else {
      h = (rf - gf) / delta + 4;
    }
    h *= 60;
    if (h < 0) {
      h += 360;
    }
  }
  const s: number = max === 0 ? 0 : (delta / max) * 100;
  const v: number = max * 100;
  return { h, s, v };
}

function hsvToRgb(h: number, s: number, v: number): [number, number, number] {
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

// ===== ArcoDesign 风格的色阶生成算法 =====
// 阶梯常量取自 ArcoDesign 色板规范：
// - 色相每档微调 ±2°，暖色（0-60, 240-360）向浅向加，冷色（60-240）向浅向减
// - 浅色段饱和度每档 -16%，深色段每档 +5%（最末档 +16%）
// - 浅色段明度每档 +5%，深色段每档 -15%（最末档 -5%）

const HUE_STEP: number = 2;
const SAT_STEP_LIGHT: number = 16;
const SAT_STEP_DARK: number = 5;
const SAT_STEP_DARK_LAST: number = 16;
const VAL_STEP_LIGHT: number = 5;
const VAL_STEP_DARK: number = 15;
const VAL_STEP_DARK_LAST: number = 5;
const LIGHT_COUNT: number = 5;   // shade 1-5（浅色段）
const DARK_COUNT: number = 4;    // shade 7-10（深色段）

function shiftHue(hsv: HsvColor, i: number, light: boolean): number {
  // 暖色（h∈[0,60]∪[240,360]）：浅色段加色相、深色段减
  // 冷色（h∈(60,240)）：浅色段减色相、深色段加
  const isWarm: boolean = hsv.h <= 60 || hsv.h >= 240;
  let h: number;
  if (isWarm) {
    h = light ? hsv.h + HUE_STEP * i : hsv.h - HUE_STEP * i;
  } else {
    h = light ? hsv.h - HUE_STEP * i : hsv.h + HUE_STEP * i;
  }
  if (h < 0) {
    h += 360;
  }
  if (h >= 360) {
    h -= 360;
  }
  return h;
}

function shiftSaturation(hsv: HsvColor, i: number, light: boolean): number {
  let s: number;
  if (light) {
    s = hsv.s - SAT_STEP_LIGHT * i;
  } else if (i === DARK_COUNT) {
    s = hsv.s + SAT_STEP_DARK_LAST;
  } else {
    s = hsv.s + SAT_STEP_DARK * i;
  }
  return Math.max(0, Math.min(100, s));
}

function shiftValue(hsv: HsvColor, i: number, light: boolean): number {
  let v: number;
  if (light) {
    v = hsv.v + VAL_STEP_LIGHT * i;
  } else if (i === DARK_COUNT) {
    v = hsv.v - VAL_STEP_DARK_LAST;
  } else {
    v = hsv.v - VAL_STEP_DARK * i;
  }
  return Math.max(0, Math.min(100, v));
}

/**
 * 从种子色生成 10 档色阶（shade 1-10）。
 * shades[0]=shade1（最浅）、shades[5]=shade6（种子）、shades[9]=shade10（最深）。
 */
export function generateShades(seedHex: string): ShadeScale {
  const seedRgb: [number, number, number] = hexToRgb(seedHex);
  const seed: HsvColor = rgbToHsv(seedRgb[0], seedRgb[1], seedRgb[2]);
  const shades: string[] = [];

  // shade 1-5（浅色段，i 从 LIGHT_COUNT 递减到 1）
  for (let i: number = LIGHT_COUNT; i >= 1; i--) {
    const h: number = shiftHue(seed, i, true);
    const s: number = shiftSaturation(seed, i, true);
    const v: number = shiftValue(seed, i, true);
    const rgb: [number, number, number] = hsvToRgb(h, s, v);
    shades.push(rgbToHex(rgb[0], rgb[1], rgb[2]));
  }

  // shade 6（种子原色）
  shades.push(seedHex);

  // shade 7-10（深色段，i 从 1 到 DARK_COUNT）
  for (let i: number = 1; i <= DARK_COUNT; i++) {
    const h: number = shiftHue(seed, i, false);
    const s: number = shiftSaturation(seed, i, false);
    const v: number = shiftValue(seed, i, false);
    const rgb: [number, number, number] = hsvToRgb(h, s, v);
    shades.push(rgbToHex(rgb[0], rgb[1], rgb[2]));
  }

  return shades;
}

/**
 * 由种子色构建完整色阶 + 语义色（按 isDark 自动选档）。
 *
 * 浅色模式选档（参考 ArcoDesign light semantics）：
 * - primary = shade 6（种子）
 * - hover = shade 5、active = shade 7
 * - container = shade 1、containerHover = shade 2
 * - border = shade 3、icon = shade 6、text = shade 7
 *
 * 深色模式选档（参考 ArcoDesign dark semantics）：
 * - primary = shade 5（比浅色浅一档，保证暗背景上可读）
 * - hover = shade 4、active = shade 6
 * - container = shade 10、containerHover = shade 9
 * - border = shade 7、icon = shade 5、text = shade 5
 */
export function buildColorScale(seedHex: string, isDark: boolean): ColorScale {
  const shades: ShadeScale = generateShades(seedHex);
  if (isDark) {
    return {
      shades,
      semantic: {
        primary: shades[4],              // shade 5：暗背景上需更亮，比浅色 primary 浅一档
        primaryHover: shades[3],         // shade 4
        primaryActive: shades[5],        // shade 6
        primaryContainer: shades[9],     // shade 10（深色容器）
        primaryContainerHover: shades[8],// shade 9
        primaryBorder: shades[6],        // shade 7
        primaryIcon: shades[4],          // shade 5
        primaryText: shades[4]           // shade 5
      }
    };
  }
  return {
    shades,
    semantic: {
      primary: shades[5],                // shade 6 = 种子
      primaryHover: shades[4],           // shade 5
      primaryActive: shades[6],          // shade 7
      primaryContainer: shades[1],       // shade 2（原 shade 1 对蓝/紫饱和度被减到 0%=纯白，选中态不可见）
      primaryContainerHover: shades[2],  // shade 3（原 shade 2，跟随 container 上移一档）
      primaryBorder: shades[2],          // shade 3
      primaryIcon: shades[5],            // shade 6
      primaryText: shades[6]             // shade 7（文字略深保证对比度）
    }
  };
}
