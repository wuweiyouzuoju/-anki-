// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AnkiWeb 同步凭证本地持久化（M10-T14 云同步）。
//
// 背景：AnkiWeb 登录成功后后端返回 hkey（会话令牌），将其持久化到本地，
// 应用重启后可直接携带 hkey 访问同步接口，实现「重启免登录」；
// hkey 失效（401）时由调用方走重新登录流程并调用 saveSyncAuth 覆盖。
//
// 安全红线：用户密码绝不落盘——本 store 只保存 hkey / endpoint / username，
// 登录请求中的密码仅在内存中短暂存在，登录成功后立即丢弃。
//
// 存储：preferences（@kit.ArkData），store=jidecards_sync
// key=sync_hkey / sync_endpoint / sync_username，value 均为 string
// 同步 API（getPreferencesSync/putSync/getSync/deleteSync）：
// 登录态读取在启动路径上需同步返回，避免 UI 闪烁；
// flush 为 fire-and-forget，写盘失败静默（与既有 store 策略一致）。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'jidecards_sync';
const KEY_HKEY: string = 'sync_hkey';
const KEY_ENDPOINT: string = 'sync_endpoint';
const KEY_USERNAME: string = 'sync_username';
const CONTEXT_KEY: string = 'abilityContext';

/** AnkiWeb 同步凭证。endpoint 可为空串（表示使用官方默认端点）。 */
export interface SyncAuthInfo {
  /** AnkiWeb 会话令牌（登录成功后后端下发） */
  hkey: string;
  /** 登录用户名（仅用于 UI 展示，不参与鉴权） */
  username: string;
  /** 自定义同步端点；空串 = 官方 AnkiWeb 默认端点 */
  endpoint: string;
}

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

/** 获取 preferences 实例；context 缺失或 API 异常时返回 null。 */
function openStore(): preferences.Preferences | null {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return null;
  }
  try {
    return preferences.getPreferencesSync(context, { name: STORE_NAME });
  } catch (error) {
    return null;
  }
}

/** 异步落盘（fire-and-forget）：putSync/deleteSync 已更新内存缓存，flush 仅保证写盘。 */
function flushSilently(store: preferences.Preferences): void {
  store.flush().then((): void => {
    // 写盘完成，无需处理
  }).catch((): void => {
    // 写盘失败静默：内存缓存已生效，极端情况下重启后回退到上次成功落盘的值
  });
}

function readString(store: preferences.Preferences, key: string): string {
  const value: preferences.ValueType = store.getSync(key, '');
  return typeof value === 'string' ? value : '';
}

/**
 * 保存登录成功后的同步凭证（三键一次落盘）。
 * auth.endpoint 可为空串（官方默认端点）。失败时静默——内存缓存已更新。
 */
export function saveSyncAuth(auth: SyncAuthInfo): void {
  const store: preferences.Preferences | null = openStore();
  if (store === null) {
    return;
  }
  try {
    store.putSync(KEY_HKEY, auth.hkey);
    store.putSync(KEY_ENDPOINT, auth.endpoint);
    store.putSync(KEY_USERNAME, auth.username);
    flushSilently(store);
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞登录流程。
  }
}

/**
 * 读取本地同步凭证。
 * hkey 为空串或不存在时返回 null（视为未登录，调用方走登录流程）。
 */
export function loadSyncAuth(): SyncAuthInfo | null {
  const store: preferences.Preferences | null = openStore();
  if (store === null) {
    return null;
  }
  try {
    const hkey: string = readString(store, KEY_HKEY);
    if (hkey.length === 0) {
      return null;
    }
    const info: SyncAuthInfo = {
      hkey: hkey,
      username: readString(store, KEY_USERNAME),
      endpoint: readString(store, KEY_ENDPOINT)
    };
    return info;
  } catch (error) {
    return null;
  }
}

/**
 * 仅更新 endpoint（服务端下发 new_endpoint 时调用），hkey/username 保持不变。
 */
export function saveSyncEndpoint(endpoint: string): void {
  const store: preferences.Preferences | null = openStore();
  if (store === null) {
    return;
  }
  try {
    store.putSync(KEY_ENDPOINT, endpoint);
    flushSilently(store);
  } catch (error) {
    // 偏好不可用时仅丢失持久化。
  }
}

/** 注销时清空三键。失败时静默。 */
export function clearSyncAuth(): void {
  const store: preferences.Preferences | null = openStore();
  if (store === null) {
    return;
  }
  try {
    store.deleteSync(KEY_HKEY);
    store.deleteSync(KEY_ENDPOINT);
    store.deleteSync(KEY_USERNAME);
    flushSilently(store);
  } catch (error) {
    // 偏好不可用时静默。
  }
}
