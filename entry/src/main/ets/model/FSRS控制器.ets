// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { 牌组配置服务 } from '../backend/牌组配置服务';
import type {
  DeckConfig,
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import { UPDATE_DECK_CONFIGS_MODE_NORMAL } from '../proto/messages/DeckConfigMessages';

const 存储名: string = 'jidecards_settings';
const FSRS已初始化键: string = 'fsrs_initialized';
const 上下文键: string = 'abilityContext';
const 默认牌组ID: number = 1;

function 取上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文键);
  return 上下文 === undefined ? null : 上下文;
}

async function 加载已初始化标记(): Promise<boolean> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return false;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 值: preferences.ValueType = await 存储.get(FSRS已初始化键, false);
    return 值 === true;
  } catch (错误) {
    return false;
  }
}

async function 标记已初始化(): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 取上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(FSRS已初始化键, true);
    await 存储.flush();
  } catch (错误) {
  }
}

function 构造请求(视图: DeckConfigsForUpdateView, fsrs开关: boolean, fsrs重调度: boolean): UpdateDeckConfigsInput {
  const 配置列表: DeckConfig[] = [];
  for (let i: number = 0; i < 视图.allConfigs.length; i++) {
    配置列表.push(视图.allConfigs[i].config);
  }
  return {
    targetDeckId: 默认牌组ID,
    configs: 配置列表,
    removedConfigIds: [],
    mode: UPDATE_DECK_CONFIGS_MODE_NORMAL,
    cardStateCustomizer: 视图.cardStateCustomizer,
    limits: 视图.currentDeck === null ? null : 视图.currentDeck.limits,
    newCardsIgnoreReviewLimit: 视图.newCardsIgnoreReviewLimit,
    fsrs: fsrs开关,
    applyAllParentLimits: 视图.applyAllParentLimits,
    fsrsReschedule: fsrs重调度,
    fsrsHealthCheck: 视图.fsrsHealthCheck
  };
}

export async function 确保FSRS已开启一次(): Promise<void> {
  const 已初始化: boolean = await 加载已初始化标记();
  if (已初始化) {
    return;
  }
  const 服务: 牌组配置服务 = new 牌组配置服务();
  try {
    const 视图: DeckConfigsForUpdateView = await 服务.获取牌组配置编辑视图(默认牌组ID);
    if (!视图.fsrs) {
      const 请求: UpdateDeckConfigsInput = 构造请求(视图, true, true);
      await 服务.更新牌组配置(请求);
    }
  } catch (错误) {
    return;
  }
  await 标记已初始化();
}

export async function 设置FSRS开启状态(开启: boolean): Promise<boolean> {
  const 服务: 牌组配置服务 = new 牌组配置服务();
  const 视图: DeckConfigsForUpdateView = await 服务.获取牌组配置编辑视图(默认牌组ID);
  const 请求: UpdateDeckConfigsInput = 构造请求(视图, 开启, 开启);
  await 服务.更新牌组配置(请求);
  return 开启;
}

export async function 加载FSRS开启状态(): Promise<boolean | null> {
  const 服务: 牌组配置服务 = new 牌组配置服务();
  try {
    const 视图: DeckConfigsForUpdateView = await 服务.获取牌组配置编辑视图(默认牌组ID);
    return 视图.fsrs;
  } catch (错误) {
    return null;
  }
}
