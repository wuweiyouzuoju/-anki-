// SPDX-License-Identifier: AGPL-3.0-or-later

import { 构建完整色阶 } from './色阶生成';

const 浅色页面底色: string = '#F5F7FA';
const 深色页面底色: string = '#10151D';
const 深色卡片底色: string = '#18202B';

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

export type 颜色主题 = 'aurora' | 'forest' | 'midnight' | 'lagoon' | 'sunset' | 'lemon';

export const 默认颜色主题: 颜色主题 = 'aurora';

function 取主题种子色(主题: 颜色主题): string {
  switch (主题) {
    case 'aurora':
      return '#2F5FD0';
    case 'forest':
      return '#00B42A';
    case 'midnight':
      return '#722ED1';
    case 'lagoon':
      return '#14C9C9';
    case 'sunset':
      return '#FF7D00';
    case 'lemon':
      return '#F7BA1E';
    default:
      return '#2F5FD0';
  }
}

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

export function 规范化颜色主题(值: string): 颜色主题 {
  if (值 === 'forest' || 值 === 'midnight' || 值 === 'lagoon'
    || 值 === 'sunset' || 值 === 'lemon') {
    return 值;
  }
  return 'aurora';
}

export function 解析主题色板(主题: 颜色主题, 是否深色: boolean): 主题色板 {
  const 新卡计数色: string = 是否深色 ? '#7C9AE8' : '#366ECE';
  const 学习中计数色: string = 是否深色 ? '#E6A45F' : '#AC6520';
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
    选中背景: 是否深色 ? 深色卡片底色 : 容器色,
    新卡计数色,
    学习中计数色,
    复习中计数色,
    热力1: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.25) : 色阶.色阶[1],
    热力2: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.45) : 色阶.色阶[2],
    热力3: 是否深色 ? 混合十六进制色(深色卡片底色, 语义.按钮背景主色, 0.70) : 色阶.色阶[4],
    热力4: 语义.按钮背景主色,
    页面底色微染: 混合十六进制色(是否深色 ? 深色页面底色 : 浅色页面底色, 语义.主色, 是否深色 ? 0.10 : 0.06)
  };
}

export function 颜色主题色块(主题: 颜色主题): string {
  return 解析主题色板(主题, false).动作主色;
}

export function 颜色主题渐变档(主题: 颜色主题): string[] {
  const 种子: string = 取主题种子色(主题);
  const 色阶 = 构建完整色阶(种子, false);
  return [色阶.色阶[0], 色阶.色阶[3], 色阶.色阶[5]];
}
