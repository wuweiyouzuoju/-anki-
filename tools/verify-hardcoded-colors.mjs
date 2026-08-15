// 硬编码色值对比度审计脚本
// 扫描 components/ 和 pages/ 下所有 .ets 文件，提取硬编码色值，
// 按用途分类计算 WCAG 对比度，报告不达标项与需人工复核项。
// 用法：在项目根目录执行 node tools/verify-hardcoded-colors.mjs
// 仅做审计，不修改任何 .ets 源码。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const 项目根 = path.resolve(__dirname, '..');

const 扫描根列表 = [
  path.join(项目根, 'entry/src/main/ets/components'),
  path.join(项目根, 'entry/src/main/ets/pages'),
];

// 已知背景色
const 浅色卡片底 = '#FFFFFF';
const 深色卡片底 = '#18202B';

// ===================== WCAG 对比度计算 =====================
function 十六进制转RGB(hex) {
  let s = hex.trim();
  if (s.startsWith('#')) s = s.slice(1);
  // 8 位 hex（#RRGGBBAA），只取 RGB 部分
  if (s.length === 8) s = s.slice(0, 6);
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

// 向深或向浅方向调整色值到达标；返回达标色或 null
function 调整达标(色值, 背景, 阈值, 向深) {
  let [r, g, b] = 十六进制转RGB(色值);
  for (let i = 0; i < 512; i++) {
    if (对比度(RGB转十六进制(r, g, b), 背景) >= 阈值) {
      return RGB转十六进制(r, g, b);
    }
    if (向深) {
      if (r === 0 && g === 0 && b === 0) break;
      r = Math.max(0, r - 1);
      g = Math.max(0, g - 1);
      b = Math.max(0, b - 1);
    } else {
      if (r === 255 && g === 255 && b === 255) break;
      r = Math.min(255, r + 1);
      g = Math.min(255, g + 1);
      b = Math.min(255, b + 1);
    }
  }
  return null;
}

// ===================== rgba 解析 =====================
function 解析rgba(字符串) {
  const m = 字符串.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)/i);
  if (!m) return null;
  return { r: +m[1], g: +m[2], b: +m[3], a: m[4] !== undefined ? +m[4] : 1 };
}
function 是遮罩色(rgba) {
  // 黑色或白色透明覆盖层
  return (rgba.r === 0 && rgba.g === 0 && rgba.b === 0) ||
         (rgba.r === 255 && rgba.g === 255 && rgba.b === 255);
}

// ===================== 文件扫描 =====================
function 递归扫描(根) {
  const 结果 = [];
  function 扫(目录) {
    const 项 = fs.readdirSync(目录, { withFileTypes: true });
    for (const e of 项) {
      const 全 = path.join(目录, e.name);
      if (e.isDirectory()) 扫(全);
      else if (e.isFile() && e.name.endsWith('.ets')) 结果.push(全);
    }
  }
  扫(根);
  return 结果;
}

// ===================== 色值提取 =====================
// 8 位优先于 6 位优先于 3 位，避免误匹配
const hex正则 = /#[0-9A-Fa-f]{8}\b|#[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{3}\b/g;
const rgba正则 = /rgba?\([^)]+\)/gi;

// 取上下文：前 N 行 + 当行 + 后 1 行
function 取上下文(内容, i, 前 = 3) {
  const 前行 = [];
  for (let k = Math.max(0, i - 前); k < i; k++) 前行.push(内容[k] || '');
  return {
    前: 前行.join('\n'),
    前1: 内容[i - 1] || '',
    当: 内容[i] || '',
    后: 内容[i + 1] || '',
  };
}

// 判断 backgroundColor 调用的参数是否为硬编码 hex 字面量
// 返回 { 动态: true } 或 { 硬编码: '#XXXXXX' }
function 解析backgroundColor参数(联合上下文) {
  const m = 联合上下文.match(/backgroundColor\s*\(\s*([^)\n]+?)\s*\)/);
  if (!m) return null;
  const 参数 = m[1].trim();
  // 硬编码 hex 字面量
  const hexM = 参数.match(/^['"]#[0-9A-Fa-f]{3,8}['"]/);
  if (hexM) {
    const 色 = 参数.match(/#[0-9A-Fa-f]{3,8}/)[0];
    return { 硬编码: 色 };
  }
  // rgba / rgb 字面量
  if (/^['"]rgba?\(/.test(参数)) return { 动态: true };
  // $r(...) 资源引用、this.XXX、方法调用、变量、三元表达式 → 动态
  return { 动态: true };
}

// ===================== 用途分类 =====================
function 分类hex(行, 上下文) {
  // .color('#XXX') 方法调用 - 视为文字色（阈值 4.5）
  if (/\.color\s*\(\s*['"]#/.test(行)) {
    return { 类型: '文字色', 阈值: 4.5 };
  }
  // fontColor: '#XXX'（对象字面量属性，如 ButtonStyle） - 文字色
  if (/fontColor\s*:\s*['"]#/.test(行)) {
    return { 类型: '文字色', 阈值: 4.5 };
  }
  // fontColor('#XXX') 方法调用 - 文字色，阈值 4.5
  if (/fontColor\s*\(/.test(行)) {
    // 特殊处理 fontColor('#FFFFFF') 配动态/硬编码按钮背景的情况
    if (/'#FFFFFF'/i.test(行) || /"#FFFFFF"/i.test(行)) {
      const 联合 = 上下文.前 + '\n' + 行 + '\n' + 上下文.后;
      const bg = 解析backgroundColor参数(联合);
      if (bg) {
        if (bg.动态) {
          // 按钮底是动态主题色（已由 verify-contrast.mjs 验证），跳过
          return { 类型: '按钮底-白字-动态背景', 阈值: null };
        }
        if (bg.硬编码) {
          // 按钮底是硬编码 hex，检查 #FFFFFF / 按钮底
          return { 类型: '按钮底-白字-硬编码背景', 阈值: 4.5, 文字色: '#FFFFFF', 背景色值: bg.硬编码 };
        }
      }
      // 没有上下文 backgroundColor，按白字处理（两个模式都检查白字 vs 卡片底）
      return { 类型: '文字色', 阈值: 4.5 };
    }
    return { 类型: '文字色', 阈值: 4.5 };
  }
  // borderColor('#XXX') - 边框色，阈值 3
  if (/borderColor\s*\(/.test(行)) {
    return { 类型: '边框色', 阈值: 3 };
  }
  // border({ width: ..., color: '#XXX' }) 单行
  if (/border\s*\(\s*\{[^}]*color:\s*['"]#/.test(行)) {
    return { 类型: '边框色', 阈值: 3 };
  }
  // color: '#XXX' - 需判断上下文
  if (/color:\s*['"]#/.test(行)) {
    // 多行 border({ ... color: '#XXX' }) 内：前 3 行内有 border({
    if (/border\s*\(\s*\{/.test(上下文.前)) {
      // 检查上下文是否有动态/硬编码 backgroundColor（边框所在元素的底色）
      const bg = 解析backgroundColor参数(上下文.前 + '\n' + 行);
      if (bg && bg.动态) {
        // 边框在动态彩色背景上，无法自动判定对比度
        return { 类型: '边框色-动态背景-需复核', 阈值: null };
      }
      if (bg && bg.硬编码) {
        // 边框在硬编码背景上，检查 边框色 / 硬编码背景（阈值 3）
        return { 类型: '边框色-硬编码背景', 阈值: 3, 背景色值: bg.硬编码 };
      }
      // 没有上下文 backgroundColor，按卡片底检查
      return { 类型: '边框色', 阈值: 3 };
    }
    // width: { left: ..., color: '#XXX' } 模式
    if (/width:\s*\{/.test(上下文.前) || /width:\s*\{/.test(行)) {
      return { 类型: '边框色', 阈值: 3 };
    }
    // 其他 color: 字段（如 AlertDialog 按钮色、样式对象）→ 需复核
    return { 类型: '样式color-需复核', 阈值: null };
  }
  // backgroundColor('#XXX') - 背景色
  if (/backgroundColor\s*\(/.test(行)) {
    // return ... ? '#XXX' : '#XXX' 模式 → 浮卡底色等条件返回
    if (/return\s+.*\?/.test(行)) {
      return { 类型: '条件返回背景-需复核', 阈值: null };
    }
    // 检查上下文（前后 1 行）是否有 fontColor('#FFFFFF')，判断按钮底配白字
    const 联合 = 上下文.前1 + '\n' + 行 + '\n' + 上下文.后;
    if (/fontColor\s*\(\s*['"]#FFFFFF['"]/.test(联合)) {
      return { 类型: '按钮底-白字-硬编码背景', 阈值: 4.5, 文字色: '#FFFFFF', 背景色值: 行.match(/#[0-9A-Fa-f]{3,8}/)[0] };
    }
    // 其他 backgroundColor 纯 hex → 需复核（可能是大面积背景或小面积交互元素）
    return { 类型: '背景色-需复核', 阈值: null };
  }
  // return this.isDark ? '#XXX' : '#XXX' - 条件返回色
  if (/return\s+.*\?/.test(行)) {
    return { 类型: '条件返回色-需复核', 阈值: null };
  }
  // case ... return '#XXX' 模式（switch case 中的颜色返回）
  if (/case\s+.+:.*return\s+['"]#/.test(行)) {
    return { 类型: 'case返回色-需复核', 阈值: null };
  }
  // 颜色映射对象 0: '#XXX', 1: '#XXX'
  if (/^\s*\d+\s*:\s*['"]#/.test(行) || /[{,]\s*\d+\s*:\s*['"]#/.test(行)) {
    return { 类型: '颜色映射-需复核', 阈值: null };
  }
  // 其他无法判定
  return { 类型: '未知-需复核', 阈值: null };
}

// ===================== 模式守卫检测 =====================
// 返回应检查的模式列表：['浅色'] / ['深色'] / ['浅色', '深色']
function 检测模式守卫(行, 色值) {
  // 三元表达式：this.isDark ? '#XXX' : '#XXX' 或 this.是否深色 ? '#XXX' : '#XXX'
  const 三元匹配 = 行.match(/(?:isDark|是否深色)\s*\?\s*(['"])(#[0-9A-Fa-f]{3,8})\1\s*:\s*(['"])(#[0-9A-Fa-f]{3,8})\3/);
  if (三元匹配) {
    const 深色值 = 三元匹配[2].toLowerCase();
    const 浅色值 = 三元匹配[4].toLowerCase();
    const 当 = 色值.toLowerCase();
    if (当 === 深色值) return ['深色'];
    if (当 === 浅色值) return ['浅色'];
    // 色值不匹配三元中的任何一个（可能是行内还有其他色值），两个模式都查
    return ['浅色', '深色'];
  }
  // 没有 isDark 守卫的色值，两个模式都检查
  return ['浅色', '深色'];
}

// ===================== 对比度检查 =====================
function 检查对比度(文件, 行号, 色值, 分类, 行, 有isDark) {
  const 阈值 = 分类.阈值;
  const 检查模式 = 检测模式守卫(行, 色值);
  void 有isDark;

  for (const 模式 of 检查模式) {
    let 前景, 背景, 建议向深, 建议色值;
    if (分类.类型 === '按钮底-白字-硬编码背景') {
      // 按钮底配白字：前景=#FFFFFF，背景=色值（按钮底），不区分模式
      前景 = '#FFFFFF';
      背景 = 分类.背景景色值;
      建议色值 = 分类.背景景色值; // 调整对象是按钮底背景
      建议向深 = true; // 让白字达标，背景需向深
    } else if (分类.类型 === '边框色-硬编码背景') {
      // 边框色配硬编码背景：前景=色值（边框），背景=硬编码背景，不区分模式
      前景 = 色值;
      背景 = 分类.背景景色值;
      建议色值 = 色值;
      // 边框向深或向浅调整以增加对比度，取决于背景明暗
      建议向深 = 相对亮度(背景) > 0.5; // 背景偏浅，边框向深调整
    } else {
      // 文字色或边框色：前景=色值，背景=卡片底
      前景 = 色值;
      背景 = 模式 === '浅色' ? 浅色卡片底 : 深色卡片底;
      建议色值 = 色值; // 调整对象是前景色值本身
      // 浅色模式：色值向深调整增加对比度；深色模式：色值向浅调整
      建议向深 = 模式 === '浅色';
    }
    const 比 = 对比度(前景, 背景);
    if (比 < 阈值) {
      const 建议 = 调整达标(建议色值, 背景, 阈值, 建议向深);
      不达标清单.push({
        文件: path.relative(项目根, 文件),
        行号, 色值, 用途: 分类.类型,
        模式, 前景, 背景,
        对比度: 比.toFixed(2),
        阈值,
        建议修复色: 建议 || '(无法自动调整)',
        代码: 行.trim(),
      });
    }
  }
}

// ===================== 主流程 =====================
const 文件列表 = [];
for (const 根 of 扫描根列表) {
  if (fs.existsSync(根)) 文件列表.push(...递归扫描(根));
}

let 总色值数 = 0;
let 文字色数 = 0, 边框色数 = 0, 背景色数 = 0, 遮罩数 = 0, 跳过数 = 0, 动态跳过数 = 0, 人工复核数 = 0;
const 不达标清单 = [];
const 人工复核清单 = [];

for (const 文件 of 文件列表) {
  const 内容 = fs.readFileSync(文件, 'utf8').split(/\r?\n/);
  const 文件全文 = 内容.join('\n');
  // 文件级 isDark / themeMode 守卫标志（用于辅助判断，目前主要按行内守卫）
  const 有isDark = /isDark|是否深色|themeMode|@StorageProp\(['"]themeMode['"]\)/.test(文件全文);
  void 有isDark; // 当前按行内三元守卫判定，文件级标志保留备用

  for (let i = 0; i < 内容.length; i++) {
    const 行 = 内容[i];
    const 行号 = i + 1;
    const 去前导 = 行.replace(/^\s+/, '');

    // 跳过纯注释行（//、/*、/**、*）
    if (去前导.startsWith('//') || 去前导.startsWith('/*') || 去前导.startsWith('*')) continue;

    const hex匹配 = 行.match(hex正则) || [];
    const rgba匹配 = 行.match(rgba正则) || [];

    // 跳过 @StorageProp / @Prop 默认值行（被主题系统或父组件运行时覆盖，不算硬编码使用）
    if (/@StorageProp\s*\(/.test(行) && /=\s*['"]#/.test(行)) {
      跳过数 += hex匹配.length;
      continue;
    }
    if (/@Prop\s+/.test(行) && /=\s*['"]#/.test(行)) {
      跳过数 += hex匹配.length;
      continue;
    }

    // 处理 hex 色值
    for (const 原 of hex匹配) {
      总色值数++;
      const 上下文 = 取上下文(内容, i);
      const 分类 = 分类hex(行, 上下文);

      if (分类.类型 === '文字色') 文字色数++;
      else if (分类.类型 === '边框色' || 分类.类型 === '边框色-硬编码背景') 边框色数++;
      else if (分类.类型 === '按钮底-白字-硬编码背景') 背景色数++;
      else if (分类.类型 === '按钮底-白字-动态背景') 动态跳过数++;
      else if (分类.类型.endsWith('需复核') || 分类.类型 === '未知-需复核') 人工复核数++;
      else 背景色数++;

      if (分类.类型 === '文字色' || 分类.类型 === '边框色' || 分类.类型 === '边框色-硬编码背景' || 分类.类型 === '按钮底-白字-硬编码背景') {
        检查对比度(文件, 行号, 原, 分类, 行, 有isDark);
      } else if (分类.类型 === '按钮底-白字-动态背景') {
        // 动态背景由主题系统保证，跳过对比度检查（不计入不达标，也不计入人工复核）
        continue;
      } else {
        人工复核清单.push({
          文件: path.relative(项目根, 文件),
          行号, 色值: 原, 用途: 分类.类型,
          代码: 行.trim(),
        });
      }
    }

    // 处理 rgba 色值
    for (const 原 of rgba匹配) {
      总色值数++;
      const rgba = 解析rgba(原);
      if (!rgba) {
        人工复核数++;
        人工复核清单.push({
          文件: path.relative(项目根, 文件),
          行号, 色值: 原, 用途: 'rgba-无法解析',
          代码: 行.trim(),
        });
        continue;
      }
      if (是遮罩色(rgba)) {
        遮罩数++;
        continue;
      }
      // 彩色透明 rgba → 人工复核
      人工复核数++;
      人工复核清单.push({
        文件: path.relative(项目根, 文件),
        行号, 色值: 原, 用途: 'rgba-彩色透明',
        代码: 行.trim(),
      });
    }
  }
}

// ===================== 输出报告 =====================
console.log('========================================');
console.log('硬编码色值对比度审计报告');
console.log('========================================');
console.log(`扫描目录：${扫描根列表.map(p => path.relative(项目根, p)).join(' / ')}`);
console.log(`扫描 .ets 文件数：${文件列表.length}`);
console.log(`硬编码色值总数（含 rgba、含 @StorageProp/@Prop 默认值）：${总色值数 + 跳过数}`);
console.log(`  其中参与对比度检查的硬编码色值：${文字色数 + 边框色数 + 背景色数}`);
console.log(`  其中跳过（遮罩/动态背景/默认值）：${遮罩数 + 动态跳过数 + 跳过数}`);
console.log(`  其中需人工复核：${人工复核数}`);
console.log('');
console.log('按用途分类统计：');
console.log(`  - 文字色（fontColor/.color）          ：${文字色数}`);
console.log(`  - 边框色（borderColor/border.color）  ：${边框色数}`);
console.log(`  - 背景色（按钮底-白字-硬编码背景）    ：${背景色数}`);
console.log(`  - 遮罩/透明覆盖（跳过）               ：${遮罩数}`);
console.log(`  - 动态主题背景配白字（跳过，已验证）  ：${动态跳过数}`);
console.log(`  - @StorageProp/@Prop 默认值（跳过）   ：${跳过数}`);
console.log(`  - 需人工复核                          ：${人工复核数}`);
console.log('');
console.log(`❌ 不达标项：${不达标清单.length} 项`);
console.log('----------------------------------------');
for (const 项 of 不达标清单) {
  console.log(`[${项.文件}:${项.行号}]`);
  console.log(`  色值: ${项.色值} | 用途: ${项.用途} | 适用模式: ${项.模式}`);
  console.log(`  对比度: ${项.对比度}:1 (需 ≥ ${项.阈值}:1)  [前景 ${项.前景} / 背景 ${项.背景}]`);
  console.log(`  建议修复色: ${项.建议修复色}`);
  console.log(`  代码: ${项.代码}`);
  console.log('');
}
console.log('----------------------------------------');
console.log(`⚠ 需人工复核项：${人工复核清单.length} 项`);
for (const 项 of 人工复核清单) {
  console.log(`[${项.文件}:${项.行号}] ${项.色值} | ${项.用途}`);
  console.log(`  代码: ${项.代码}`);
}
console.log('----------------------------------------');
console.log(不达标清单.length === 0 ? '✓ 所有自动判定的文字/边框/按钮底色均达标' : `⚠ 共 ${不达标清单.length} 项不达标，需修复`);
