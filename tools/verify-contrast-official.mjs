// 华为官方无障碍规范补测脚本（基于 verify-contrast.mjs 扩展）
// 补测 verify-contrast.mjs 未覆盖的华为官方额外要求：
//   1. 深色模式非大字号主要文本 ≥5:1（华为比 WCAG 4.5:1 更严格）
//   2. 可交互控件背板 vs 页面背景 ≥2.2:1（华为独有）
//   3. 相邻颜色色彩差异 △Euv ≥20（华为 ISO9421-307 标准，含色盲群体）
//   4. 舒适性上限：深色模式文字对比度 ≤17.6:1；图标背板 ≤15.7:1
// 用法：node tools/verify-contrast-official.mjs
// 完成后可删除。

// ===== 从 verify-contrast.mjs 复制的核心函数（保持算法一致） =====
function 十六进制转RGB(hex) {
  let s = hex.trim();
  if (s.startsWith('#')) s = s.slice(1);
  if (s.length === 3) s = s.split('').map(c => c + c).join('');
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function RGB转十六进制(r, g, b) {
  const 转 = n => {
    const x = Math.max(0, Math.min(255, Math.round(n)));
    const h = x.toString(16);
    return h.length === 1 ? '0' + h : h;
  };
  return '#' + 转(r) + 转(g) + 转(b);
}
function sRGB通道转线性亮度(c) {
  const cs = c / 255;
  return cs <= 0.03928 ? cs / 12.92 : Math.pow((cs + 0.055) / 1.055, 2.4);
}
function 相对亮度(hex) {
  const [r, g, b] = 十六进制转RGB(hex);
  return 0.2126 * sRGB通道转线性亮度(r) + 0.7152 * sRGB通道转线性亮度(g) + 0.0722 * sRGB通道转线性亮度(b);
}
function 对比度(a, b) {
  const 亮a = 相对亮度(a);
  const 亮b = 相对亮度(b);
  return (Math.max(亮a, 亮b) + 0.05) / (Math.min(亮a, 亮b) + 0.05);
}
function RGB转HSV(r, g, b) {
  const rf = r/255, gf = g/255, bf = b/255;
  const 最大 = Math.max(rf, gf, bf);
  const 最小 = Math.min(rf, gf, bf);
  const 差值 = 最大 - 最小;
  let h = 0;
  if (差值 > 0) {
    if (最大 === rf) h = ((gf - bf) / 差值) % 6;
    else if (最大 === gf) h = (bf - rf) / 差值 + 2;
    else h = (rf - gf) / 差值 + 4;
    h *= 60;
    if (h < 0) h += 360;
  }
  const s = 最大 === 0 ? 0 : (差值 / 最大) * 100;
  const v = 最大 * 100;
  return { 色相: h, 饱和度: s, 明度: v };
}
function HSV转RGB(h, s, v) {
  const sf = s/100, vf = v/100;
  const c = vf * sf;
  const hp = h / 60;
  const x = c * (1 - Math.abs(hp % 2 - 1));
  const m = vf - c;
  let r=0, g=0, b=0;
  if (hp >= 0 && hp < 1) { r=c; g=x; b=0; }
  else if (hp < 2) { r=x; g=c; b=0; }
  else if (hp < 3) { r=0; g=c; b=x; }
  else if (hp < 4) { r=0; g=x; b=c; }
  else if (hp < 5) { r=x; g=0; b=c; }
  else { r=c; g=0; b=x; }
  return [(r+m)*255, (g+m)*255, (b+m)*255];
}
const 色相步长 = 2, 浅色段饱和度步长 = 16, 深色段饱和度步长 = 5, 深色段末档饱和度步长 = 16;
const 浅色段明度步长 = 5, 深色段明度步长 = 15, 深色段末档明度步长 = 5;
const 浅色段档数 = 5, 深色段档数 = 4;
function 偏移色相(hsv, i, 浅色段) {
  const 是暖色 = hsv.色相 <= 60 || hsv.色相 >= 240;
  let h = 是暖色 ? (浅色段 ? hsv.色相 + 色相步长 * i : hsv.色相 - 色相步长 * i)
                : (浅色段 ? hsv.色相 - 色相步长 * i : hsv.色相 + 色相步长 * i);
  if (h < 0) h += 360;
  if (h >= 360) h -= 360;
  return h;
}
function 偏移饱和度(hsv, i, 浅色段) {
  let s;
  if (浅色段) s = hsv.饱和度 - 浅色段饱和度步长 * i;
  else if (i === 深色段档数) s = hsv.饱和度 + 深色段末档饱和度步长;
  else s = hsv.饱和度 + 深色段饱和度步长 * i;
  return Math.max(0, Math.min(100, s));
}
function 偏移明度(hsv, i, 浅色段) {
  let v;
  if (浅色段) v = hsv.明度 + 浅色段明度步长 * i;
  else if (i === 深色段档数) v = hsv.明度 - 深色段末档明度步长;
  else v = hsv.明度 - 深色段明度步长 * i;
  return Math.max(0, Math.min(100, v));
}
function 生成色阶(种子hex) {
  const [r, g, b] = 十六进制转RGB(种子hex);
  const 种子 = RGB转HSV(r, g, b);
  const 色阶 = [];
  for (let i = 浅色段档数; i >= 1; i--) {
    const [rr, gg, bb] = HSV转RGB(偏移色相(种子, i, true), 偏移饱和度(种子, i, true), 偏移明度(种子, i, true));
    色阶.push(RGB转十六进制(rr, gg, bb));
  }
  色阶.push(种子hex);
  for (let i = 1; i <= 深色段档数; i++) {
    const [rr, gg, bb] = HSV转RGB(偏移色相(种子, i, false), 偏移饱和度(种子, i, false), 偏移明度(种子, i, false));
    色阶.push(RGB转十六进制(rr, gg, bb));
  }
  return 色阶;
}
function 选取白字达标档索引(色阶, 起始索引) {
  for (let i = 起始索引; i < 色阶.length; i++) {
    if (对比度('#FFFFFF', 色阶[i]) >= 4.5) return i;
  }
  return 色阶.length - 1;
}
function 选取对比度达标档索引(色阶, 起始索引, 参考色, 阈值, 向深档) {
  if (向深档) {
    for (let i = 起始索引; i < 色阶.length; i++) {
      if (对比度(参考色, 色阶[i]) >= 阈值) return i;
    }
    return 色阶.length - 1;
  }
  for (let i = 起始索引; i >= 0; i--) {
    if (对比度(参考色, 色阶[i]) >= 阈值) return i;
  }
  return 0;
}
const 浅色卡片底色 = '#FFFFFF';
const 深色卡片底色 = '#18202B';
function 构建完整色阶(种子hex, 是否深色) {
  const 色阶 = 生成色阶(种子hex);
  if (是否深色) {
    const 按钮档索引 = 选取白字达标档索引(色阶, 4);
    const 按钮按下档索引 = Math.min(按钮档索引 + 1, 色阶.length - 1);
    const 主色文字档索引 = 选取对比度达标档索引(色阶, 4, 深色卡片底色, 4.5, false);
    const 主色边框档索引 = 选取对比度达标档索引(色阶, 6, 深色卡片底色, 3, false);
    return {
      色阶,
      语义: {
        主色: 色阶[4], 主色悬停: 色阶[3], 主色按下: 色阶[5],
        按钮背景主色: 色阶[按钮档索引], 按钮背景按下: 色阶[按钮按下档索引],
        主色容器: 色阶[9], 主色容器悬停: 色阶[8],
        主色边框: 色阶[主色边框档索引], 主色图标: 色阶[4], 主色文字: 色阶[主色文字档索引]
      }
    };
  }
  const 按钮档索引浅色 = 选取白字达标档索引(色阶, 5);
  const 按钮按下档索引浅色 = Math.min(按钮档索引浅色 + 1, 色阶.length - 1);
  const 主色文字档索引浅色 = 选取对比度达标档索引(色阶, 6, 浅色卡片底色, 4.5, true);
  const 主色图标档索引浅色 = 选取对比度达标档索引(色阶, 5, 浅色卡片底色, 3, true);
  const 主色边框档索引浅色 = 选取对比度达标档索引(色阶, 2, 浅色卡片底色, 3, true);
  return {
    色阶,
    语义: {
      主色: 色阶[5], 主色悬停: 色阶[4], 主色按下: 色阶[6],
      按钮背景主色: 色阶[按钮档索引浅色], 按钮背景按下: 色阶[按钮按下档索引浅色],
      主色容器: 色阶[1], 主色容器悬停: 色阶[2],
      主色边框: 色阶[主色边框档索引浅色], 主色图标: 色阶[主色图标档索引浅色],
      主色文字: 色阶[主色文字档索引浅色]
    }
  };
}
function 混合十六进制色(背景色, 前景色, alpha) {
  const [br, bg, bb] = 十六进制转RGB(背景色);
  const [fr, fg, fb] = 十六进制转RGB(前景色);
  return RGB转十六进制(
    Math.round(fr * alpha + br * (1 - alpha)),
    Math.round(fg * alpha + bg * (1 - alpha)),
    Math.round(fb * alpha + bb * (1 - alpha))
  );
}
const 浅色页面底色 = '#F5F7FA';
const 深色页面底色 = '#10151D';
function 取主题种子色(主题) {
  switch (主题) {
    case 'aurora': return '#2F5FD0';
    case 'forest': return '#00B42A';
    case 'midnight': return '#722ED1';
    case 'lagoon': return '#14C9C9';
    case 'sunset': return '#FF7D00';
    case 'lemon': return '#F7BA1E';
    case 'minimal_gray': return '#595959';
    default: return '#2F5FD0';
  }
}
function 解析主题色板(主题, 是否深色) {
  const 新卡计数色 = 是否深色 ? '#7C9AE8' : '#366ECE';
  const 学习中计数色 = 是否深色 ? '#E6A45F' : '#A05D1C';
  const 复习中计数色 = 是否深色 ? '#B2A0F2' : '#7056C8';
  if (主题 === 'minimal_gray') {
    return 是否深色 ? {
      动作主色: '#BFBFBF', 动作主色悬停: '#D9D9D9', 动作主色按下: '#A6A6A6',
      主色按钮背景: '#595959', 主色按钮按下: '#4A4A4A',
      选中背景: 深色卡片底色, 主色容器: '#2A2A2A', 主色容器悬停: '#333333',
      主色边框: '#6B6B6B', 主色图标: '#BFBFBF', 主色文字: '#CCCCCC',
      新卡计数色, 学习中计数色, 复习中计数色,
      热力1: '#2A2A2A', 热力2: '#3D3D3D', 热力3: '#4D4D4D', 热力4: '#595959',
      页面底色微染: 混合十六进制色(深色页面底色, '#BFBFBF', 0.10)
    } : {
      动作主色: '#4A4A4A', 动作主色悬停: '#595959', 动作主色按下: '#3D3D3D',
      主色按钮背景: '#4A4A4A', 主色按钮按下: '#3D3D3D',
      选中背景: '#E8E8E8', 主色容器: '#E8E8E8', 主色容器悬停: '#DCDCDC',
      主色边框: '#8C8C8C', 主色图标: '#4A4A4A', 主色文字: '#3D3D3D',
      新卡计数色, 学习中计数色, 复习中计数色,
      热力1: '#BFBFBF', 热力2: '#A6A6A6', 热力3: '#8C8C8C', 热力4: '#4A4A4A',
      页面底色微染: 混合十六进制色(浅色页面底色, '#4A4A4A', 0.06)
    };
  }
  const 种子 = 取主题种子色(主题);
  const 色阶 = 构建完整色阶(种子, 是否深色);
  const 语义 = 色阶.语义;
  const 马卡龙白 = '#FFFFFF';
  const 原始容器色 = 是否深色 ? 色阶.色阶[3] : 语义.主色容器;
  const 原始容器悬停色 = 是否深色 ? 色阶.色阶[2] : 语义.主色容器悬停;
  const 容器色 = 是否深色 ? 混合十六进制色(马卡龙白, 原始容器色, 0.65) : 原始容器色;
  const 容器悬停色 = 是否深色 ? 混合十六进制色(马卡龙白, 原始容器悬停色, 0.65) : 原始容器悬停色;
  const 浅色主文本色 = '#182230';
  const 热力3档索引浅色 = 选取对比度达标档索引(色阶.色阶, 4, 浅色主文本色, 4.5, false);
  const 热力3档索引最终 = Math.max(3, 热力3档索引浅色);
  return {
    动作主色: 语义.主色, 动作主色悬停: 语义.主色悬停, 动作主色按下: 语义.主色按下,
    主色按钮背景: 语义.按钮背景主色, 主色按钮按下: 语义.按钮背景按下,
    主色容器: 容器色, 主色容器悬停: 容器悬停色,
    主色边框: 语义.主色边框, 主色图标: 语义.主色图标, 主色文字: 语义.主色文字,
    选中背景: 是否深色 ? 深色卡片底色 : 容器色,
    新卡计数色, 学习中计数色, 复习中计数色,
    热力1: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.02) : 色阶.色阶[1],
    热力2: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.31) : 色阶.色阶[2],
    热力3: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.63) : 色阶.色阶[热力3档索引最终],
    热力4: 语义.按钮背景主色,
    页面底色微染: 混合十六进制色(是否深色 ? 深色页面底色 : 浅色页面底色, 语义.主色, 是否深色 ? 0.10 : 0.06)
  };
}

// ===== 华为官方补测：CIE Lu*v* 色彩差异 △Euv（ISO9421-307） =====
// sRGB → linear RGB → XYZ（D65）→ CIE Luv → △Euv
function sRGB转线性(c) {
  const cs = c / 255;
  return cs <= 0.04045 ? cs / 12.92 : Math.pow((cs + 0.055) / 1.055, 2.4);
}
function 转XYZ(hex) {
  const [r, g, b] = 十六进制转RGB(hex);
  const R = sRGB转线性(r), G = sRGB转线性(g), B = sRGB转线性(b);
  // sRGB → XYZ(D65) 矩阵
  const X = 0.4124564 * R + 0.3575761 * G + 0.1804375 * B;
  const Y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * B;
  const Z = 0.0193339 * R + 0.1191920 * G + 0.9503041 * B;
  return [X * 100, Y * 100, Z * 100];
}
// D65 参考白点
const Xn = 95.047, Yn = 100.0, Zn = 108.883;
const un_ = 4 * Xn / (Xn + 15 * Yn + 3 * Zn);   // 0.19783
const vn_ = 9 * Yn / (Xn + 15 * Yn + 3 * Zn);   // 0.46834
function 转CIELuv(hex) {
  const [X, Y, Z] = 转XYZ(hex);
  // L* 公式
  const yr = Y / Yn;
  const L = yr > Math.pow(6 / 29, 3) ? 116 * Math.cbrt(yr) - 16 : Math.pow(29 / 3, 3) * yr;
  const d = X + 15 * Y + 3 * Z;
  const u_ = d === 0 ? 0 : 4 * X / d;
  const v_ = d === 0 ? 0 : 9 * Y / d;
  const u = 13 * L * (u_ - un_);
  const v = 13 * L * (v_ - vn_);
  return { L, u, v };
}
function 色彩差异Euv(hex1, hex2) {
  const a = 转CIELuv(hex1);
  const b = 转CIELuv(hex2);
  return Math.sqrt(Math.pow(a.L - b.L, 2) + Math.pow(a.u - b.u, 2) + Math.pow(a.v - b.v, 2));
}

const 浅色文本 = {
  text_primary: '#182230', text_secondary: '#667085',
  error_text: '#D92D20', surface_page: '#F5F7FA', surface_card: '#FFFFFF'
};
const 深色文本 = {
  text_primary: '#F1F5F9', text_secondary: '#B8C1CE',
  error_text: '#F97066', surface_page: '#10151D', surface_card: '#18202B'
};

const 主题列表 = ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon', 'minimal_gray'];
const 主题中文名 = {
  aurora: '极光蓝', forest: '仙野绿', midnight: '暗夜紫',
  lagoon: '碧涛青', sunset: '活力橙', lemon: '柠檬金', minimal_gray: '极简灰'
};

let 有问题 = false;
let 问题清单 = [];

console.log('========== 华为官方无障碍规范补测 ==========\n');

for (const 主题 of 主题列表) {
  for (const 是否深色 of [false, true]) {
    const 色板 = 解析主题色板(主题, 是否深色);
    const 文本 = 是否深色 ? 深色文本 : 浅色文本;
    const 模式名 = 是否深色 ? '深色' : '浅色';
    const 卡片底 = 文本.surface_card;
    const 页面底 = 文本.surface_page;

    console.log(`\n--- ${主题中文名[主题]} (${模式名}) ---`);

    const 检查 = (前景, 背景, 阈值, 标签, 类型 = 'min') => {
      const r = 对比度(前景, 背景);
      // 类型 min: 必须 ≥ 阈值；max: 必须 ≤ 阈值（舒适性上限）
      const ok = 类型 === 'max' ? r <= 阈值 : r >= 阈值;
      if (!ok) {
        有问题 = true;
        问题清单.push(`${主题中文名[主题]}-${模式名}: ${标签} ${前景}/${背景} = ${r.toFixed(2)} (需${类型 === 'max' ? '≤' : '≥'}${阈值})`);
      }
      console.log(`  ${标签}: ${r.toFixed(2)} ${ok ? '✓' : '✗'}`);
    };

    // 1. 深色模式非大字号主要文本 ≥5:1（华为比 WCAG 4.5:1 更严格）
    //    适用：主色文字、text_primary、text_secondary、error_text、三个计数色（这些是作为文本/数字显示在卡片底）
    if (是否深色) {
      检查(色板.主色文字, 卡片底, 5, `【华为深色5:1】主色文字 ${色板.主色文字}/卡片底`);
      检查(文本.text_primary, 卡片底, 5, `【华为深色5:1】text_primary/卡片底`);
      检查(文本.text_secondary, 卡片底, 5, `【华为深色5:1】text_secondary/卡片底`);
      检查(文本.error_text, 卡片底, 5, `【华为深色5:1】error_text/卡片底`);
      检查(色板.新卡计数色, 卡片底, 5, `【华为深色5:1】新卡计数色`);
      检查(色板.学习中计数色, 卡片底, 5, `【华为深色5:1】学习中计数色`);
      检查(色板.复习中计数色, 卡片底, 5, `【华为深色5:1】复习中计数色`);
      // 热力1作为背景配 text_primary ≥5:1（深色主要文本）
      检查(文本.text_primary, 色板.热力1, 5, `【华为深色5:1】text_primary/热力1`);
      检查(文本.text_primary, 色板.热力2, 5, `【华为深色5:1】text_primary/热力2`);
      检查(文本.text_primary, 色板.热力3, 5, `【华为深色5:1】text_primary/热力3`);
    }

    // 2. 可交互控件背板 vs 页面背景 ≥2.2:1（华为独有，WCAG 无此项）
    //    适用：主色按钮背景（按钮主色块）、主色容器（选中态底色）
    检查(色板.主色按钮背景, 页面底, 2.2, `【华为控件背板2.2:1】主色按钮背景/页面底`);
    检查(色板.主色容器, 页面底, 2.2, `【华为控件背板2.2:1】主色容器/页面底`);
    // 热力4 作为热力图最深档背景，需与页面底区分（背板对比度）
    检查(色板.热力4, 页面底, 2.2, `【华为控件背板2.2:1】热力4/页面底`);

    // 3. 舒适性上限：深色模式文字对比度 ≤17.6:1（华为独有）
    //    适用：text_primary vs 卡片底（最强的文字对比度）
    if (是否深色) {
      检查(文本.text_primary, 卡片底, 17.6, `【华为舒适性上限17.6:1】text_primary/卡片底`, 'max');
      // 图标背板对比度 ≤15.7:1（深色模式小图标背板建议）
      // 主色图标与卡片底的对比度，作为功能性图标参考
      检查(色板.主色图标, 卡片底, 15.7, `【华为图标背板上限15.7:1】主色图标/卡片底`, 'max');
    }
  }
}

// 4. 相邻颜色色彩差异 △Euv ≥20（华为 ISO9421-307，含色盲群体无障碍要求）
//    适用：三个计数色（蓝/橙/紫，相邻显示如卡片状态栏）、热力1-4 色阶（相邻渐变）
console.log('\n\n========== 色彩差异 △Euv ≥20 ==========\n');
for (const 主题 of 主题列表) {
  for (const 是否深色 of [false, true]) {
    const 色板 = 解析主题色板(主题, 是否深色);
    const 模式名 = 是否深色 ? '深色' : '浅色';
    console.log(`\n--- ${主题中文名[主题]} (${模式名}) ---`);

    const 检查差异 = (色1, 色2, 标签) => {
      const e = 色彩差异Euv(色1, 色2);
      const ok = e >= 20;
      if (!ok) {
        有问题 = true;
        问题清单.push(`${主题中文名[主题]}-${模式名}: ${标签} ${色1}/${色2} △Euv=${e.toFixed(2)} (需≥20)`);
      }
      console.log(`  ${标签}: △Euv=${e.toFixed(2)} ${ok ? '✓' : '✗'}`);
    };

    // 三个计数色两两差异（卡片状态显示时相邻）
    检查差异(色板.新卡计数色, 色板.学习中计数色, '新卡↔学习');
    检查差异(色板.新卡计数色, 色板.复习中计数色, '新卡↔复习');
    检查差异(色板.学习中计数色, 色板.复习中计数色, '学习↔复习');

    // 热力1-4 相邻色阶差异（GitHub 风格热力图相邻档）
    检查差异(色板.热力1, 色板.热力2, '热力1↔热力2');
    检查差异(色板.热力2, 色板.热力3, '热力2↔热力3');
    检查差异(色板.热力3, 色板.热力4, '热力3↔热力4');
  }
}

console.log('\n\n========================================');
console.log(有问题 ? '⚠ 仍有不达标项：' : '✓ 华为官方规范全部达标');
if (有问题) 问题清单.forEach(p => console.log('  - ' + p));
