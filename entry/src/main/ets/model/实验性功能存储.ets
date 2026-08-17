// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-EXPERIMENTAL-FEATURES-001
// @名称 实验性功能持久化
//
// @作用
// 实验性功能开关的 preferences 持久化 + AppStorage 跨组件广播。
// 当前包含两项：
// - Tap Zones（点击屏幕区域快速答题）：answer 阶段把屏幕划成 2×2 象限直接评分；
//   question 阶段点屏幕翻面。
// - 学习页手写白板：浮动工具栏加「手写」按钮，按下后叠加 Canvas 笔迹层，
//   用户可在卡片区域手写答案，提供清空/撤销/保存。
// 两项默认关闭，且仅在「实验版」模式下设置页可见；学习页生效前会再校验当前为实验版，
// 简洁版下即使开关残留为 true 也不会触发功能。
//
// @输入
// 无（读取）；开启: boolean（保存）
//
// @输出
// 加载TapZones开关(): Promise<boolean>
// 保存TapZones开关(开启: boolean): Promise<void>
// 加载手写白板开关(): Promise<boolean>
// 保存手写白板开关(开启: boolean): Promise<void>
// TapZones开关AppStorage键: string
// 手写白板开关AppStorage键: string
//
// @业务规则
// 默认值 false（关闭）：实验性功能默认不启用，避免影响主线体验。
// 'tap_zones_enabled' / 'study_whiteboard_enabled' 是 AppStorage 协议字段，保留英文，不可中文化。
//
// @副作用
// 读写 preferences 的 jidecards_settings store（与 简洁模式存储 同 store，key 前缀独立）；
// 保存时同步写 AppStorage 触发 @StorageLink 监听方重渲染。
// ========================================================

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const TapZones键: string = 'tap_zones_enabled';
const 手写白板键: string = 'study_whiteboard_enabled';
const 上下文键: string = 'abilityContext';

export const TapZones开关AppStorage键: string = 'tapZonesEnabled';
export const 手写白板开关AppStorage键: string = 'studyWhiteboardEnabled';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

export async function 加载TapZones开关(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return false;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(TapZones键, false);
    return 值 === true;
  } catch (错误) {
    return false;
  }
}

export async function 保存TapZones开关(开启: boolean): Promise<void> {
  AppStorage.setOrCreate<boolean>(TapZones开关AppStorage键, 开启);
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(TapZones键, 开启);
    await 存储.flush();
  } catch (错误) {
    // 持久化失败可接受：UI 已切换，下次启动会回退到上次保存的值。
  }
}

export async function 加载手写白板开关(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return false;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(手写白板键, false);
    return 值 === true;
  } catch (错误) {
    return false;
  }
}

export async function 保存手写白板开关(开启: boolean): Promise<void> {
  AppStorage.setOrCreate<boolean>(手写白板开关AppStorage键, 开启);
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(手写白板键, 开启);
    await 存储.flush();
  } catch (错误) {
    // 持久化失败可接受：UI 已切换，下次启动会回退到上次保存的值。
  }
}
