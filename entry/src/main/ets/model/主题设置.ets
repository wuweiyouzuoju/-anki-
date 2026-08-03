// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-THEME-SETTINGS-001
// @名称 主题设置
//
// @作用
// 定义深浅色主题模式枚举（system/light/dark）及其规范化与解析逻辑。
// system 模式由系统深浅色决定，light/dark 为强制覆盖。
//
// @输入
// （规范化）任意字符串
// （解析是否深色）主题模式 枚举值 + 系统当前是否深色 布尔值
//
// @输出
// 规范化主题模式：主题模式 枚举值（非法/未设置时回退 'system'）
// 解析是否深色：布尔值
//
// @业务规则
// 主题模式 枚举字符串值 'system'/'light'/'dark' 是 preferences 持久化值，禁止修改。
// system 模式下是否深色由系统当前状态决定；light 强制浅色；dark 强制深色。
//
// @副作用
// 无。本文件为纯类型与纯函数。
// ========================================================

export type 主题模式 = 'system' | 'light' | 'dark';

export const 默认主题模式: 主题模式 = 'system';

/** 把持久化的字符串值安全转回 主题模式；非法/未设置时回退 'system'。 */
export function 规范化主题模式(值: string): 主题模式 {
  if (值 === 'light') {
    return 'light';
  }
  if (值 === 'dark') {
    return 'dark';
  }
  return 'system';
}

/** 根据主题模式 与系统当前是否深色，解析出当前实际是否处于深色模式。 */
export function 解析是否深色(模式: 主题模式, 系统深色: boolean): boolean {
  if (模式 === 'dark') {
    return true;
  }
  if (模式 === 'light') {
    return false;
  }
  return 系统深色;
}
