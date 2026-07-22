// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 同级子牌组顺序持久化（前端独立方案，Anki 后端不支持 deck 排序）。
// 用 preferences（@kit.ArkData）存储，key 形如 `deck_order_<parentId>`，
// value 是 JSON 字符串 `["id1","id2",...]`，表示该 parent 下子牌组的前端展示顺序。
//
// 顶层（parentId=''）的 key 用 `deck_order_root`。
// 未持久化的 parent 仍按 Anki 返回的默认顺序（即 DeckTreeNode.children 原序，通常按 name 字典序）。
//
// 同步语义：Anki Desktop / 其他设备看到的仍是后端默认顺序，本机自定义顺序不同步。
// jidecards 是 offline-first 单机应用，此限制可接受。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'jidecards_deck_meta';
const ORDER_KEY_PREFIX: string = 'deck_order_';
const ROOT_KEY_SUFFIX: string = 'root';
const CONTEXT_KEY: string = 'abilityContext';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

/** parentId=''（顶层）映射到 deck_order_root；其余映射到 deck_order_<parentId>。 */
function orderKey(parentId: string): string {
  return parentId === '' ? `${ORDER_KEY_PREFIX}${ROOT_KEY_SUFFIX}` : `${ORDER_KEY_PREFIX}${parentId}`;
}

/**
 * 读取某 parent 下用户自定义的子牌组顺序。
 * 返回 null 表示未持久化，调用方应回退到后端默认顺序。
 * 解析失败或 JSON 非数组时也返回 null，不抛异常。
 */
export async function loadDeckOrder(parentId: string): Promise<string[] | null> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return null;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const has: boolean = await store.has(orderKey(parentId));
    if (!has) {
      return null;
    }
    const value: preferences.ValueType = await store.get(orderKey(parentId), '');
    if (typeof value !== 'string' || value === '') {
      return null;
    }
    const parsed: object = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return null;
    }
    const out: string[] = [];
    for (let i: number = 0; i < parsed.length; i++) {
      const item: string = parsed[i] as string;
      if (typeof item === 'string' && item !== '') {
        out.push(item);
      }
    }
    return out;
  } catch (error) {
    return null;
  }
}

/**
 * 批量加载多个 parent 的子牌组顺序，返回 parentId → string[] 的 Map。
 * 未持久化的 parent 不出现在 Map 中，调用方回退到后端默认顺序。
 */
export async function loadAllDeckOrders(parentIds: string[]): Promise<Map<string, string[]>> {
  const out: Map<string, string[]> = new Map<string, string[]>();
  if (parentIds.length === 0) {
    return out;
  }
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return out;
  }
  // 去重，避免重复 IO
  const seen: Set<string> = new Set<string>();
  for (let i: number = 0; i < parentIds.length; i++) {
    const parentId: string = parentIds[i];
    if (seen.has(parentId)) {
      continue;
    }
    seen.add(parentId);
    const order: string[] | null = await loadDeckOrder(parentId);
    if (order !== null) {
      out.set(parentId, order);
    }
  }
  return out;
}

/**
 * 持久化某 parent 下子牌组的顺序。childIds 为空数组时也写入（表示用户主动清空排序）。
 * 调用方应在用户拖动结束后调用一次，而非每次拖动中都写入。
 */
export async function saveDeckOrder(parentId: string, childIds: string[]): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(orderKey(parentId), JSON.stringify(childIds));
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}

/**
 * 删除某 parent 的顺序覆盖，恢复后端默认顺序。
 * 用户在「完成排序」模式下点击「恢复默认」时调用。
 */
export async function clearDeckOrder(parentId: string): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const has: boolean = await store.has(orderKey(parentId));
    if (has) {
      await store.delete(orderKey(parentId));
      await store.flush();
    }
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}
