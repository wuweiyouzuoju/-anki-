// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 复习页布局持久化：布局模式（底部默认 / 浮动模式）+ 两个浮动工具栏的拖动位置。
// 用 preferences（@kit.ArkData）存储，与 DeckMetaStore 同一 store 但 key 前缀独立。
// 浮动模式下的工具栏位置以 vp 为单位，避免与屏幕分辨率耦合；拖出屏幕外时由调用方夹紧。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'jidecards_study_layout';
const KEY_LAYOUT_MODE: string = 'study_layout_mode';
const KEY_MAIN_X: string = 'study_main_toolbar_x';
const KEY_MAIN_Y: string = 'study_main_toolbar_y';
const KEY_AUX_X: string = 'study_aux_toolbar_x';
const KEY_AUX_Y: string = 'study_aux_toolbar_y';
const CONTEXT_KEY: string = 'abilityContext';

/** 复习页操作按钮布局模式。bottom=贴底部（默认，保持原体验）；float=浮动可拖动。 */
export type StudyLayoutMode = 'bottom' | 'float';

/** 浮动工具栏标识：main=主操作（显示答案/4 评分按钮）；aux=辅助操作（埋藏/暂停）。 */
export type StudyToolbarId = 'main' | 'aux';

/** 浮动工具栏屏幕坐标（vp）。x/y 是工具栏左上角相对屏幕左上角的偏移。 */
export interface ToolbarPosition {
  x: number;
  y: number;
}

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

/** 读取布局模式；读取失败或未设置时返回 'bottom'（默认保持原体验）。 */
export async function loadStudyLayoutMode(): Promise<StudyLayoutMode> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return 'bottom';
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const value: preferences.ValueType = await store.get(KEY_LAYOUT_MODE, 'bottom');
    if (typeof value === 'string' && (value === 'bottom' || value === 'float')) {
      return value;
    }
    return 'bottom';
  } catch (error) {
    return 'bottom';
  }
}

/** 持久化布局模式。 */
export async function saveStudyLayoutMode(mode: StudyLayoutMode): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(KEY_LAYOUT_MODE, mode);
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}

/**
 * 读取指定浮动工具栏的拖动位置（vp）。
 * 未持久化时返回 null，调用方应使用默认位置（如主工具栏贴右下、辅助工具栏贴左下）。
 */
export async function loadStudyToolbarPos(toolbarId: StudyToolbarId): Promise<ToolbarPosition | null> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return null;
  }
  const xKey: string = toolbarId === 'main' ? KEY_MAIN_X : KEY_AUX_X;
  const yKey: string = toolbarId === 'main' ? KEY_MAIN_Y : KEY_AUX_Y;
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const hasX: boolean = await store.has(xKey);
    if (!hasX) {
      return null;
    }
    const xVal: preferences.ValueType = await store.get(xKey, 0);
    const yVal: preferences.ValueType = await store.get(yKey, 0);
    if (typeof xVal !== 'number' || typeof yVal !== 'number') {
      return null;
    }
    const pos: ToolbarPosition = { x: xVal, y: yVal };
    return pos;
  } catch (error) {
    return null;
  }
}

/** 持久化指定浮动工具栏的拖动位置（vp）。 */
export async function saveStudyToolbarPos(toolbarId: StudyToolbarId, x: number, y: number): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  const xKey: string = toolbarId === 'main' ? KEY_MAIN_X : KEY_AUX_X;
  const yKey: string = toolbarId === 'main' ? KEY_MAIN_Y : KEY_AUX_Y;
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(xKey, x);
    await store.put(yKey, y);
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}
