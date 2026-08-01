// SPDX-License-Identifier: AGPL-3.0-or-later

import { 颜色键 } from '../model/颜色主题';
import { 规范化主题模式, 解析是否深色 } from '../model/主题设置';

export interface 设置面板色板 {
  背景: string;
  主文字: string;
  次文字: string;
  三级文字: string;
  弱化文字: string;
  分隔线: string;
  标签背景: string;
  主色: string;
  主色按钮背景: string;
  错误色: string;
  遮罩: string;
}

function 兜底主色(是否深色: boolean): string {
  return 是否深色 ? '#5C84E6' : '#2F5FD0';
}

function 兜底主色按钮背景(是否深色: boolean): string {
  return 是否深色 ? '#2F5FD0' : '#2F5FD0';
}

function 中性标签背景(是否深色: boolean): string {
  return 是否深色 ? '#334155' : '#F1F5F9';
}

function 解析主色(是否深色: boolean): string {
  const 存储: string | undefined = AppStorage.get<string>(颜色键.动作主色);
  return 存储 !== undefined && 存储 !== '' ? 存储 : 兜底主色(是否深色);
}

function 解析主色按钮背景(是否深色: boolean): string {
  const 存储: string | undefined = AppStorage.get<string>(颜色键.主色按钮背景);
  return 存储 !== undefined && 存储 !== '' ? 存储 : 兜底主色按钮背景(是否深色);
}

function 解析标签背景(是否深色: boolean): string {
  return 中性标签背景(是否深色);
}

function 解析同步是否深色(回退值: boolean): boolean {
  const 模式字符串: string | undefined = AppStorage.get<string>('themeMode');
  const 系统深色: boolean | undefined = AppStorage.get<boolean>('systemDarkMode');
  if (模式字符串 === undefined || 系统深色 === undefined) {
    return 回退值;
  }
  return 解析是否深色(规范化主题模式(模式字符串), 系统深色);
}

export function 设置面板色板_取(回退是否深色: boolean): 设置面板色板 {
  const 是否深色: boolean = 解析同步是否深色(回退是否深色);
  return 是否深色 ? {
    背景: '#1E293B',
    主文字: '#F1F5F9',
    次文字: '#CBD5E1',
    三级文字: '#AEBBCE',
    弱化文字: '#9FB3CC',
    分隔线: '#334155',
    标签背景: 解析标签背景(是否深色),
    主色: 解析主色(是否深色),
    主色按钮背景: 解析主色按钮背景(是否深色),
    错误色: '#F87171',
    遮罩: 'rgba(0,0,0,0.40)'
  } : {
    背景: '#FFFFFF',
    主文字: '#182230',
    次文字: '#475569',
    三级文字: '#616A78',
    弱化文字: '#656E7C',
    分隔线: '#F1F5F9',
    标签背景: 解析标签背景(是否深色),
    主色: 解析主色(是否深色),
    主色按钮背景: 解析主色按钮背景(是否深色),
    错误色: '#DC2626',
    遮罩: 'rgba(0,0,0,0.15)'
  };
}

export function 标签文字色(色板: 设置面板色板, 是否选中: boolean): string {
  return 是否选中 ? '#FFFFFF' : 色板.次文字;
}
