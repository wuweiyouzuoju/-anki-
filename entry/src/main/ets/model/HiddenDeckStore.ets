// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 已隐藏牌组持久化（前端独立方案，Anki 后端不支持 deck 隐藏）。
// 用 preferences（@kit.ArkData）存储，key 为 `hidden_decks`，
// value 是 JSON 字符串 `["id1","id2",...]`，表示用户主动隐藏的 deck id 列表。
//
// 隐藏语义：
// - 仅隐藏当前 deck id（子牌组不联动隐藏，但父 deck 隐藏后子 deck 本来就看不见）
// - 隐藏后主页 visibleDeckRows 过滤掉这些 id
// - 恢复入口在设置页「已隐藏牌组」，用户可随时取消隐藏
//
// 同步语义：Anki Desktop / 其他设备看到的仍是所有 deck，本机隐藏状态不同步。
// jidecards 是 offline-first 单机应用，此限制可接受。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'jidecards_deck_meta';
const HIDDEN_DECKS_KEY: string = 'hidden_decks';
const CONTEXT_KEY: string = 'abilityContext';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

/**
 * 读取已隐藏的 deck id 列表。
 * 返回空数组表示无隐藏（未持久化或解析失败均降级为空）。
 */
export async function loadHiddenDeckIds(): Promise<string[]> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return [];
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const has: boolean = await store.has(HIDDEN_DECKS_KEY);
    if (!has) {
      return [];
    }
    const value: preferences.ValueType = await store.get(HIDDEN_DECKS_KEY, '');
    if (typeof value !== 'string' || value === '') {
      return [];
    }
    const parsed: object = JSON.parse(value);
    if (!Array.isArray(parsed)) {
      return [];
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
    return [];
  }
}

/**
 * 隐藏一个 deck（加入隐藏列表）。已在内则幂等无副作用。
 */
export async function saveHiddenDeck(deckId: string): Promise<void> {
  if (deckId === '') {
    return;
  }
  const current: string[] = await loadHiddenDeckIds();
  if (current.indexOf(deckId) >= 0) {
    return;
  }
  current.push(deckId);
  await writeHiddenDecks(current);
}

/**
 * 取消隐藏一个 deck（从隐藏列表移除）。不在内则幂等无副作用。
 */
export async function unhideDeck(deckId: string): Promise<void> {
  const current: string[] = await loadHiddenDeckIds();
  const next: string[] = current.filter((id: string): boolean => id !== deckId);
  if (next.length === current.length) {
    return;
  }
  await writeHiddenDecks(next);
}

/** 批量取消隐藏（清空列表）。 */
export async function unhideAllDecks(): Promise<void> {
  await writeHiddenDecks([]);
}

async function writeHiddenDecks(ids: string[]): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(HIDDEN_DECKS_KEY, JSON.stringify(ids));
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}
