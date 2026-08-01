// SPDX-License-Identifier: AGPL-3.0-or-later

export type 主题模式 = 'system' | 'light' | 'dark';

export const 默认主题模式: 主题模式 = 'system';

export function 规范化主题模式(值: string): 主题模式 {
  if (值 === 'light') {
    return 'light';
  }
  if (值 === 'dark') {
    return 'dark';
  }
  return 'system';
}

export function 解析是否深色(模式: 主题模式, 系统深色: boolean): boolean {
  if (模式 === 'dark') {
    return true;
  }
  if (模式 === 'light') {
    return false;
  }
  return 系统深色;
}
