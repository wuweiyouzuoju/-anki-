// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-SYNC-AUTH-001
// @名称 AnkiWeb 同步凭证本地持久化
//
// @作用
// 持久化 AnkiWeb 登录成功后的会话令牌 hkey / endpoint / username 到本地
// （M10-T14 云同步）。应用重启后可直接携带 hkey 访问同步接口，
// 实现「重启免登录」；hkey 失效（401）时由调用方走重新登录流程并覆盖。
//
// @输入
// 无（读取）；SyncAuthInfo（保存）；endpoint: string（仅更新端点）
//
// @输出
// 保存同步凭证(auth): void
// 加载同步凭证(): SyncAuthInfo | null
// 保存同步端点(endpoint): void
// 清除同步凭证(): void
//
// @业务规则
// 安全红线：用户密码绝不落盘——本 store 只保存 hkey / endpoint / username，
// 登录请求中的密码仅在内存中短暂存在，登录成功后立即丢弃。
// 同步 API（getPreferencesSync/putSync/getSync/deleteSync）：
// 登录态读取在启动路径上需同步返回，避免 UI 闪烁；
// flush 为 fire-and-forget，写盘失败静默（与既有 store 策略一致）。
//
// @副作用
// 读写 preferences 的 jidecards_sync store。
//
// @注意
// preferences 中的字符串键（'jidecards_sync' / 'sync_hkey' /
// 'sync_endpoint' / 'sync_username' / 'abilityContext'）
// 属持久化协议字段，保留英文，不可中文化。
// ========================================================

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_sync';
const HKEY键: string = 'sync_hkey';
const 端点键: string = 'sync_endpoint';
const 用户名键: string = 'sync_username';
const 上下文键: string = 'abilityContext';

// ========================================================
// @块ID MODEL-SYNC-AUTH-002
// @名称 同步凭证信息
//
// @作用
// 描述一次成功登录后的 AnkiWeb 同步凭证。
//
// @输入
// 无（数据结构定义）
//
// @输出
// 字段：
// hkey - AnkiWeb 会话令牌（登录成功后后端下发）
// username - 登录用户名（仅用于 UI 展示，不参与鉴权）
// endpoint - 自定义同步端点；空串 = 官方 AnkiWeb 默认端点
//
// @副作用
// 无
// ========================================================
export interface 同步凭证信息 {
  /** AnkiWeb 会话令牌（登录成功后后端下发） */
  hkey: string;
  /** 登录用户名（仅用于 UI 展示，不参与鉴权） */
  username: string;
  /** 自定义同步端点；空串 = 官方 AnkiWeb 默认端点 */
  endpoint: string;
}

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

/** 获取 preferences 实例；context 缺失或 API 异常时返回 null。 */
function 打开存储(): preferences.Preferences | null {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return null;
  }
  try {
    return preferences.getPreferencesSync(上下文, { name: 存储名 });
  } catch (错误) {
    return null;
  }
}

/** 异步落盘（fire-and-forget）：putSync/deleteSync 已更新内存缓存，flush 仅保证写盘。 */
function 静默落盘(存储: preferences.Preferences): void {
  存储.flush().then((): void => {
    // 写盘完成，无需处理
  }).catch((): void => {
    // 写盘失败静默：内存缓存已生效，极端情况下重启后回退到上次成功落盘的值
  });
}

function 读取字符串(存储: preferences.Preferences, 键: string): string {
  const 值: preferences.ValueType = 存储.getSync(键, '');
  return typeof 值 === 'string' ? 值 : '';
}

// ========================================================
// @块ID MODEL-SYNC-AUTH-003
// @名称 保存同步凭证
//
// @作用
// 保存登录成功后的同步凭证（三键一次落盘）。
//
// @输入
// auth: 同步凭证信息（endpoint 可为空串，表示官方默认端点）
//
// @输出
// void。失败时静默——内存缓存已更新。
//
// @副作用
// 同步写入 preferences 的 sync_hkey / sync_endpoint / sync_username，
// 并触发 fire-and-forget flush。
// ========================================================
export function 保存同步凭证(凭证: 同步凭证信息): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.putSync(HKEY键, 凭证.hkey);
    存储.putSync(端点键, 凭证.endpoint);
    存储.putSync(用户名键, 凭证.username);
    静默落盘(存储);
  } catch (错误) {
    // 偏好不可用时仅丢失持久化，不阻塞登录流程。
  }
}

// ========================================================
// @块ID MODEL-SYNC-AUTH-004
// @名称 加载同步凭证
//
// @作用
// 读取本地同步凭证。
//
// @输入
// 无
//
// @输出
// SyncAuthInfo | null：hkey 为空串或不存在时返回 null
// （视为未登录，调用方走登录流程）。
//
// @副作用
// 只读 preferences，不写入。
// ========================================================
export function 加载同步凭证(): 同步凭证信息 | null {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return null;
  }
  try {
    const hkey: string = 读取字符串(存储, HKEY键);
    if (hkey.length === 0) {
      return null;
    }
    const 信息: 同步凭证信息 = {
      hkey: hkey,
      username: 读取字符串(存储, 用户名键),
      endpoint: 读取字符串(存储, 端点键)
    };
    return 信息;
  } catch (错误) {
    return null;
  }
}

// ========================================================
// @块ID MODEL-SYNC-AUTH-005
// @名称 保存同步端点
//
// @作用
// 仅更新 endpoint（服务端下发 new_endpoint 时调用），hkey/username 保持不变。
//
// @输入
// endpoint: string - 新同步端点
//
// @输出
// void
//
// @副作用
// 同步写入 preferences 的 sync_endpoint，并触发 fire-and-forget flush。
// ========================================================
export function 保存同步端点(端点: string): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.putSync(端点键, 端点);
    静默落盘(存储);
  } catch (错误) {
    // 偏好不可用时仅丢失持久化。
  }
}

// ========================================================
// @块ID MODEL-SYNC-AUTH-006
// @名称 清除同步凭证
//
// @作用
// 注销时清空三键。
//
// @输入
// 无
//
// @输出
// void。失败时静默。
//
// @副作用
// 删除 preferences 中的 sync_hkey / sync_endpoint / sync_username，
// 并触发 fire-and-forget flush。
// ========================================================
export function 清除同步凭证(): void {
  const 存储: preferences.Preferences | null = 打开存储();
  if (存储 === null) {
    return;
  }
  try {
    存储.deleteSync(HKEY键);
    存储.deleteSync(端点键);
    存储.deleteSync(用户名键);
    静默落盘(存储);
  } catch (错误) {
    // 偏好不可用时静默。
  }
}
