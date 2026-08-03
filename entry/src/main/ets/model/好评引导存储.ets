// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @名称 好评引导弹窗「只弹一次」持久化
//
// @作用
// 用户完成一份牌组学习回到主页后，弹一次好评引导弹窗，引导用户去华为应用市场
// 评分或发意见反馈。为避免每次学习完成都打扰用户，用 preferences 持久化
// 「已展示过」标记，仅在用户首次完成学习后弹一次。
//
// @输入
// 无（内部从 AppStorage 取 abilityContext）
//
// @输出
// 是否已展示好评引导(): Promise<boolean>
// 标记已展示好评引导(): Promise<void>
//
// @业务规则
// 复用 AnkiWeb引导存储 的「只弹一次」模式：STORE_NAME 同为 jidecards_settings，
// KEY 为 rate_guide_shown。失败静默降级，不阻断首页加载；
// 最坏情况下下次学习完成可能再弹一次。
//
// @副作用
// 读写 preferences（@kit.ArkData）的 jidecards_settings store。
//
// @注意
// preferences 中的字符串键（'jidecards_settings' / 'rate_guide_shown' /
// 'abilityContext'）属持久化协议字段，保留英文，不可中文化。
// ========================================================

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const 引导已展示键: string = 'rate_guide_shown';
const 上下文键: string = 'abilityContext';

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

// ========================================================
// @名称 是否已展示好评引导
//
// @作用
// 查询本地 preferences 中好评引导弹窗是否已经展示过。
//
// @输入
// 无
//
// @输出
// Promise<boolean>：true=已展示过（不再弹）；false=未展示或读取失败（可再次尝试展示）。
//
// @副作用
// 只读 preferences，不写入。
// ========================================================
export async function 是否已展示好评引导(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return false;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(引导已展示键, false);
    return 值 === true;
  } catch (错误) {
    return false;
  }
}

// ========================================================
// @名称 标记已展示好评引导
//
// @作用
// 在好评引导弹窗展示完成后写入 preferences，标记本次设备已展示过。
//
// @输入
// 无
//
// @输出
// Promise<void>。失败静默降级，下次学习完成可能再弹一次。
//
// @副作用
// 写入 preferences 的 rate_guide_shown=true 并 flush 落盘。
// ========================================================
export async function 标记已展示好评引导(): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(引导已展示键, true);
    await 存储.flush();
  } catch (错误) {
    // 偏好不可用时不阻断；下次学习完成可能再次尝试展示。
  }
}
