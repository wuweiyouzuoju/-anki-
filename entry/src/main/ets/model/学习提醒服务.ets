// SPDX-License-Identifier: AGPL-3.0-or-later

import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { 加载学习提醒设置, 保存提醒ID列表, 提醒项 } from './学习提醒存储';
import { 牌组服务 } from '../backend/牌组服务';
import { 后端会话 } from '../backend/后端会话';
import { common } from '@kit.AbilityKit';
import type { DeckTreeNode } from '../proto/messages/DeckMessages';

const 包名: string = 'com.jide.kapian';
const 能力名: string = 'EntryAbility';
const 默认标题: string = 'jidecards 学习提醒';
const 默认内容模板: string = '今日待学习 {{待学}} 张，待复习 {{待复习}} 张';

// ========================================================
// @名称 计算待学数量
// @作用 拉取牌组树，汇总 newCount + learnCount（待学）和 reviewCount（待复习）
// ========================================================
async function 计算待学数量(): Promise<[number, number]> {
  try {
    const 上下文: common.UIAbilityContext | undefined =
      AppStorage.get<common.UIAbilityContext>('abilityContext');
    if (上下文 === undefined) {
      return [0, 0];
    }
    await 后端会话.获取实例().确保已打开(上下文.filesDir);
    const 服务: 牌组服务 = new 牌组服务();
    const 树: DeckTreeNode = await 服务.获取牌组树();
    let 待学: number = 0;
    let 待复习: number = 0;
    for (let i: number = 0; i < 树.children.length; i++) {
      const 节点 = 树.children[i];
      待学 += 节点.newCount + 节点.learnCount;
      待复习 += 节点.reviewCount;
    }
    return [待学, 待复习];
  } catch (错误) {
    return [0, 0];
  }
}

// ========================================================
// @名称 替换占位符
// @作用 把 {{待学}} {{待复习}}（中文）或 {{new}} {{review}}（英文）替换成实际数字；
//       无占位符的文案原样返回。双占位符兼容旧用户已存中文文案与新英文 UI。
// ========================================================
function 替换占位符(模板: string, 待学数: number, 待复习数: number): string {
  return 模板
    .replace(/{{待学}}|{{new}}/g, `${待学数}`)
    .replace(/{{待复习}}|{{review}}/g, `${待复习数}`);
}

// ========================================================
// @名称 发布单个提醒
// @作用 发布一个每日固定时间的闹钟型提醒，标题/内容用用户自定义或默认
// ========================================================
async function 发布单个提醒(
  项: 提醒项,
  待学数: number,
  待复习数: number
): Promise<number> {
  const 标题: string = 项.标题.length > 0 ? 项.标题 : 默认标题;
  const 内容模板: string = 项.内容.length > 0 ? 项.内容 : 默认内容模板;
  const 内容: string = 替换占位符(内容模板, 待学数, 待复习数);
  const 提醒请求: reminderAgentManager.ReminderRequestAlarm = {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
    hour: 项.小时,
    minute: 项.分钟,
    title: 标题,
    content: 内容,
    actionButton: [
      {
        title: '打开',
        type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
      }
    ],
    wantAgent: {
      pkgName: 包名,
      abilityName: 能力名
    },
    maxScreenWantAgent: {
      pkgName: 包名,
      abilityName: 能力名
    }
  };
  return await reminderAgentManager.publishReminder(提醒请求);
}

// ========================================================
// @名称 取消所有已发布提醒
// ========================================================
export async function 取消所有学习提醒(): Promise<void> {
  await reminderAgentManager.cancelAllReminders();
}

// ========================================================
// @名称 刷新学习提醒
// @作用 读取持久化设置，取消旧提醒 + 发布新提醒（带最新待学数量）
// @使用时机 App 启动 / 复习后 / 设置变更
// ========================================================
export async function 刷新学习提醒(): Promise<void> {
  const 设置 = await 加载学习提醒设置();
  // 先取消所有旧提醒
  await 取消所有学习提醒();
  // 计算当前待学数量（仅在有开启的提醒项时才查）
  let 任一开启: boolean = false;
  for (let i: number = 0; i < 设置.提醒项列表.length; i++) {
    if (设置.提醒项列表[i].开启) {
      任一开启 = true;
      break;
    }
  }
  if (!任一开启) {
    return;
  }
  const 数量: [number, number] = await 计算待学数量();
  // 为每个开启的提醒项发布一个提醒
  const 新ID列表: number[] = [];
  for (let i: number = 0; i < 设置.提醒项列表.length; i++) {
    if (!设置.提醒项列表[i].开启) {
      continue;
    }
    try {
      const id: number = await 发布单个提醒(设置.提醒项列表[i], 数量[0], 数量[1]);
      新ID列表.push(id);
    } catch (错误) {
      // 单个发布失败不阻塞其他
    }
  }
  await 保存提醒ID列表(新ID列表);
}
