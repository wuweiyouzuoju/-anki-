// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-STUDY-REMINDER-STORE-001
// @名称 学习提醒持久化
//
// @作用
// 「定时学习提醒」的开关 + 提醒项列表（每项含小时/分钟/标题/内容）+ reminderId 列表持久化。
// 支持用户自由新建多个提醒，每个提醒可独立设置时间和文案。
//
// @输入
// 无（读取）；开启/提醒项列表/reminderId列表（保存）
//
// @输出
// 加载学习提醒设置(): Promise<学习提醒设置>
// 保存学习提醒设置(开启, 提醒项列表): Promise<void>
// 保存提醒ID列表(ids): Promise<void>
// 加载提醒ID列表(): Promise<number[]>
//
// @业务规则
// - 默认关闭（开启=false），默认含 1 个提醒项（21:00）
// - 每个提醒项有唯一 ID（用于增删改）
// - reminderId 列表用于取消已发布的提醒
//
// @副作用
// 读写 preferences 的 jidecards_settings store
// ========================================================

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const 存储名: string = 'jidecards_settings';
const 提醒项列表键: string = 'study_reminder_items';
const 提醒ID列表键: string = 'study_reminder_ids';
const 通知设置已引导键: string = 'reminder_notification_guided';
const 上下文键: string = 'abilityContext';

// 跨组件广播键名
export const 学习提醒AppStorage键: string = 'studyReminderEnabled';

export interface 提醒项 {
  唯一ID: number; // 用于 UI 增删改标识
  小时: number; // 0-23
  分钟: number; // 0-59
  标题: string; // 通知标题（空则用默认）
  内容: string; // 通知内容（空则用默认，支持 {{待学}} {{待复习}} 占位符）
  开启: boolean; // 单项开关，关闭则不发布该提醒
}

export interface 学习提醒设置 {
  提醒项列表: 提醒项[];
}

let 下一个ID: number = 1;

export function 生成提醒项ID(): number {
  return 下一个ID++;
}

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

function 默认提醒项列表(): 提醒项[] {
  return [];
}

export async function 加载学习提醒设置(): Promise<学习提醒设置> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return { 提醒项列表: 默认提醒项列表() };
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 项串: preferences.ValueType = await 存储.get(提醒项列表键, '');
    let 提醒项列表: 提醒项[] = 默认提醒项列表();
    if (typeof 项串 === 'string' && 项串.length > 0) {
      try {
        const 解析: 提醒项[] = JSON.parse(项串) as 提醒项[];
        // 兼容旧数据：无"开启"字段的补 true
        for (let i: number = 0; i < 解析.length; i++) {
          if (解析[i].开启 === undefined) {
            解析[i].开启 = true;
          }
        }
        提醒项列表 = 解析;
        // 更新下一个 ID 计数器
        let 最大ID: number = 0;
        for (let i: number = 0; i < 提醒项列表.length; i++) {
          if (提醒项列表[i].唯一ID > 最大ID) {
            最大ID = 提醒项列表[i].唯一ID;
          }
        }
        下一个ID = 最大ID + 1;
      } catch (_解析错误) {
        // JSON 解析失败用默认值
      }
    }
    return { 提醒项列表 };
  } catch (错误) {
    return { 提醒项列表: 默认提醒项列表() };
  }
}

export async function 保存学习提醒设置(提醒项列表: 提醒项[]): Promise<void> {
  // 是否有任意提醒开启，写入 AppStorage 供其他组件感知
  let 任一开启: boolean = false;
  for (let i: number = 0; i < 提醒项列表.length; i++) {
    if (提醒项列表[i].开启) {
      任一开启 = true;
      break;
    }
  }
  AppStorage.setOrCreate<boolean>(学习提醒AppStorage键, 任一开启);
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(提醒项列表键, JSON.stringify(提醒项列表));
    await 存储.flush();
  } catch (错误) {
    // 持久化失败可接受
  }
}

export async function 保存提醒ID列表(ids: number[]): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(提醒ID列表键, JSON.stringify(ids));
    await 存储.flush();
  } catch (错误) {
    // 失败不阻塞
  }
}

export async function 加载提醒ID列表(): Promise<number[]> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return [];
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 串: preferences.ValueType = await 存储.get(提醒ID列表键, '[]');
    if (typeof 串 === 'string' && 串.length > 0) {
      try {
        return JSON.parse(串) as number[];
      } catch (_解析错误) {
        return [];
      }
    }
    return [];
  } catch (错误) {
    return [];
  }
}

// ========================================================
// @名称 是否已引导通知设置
// @作用 首次成功保存提醒后自动拉起系统通知设置页（引导开横幅通知），
//       本标记记录是否已引导过，之后不再重复拉起。
// ========================================================
export async function 是否已引导通知设置(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return true;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(通知设置已引导键, false);
    return 值 === true;
  } catch (错误) {
    return true;
  }
}

export async function 标记已引导通知设置(): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(通知设置已引导键, true);
    await 存储.flush();
  } catch (错误) {
    // 持久化失败可接受
  }
}
