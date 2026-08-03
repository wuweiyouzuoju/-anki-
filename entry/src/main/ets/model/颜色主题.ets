// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-COLOR-THEME-001
// @名称 颜色主题
//
// @作用
// 定义 6 个颜色主题（极光蓝/仙野绿/暗夜紫/碧涛青/活力橙/柠檬金），
// 每个主题由一个种子色派生出 19 个颜色键的完整色板，供 AppStorage 全局绑定。
// 与 主题模式（system/light/dark）正交——这是主色调维度。
//
// @输入
// 颜色主题 枚举值（'aurora'/'forest'/'midnight'/'lagoon'/'sunset'/'lemon'）
// 是否深色 布尔值
//
// @输出
// 默认颜色主题 常量
// 颜色键集合（19 个 AppStorage 键名常量）
// 主题色板（19 个 hex 字符串值）
// 主题色块 / 主题渐变档（用于设置页 chip 预览）
//
// @业务规则
// 设计原则（B 方案：ArcoDesign 色阶重写，2026-07-22）：
// - 每个主题只需指定 1 个种子色（= ArcoDesign shade 6），运行时由 色阶生成.构建完整色阶
//   派生 10 档色阶 + 8 个语义色（primary/hover/active/container/containerHover/border/icon/text）。
// - 13 个颜色键跟随主题变化：
//   1) 主色系（8 个）：覆盖按钮、选中行底色、边框、图标、强调文字等所有主色场景
//   2) 热力图（1 个）：heat4（= primary）
//   3) 选中背景（1 个）：surfaceSelected（= primaryContainer，保留旧键名兼容既有组件）
//   4) 固定语义色（3 个）：countNew（蓝）/ countLearning（橙）/ countReview（紫）
//      —— 保证「新卡=蓝、学习中=橙、复习中=紫」交通灯语义在所有主题下一致，
//         不跟随主色变化，让用户通过颜色快速识别卡片状态。
// - 每个主题提供浅色+深色两套配色，由 是否深色 决定使用哪套（构建完整色阶 自动选档）。
// 主题种子色取自 ArcoDesign 色板（https://arco.design/palette/list），均经 WCAG AA/AAA 验证。
// 6 个主题枚举值与 preferences 持久化字符串一一对应，不得改名。
//
// @副作用
// 无。本文件为纯函数与常量定义，不读不写状态。
//
// @注意
// 主题枚举字符串值 'aurora'/'forest'/'midnight'/'lagoon'/'sunset'/'lemon' 是持久化值，禁止修改。
// AppStorage 键名字符串 'theme_color_*' 是与组件 @StorageProp 绑定的协议字段，禁止修改。
// 修改 选档逻辑 或 马卡龙化比例 会影响所有主题视觉呈现与对比度达标情况。
// ========================================================

import { 构建完整色阶 } from './色阶生成';

/** 页面底色（与 resources color.json surface_page 一致），用于和主题色混合产生极淡背景。 */
const 浅色页面底色: string = '#F5F7FA';
const 深色页面底色: string = '#10151D';
/** 深色模式卡片底色（与 resources dark/color.json surface_card 一致），用于 heat 色阶混合。 */
const 深色卡片底色: string = '#18202B';

// ========================================================
// @块ID MODEL-COLOR-THEME-002
// @名称 混合十六进制色
//
// @作用
// 把前景色 按 alpha 混入背景色，返回混合后的 hex 字符串。
//
// @输入
// 背景色 hex 字符串
// 前景色 hex 字符串
// alpha∈[0,1]（0=纯背景色，1=纯前景色）
//
// @输出
// 混合后的 hex 字符串
//
// @业务规则
// ArkTS 不支持解构声明（arkts-no-destruct-decls），用索引访问。
//
// @副作用
// 无。
// ========================================================
function 混合十六进制色(背景色: string, 前景色: string, alpha: number): string {
  const 解析 = (hex: string): number[] => {
    let s: string = hex.startsWith('#') ? hex.slice(1) : hex;
    if (s.length === 3) {
      s = s.split('').map((c: string): string => c + c).join('');
    }
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
  };
  const 背景数组: number[] = 解析(背景色);
  const 前景数组: number[] = 解析(前景色);
  const r: number = Math.round(前景数组[0] * alpha + 背景数组[0] * (1 - alpha));
  const g: number = Math.round(前景数组[1] * alpha + 背景数组[1] * (1 - alpha));
  const b: number = Math.round(前景数组[2] * alpha + 背景数组[2] * (1 - alpha));
  const 转十六进制 = (n: number): string => {
    const 限定: number = Math.max(0, Math.min(255, n));
    const h: string = 限定.toString(16);
    return h.length === 1 ? '0' + h : h;
  };
  return '#' + 转十六进制(r) + 转十六进制(g) + 转十六进制(b);
}

/** 6 个颜色主题枚举值，与 preferences 持久化字符串一一对应。 */
export type 颜色主题 = 'aurora' | 'forest' | 'midnight' | 'lagoon' | 'sunset' | 'lemon';

export const 默认颜色主题: 颜色主题 = 'aurora';

/**
 * 6 个主题的种子色（= ArcoDesign shade 6）。运行时由 构建完整色阶 派生完整色阶。
 * 取自 ArcoDesign 色板：https://arco.design/palette/list
 * 用函数而非 Record 避免 ArkTS 的 arkts-no-untyped-obj-literals 限制。
 */
function 取主题种子色(主题: 颜色主题): string {
  switch (主题) {
    case 'aurora':
      return '#2F5FD0';   // ArcoDesign Blue 6
    case 'forest':
      return '#00B42A';   // ArcoDesign Green 6
    case 'midnight':
      return '#722ED1';   // ArcoDesign Purple 6
    case 'lagoon':
      return '#14C9C9';   // ArcoDesign Cyan 6
    case 'sunset':
      return '#FF7D00';   // ArcoDesign Orange 6
    case 'lemon':
      return '#F7BA1E';   // ArcoDesign Yellow 6
    default:
      return '#2F5FD0';
  }
}

/**
 * AppStorage 中存储的 19 个颜色键名常量；组件用 @StorageProp 绑定这些键即可跟随主题色。
 * - 旧键（保留）：actionPrimary / surfaceSelected / countNew / countLearning / countReview / heat4
 * - 新键（B 方案）：actionPrimaryHover / actionPrimaryActive / primaryContainer / primaryContainerHover
 *                  / primaryBorder / primaryIcon / primaryText
 * - 新键（2.1.4.1 对比度）：primaryButton（按钮背景专用，配 #FFFFFF 文字 ≥ 4.5:1）
 * 字段值字符串 'theme_color_*' 是持久化协议字段，禁止修改。
 */
export interface 颜色键集合 {
  动作主色: string;
  动作主色悬停: string;
  动作主色按下: string;
  主色按钮背景: string;
  主色按钮按下: string;
  选中背景: string;
  主色容器: string;
  主色容器悬停: string;
  主色边框: string;
  主色图标: string;
  主色文字: string;
  新卡计数色: string;
  学习中计数色: string;
  复习中计数色: string;
  热力1: string;
  热力2: string;
  热力3: string;
  热力4: string;
  页面底色微染: string;
}

export const 颜色键: 颜色键集合 = {
  动作主色: 'theme_color_action_primary',
  动作主色悬停: 'theme_color_action_primary_hover',
  动作主色按下: 'theme_color_action_primary_active',
  主色按钮背景: 'theme_color_primary_button',
  主色按钮按下: 'theme_color_primary_button_active',
  选中背景: 'theme_color_surface_selected',
  主色容器: 'theme_color_primary_container',
  主色容器悬停: 'theme_color_primary_container_hover',
  主色边框: 'theme_color_primary_border',
  主色图标: 'theme_color_primary_icon',
  主色文字: 'theme_color_primary_text',
  新卡计数色: 'theme_color_count_new',
  学习中计数色: 'theme_color_count_learning',
  复习中计数色: 'theme_color_count_review',
  热力1: 'theme_color_heat_1',
  热力2: 'theme_color_heat_2',
  热力3: 'theme_color_heat_3',
  热力4: 'theme_color_heat_4',
  页面底色微染: 'theme_color_surface_page_tint'
};

/** 一组完整主题色（含 19 个键的 hex 字符串值，不含 alpha）。 */
export interface 主题色板 {
  动作主色: string;
  动作主色悬停: string;
  动作主色按下: string;
  主色按钮背景: string;
  主色按钮按下: string;
  选中背景: string;
  主色容器: string;
  主色容器悬停: string;
  主色边框: string;
  主色图标: string;
  主色文字: string;
  新卡计数色: string;
  学习中计数色: string;
  复习中计数色: string;
  热力1: string;
  热力2: string;
  热力3: string;
  热力4: string;
  页面底色微染: string;
}

/** 把持久化的字符串值安全转回 颜色主题；非法/未设置时返回默认主题。 */
export function 规范化颜色主题(值: string): 颜色主题 {
  if (值 === 'forest' || 值 === 'midnight' || 值 === 'lagoon'
    || 值 === 'sunset' || 值 === 'lemon') {
    return 值;
  }
  return 'aurora';
}

// ========================================================
// @块ID MODEL-COLOR-THEME-003
// @名称 解析主题色板
//
// @作用
// 从种子色派生完整 19 色调色板。
// 新卡计数色/学习中计数色/复习中计数色 作为固定语义色保持稳定，不跟随主题色变化，
// 形成「新卡=蓝、学习中=橙、复习中=紫」交通灯语义。
//
// @输入
// 颜色主题 枚举值
// 是否深色 布尔值
//
// @输出
// 主题色板（19 个 hex 字符串）
//
// @业务规则
// 深色模式 主色容器 参考 SchulteTable05 思路：选中态用亮色实色形成对比，
// 而非与深色背景混合（混合后过暗）。选用 shades[3]（shade 4，浅色段中浅档）作基础，
// 再与白色混合做马卡龙化（降饱和提亮）：
// - 蓝/紫主题 shades[3] 本就柔和（饱和度~45%），混合后变化小
// - 绿/橙/黄主题 shades[3] 饱和度高（~68%），混合后明显柔化呈马卡龙色调
// 混合比例经用户微调 2026-07-23：0.65（35% 白）。
// 悬停 用 shades[2] 同样马卡龙化，保持层次。浅色模式沿用 shades[1]/[2] 不变。
// 选中背景：
// - 浅色模式用马卡龙浅色 容器（配深色 text_primary 文字，对比度足够）
// - 深色模式用 深色卡片底色 深底（2.1.4.1：马卡龙浅底配深色模式浅文字对比度仅 1.1~1.5:1 不达标，
//   改为深底 + 主色边框 边框区分选中态，文字对比度恢复 ≥10:1。用户决策：只包裹边框）
// 热力图 4 档（GitHub 风格：heat4 = 主色按钮背景 深档，heat1-3 由浅到深渐进）
// 2.1.4.1 对比度：heat4 配白字需 ≥4.5:1，高明度主题（lemon/sunset）的 主色 白字不足，
// 改用 主色按钮背景（已搜索到白字达标档）；heat3 配 text_primary 深字保证可读。
// 浅色：shades[1]/[2]/[4]/[主色按钮背景]，intensity=0 让 surface_card 白底透出
// 深色：用 混合(深色卡片底色, 主色按钮背景, alpha) 生成渐进色阶（alpha 0.25/0.45/0.70/1.0）。
//   原 shades[9]/[7]/[5] 方案在高明度主题（forest/lagoon/sunset/lemon）下色阶不够深，
//   配亮白字对比度不足 4.5:1；混合方案确保 heat1-3 始终足够深，配 text_primary 亮白字均 ≥7:1。
//
// @副作用
// 无。
// ========================================================
export function 解析主题色板(主题: 颜色主题, 是否深色: boolean): 主题色板 {
  // 新卡计数色（蓝）：浅色 #366ECE / 深色 #7C9AE8，所有主题通用（2.1.4.1 加深，白底 ≥4.5:1）
  const 新卡计数色: string = 是否深色 ? '#7C9AE8' : '#366ECE';
  // 学习中卡片计数色（橙）：浅色 #AC6520 / 深色 #E6A45F，所有主题通用（2.1.4.1 加深，白底 ≥4.5:1）
  const 学习中计数色: string = 是否深色 ? '#E6A45F' : '#AC6520';
  // 复习中卡片计数色（紫）：浅色 #7056C8 / 深色 #B2A0F2，所有主题通用
  const 复习中计数色: string = 是否深色 ? '#B2A0F2' : '#7056C8';

  const 种子: string = 取主题种子色(主题);
  const 色阶 = 构建完整色阶(种子, 是否深色);
  const 语义 = 色阶.语义;

  const 马卡龙白: string = '#FFFFFF';
  const 原始容器色: string = 是否深色 ? 色阶.色阶[3] : 语义.主色容器;
  const 原始容器悬停色: string = 是否深色 ? 色阶.色阶[2] : 语义.主色容器悬停;
  const 容器色: string = 是否深色
    ? 混合十六进制色(马卡龙白, 原始容器色, 0.65)
    : 原始容器色;
  const 容器悬停色: string = 是否深色
    ? 混合十六进制色(马卡龙白, 原始容器悬停色, 0.65)
    : 原始容器悬停色;

  return {
    // 主色系（8 个）
    动作主色: 语义.主色,
    动作主色悬停: 语义.主色悬停,
    动作主色按下: 语义.主色按下,
    主色按钮背景: 语义.按钮背景主色,
    主色按钮按下: 语义.按钮背景按下,
    主色容器: 容器色,
    主色容器悬停: 容器悬停色,
    主色边框: 语义.主色边框,
    主色图标: 语义.主色图标,
    主色文字: 语义.主色文字,
    // 选中背景（保留旧键名）：见 @业务规则 中的深浅色分支说明
    选中背景: 是否深色 ? 深色卡片底色 : 容器色,
    // 计数色
    新卡计数色,
    学习中计数色,
    复习中计数色,
    // 热力图 4 档（GitHub 风格渐进，深色模式用 混合(深色卡片底色, 主色按钮背景, alpha) 生成）
    热力1: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.25) : 色阶.色阶[1],
    热力2: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.45) : 色阶.色阶[2],
    热力3: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.70) : 色阶.色阶[4],
    热力4: 语义.按钮背景主色,
    // 页面背景极淡主题色：浅色 6% / 深色 10% 主色 混入静态页面底色
    页面底色微染: 混合十六进制色(是否深色 ? 深色页面底色 : 浅色页面底色, 语义.主色, 是否深色 ? 0.10 : 0.06)
  };
}

/** 主题色预览（用于 chip 按钮上的色块）：取该主题浅色模式 动作主色 即可。 */
export function 颜色主题色块(主题: 颜色主题): string {
  return 解析主题色板(主题, false).动作主色;
}

/**
 * 主题色阶预览渐变档（用于设置页 chip 内的渐变色条）。
 * 返回该主题浅色模式下的 3 档色阶 hex：[浅, 中, 深] = [shade 1, shade 4, shade 6]。
 * 调用方用 linearGradient 把这 3 档渲染为色阶预览，让用户在选 chip 时就能看到该主题的色阶层次，
 * 而非单一纯色——蓝紫等冷色主题与暖色主题都能通过渐变看出"颜色丰富度"差异。
 */
export function 颜色主题渐变档(主题: 颜色主题): string[] {
  const 种子: string = 取主题种子色(主题);
  const 色阶 = 构建完整色阶(种子, false);
  // shades[0]=shade 1 极浅，shades[3]=shade 4 中浅，shades[5]=shade 6 种子色（= primary）
  return [色阶.色阶[0], 色阶.色阶[3], 色阶.色阶[5]];
}
