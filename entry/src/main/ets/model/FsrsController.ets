// FSRS（Free Spaced Repetition Scheduler）全局开关控制器。
//
// Anki 的 fsrs 字段是 collection 级全局 flag（不是 per-deck）：整个 collection 要么
// 全用 FSRS，要么全用 SM-2，二选一。Anki 24.04 起官方推荐默认开启 FSRS。
//
// 本控制器提供两个能力：
// 1. ensureFsrsEnabledOnce(): App 首次启动时若 fsrs=false 则自动开启一次，并写
//    `fsrs_initialized` 标记；之后用户在设置页关闭就保持关闭，下次启动不再自动开启。
// 2. setFsrsEnabled(value): 设置页切换开关时回写到后端，保留 view 中其他字段不丢。
//
// 实现要点：
// - targetDeckId 用 Default deck (id=1)。Anki 约定 Default deck 不可删除且 id 固定，
//   fsrs 字段与 targetDeckId 无关，只是后端用 targetDeckId 定位 currentDeck.limits。
// - configs 数组只回传 view.allConfigs 里的所有 config，原样保真（含 preserved 字节）。
// - fsrsReschedule：view 里没有这个字段；开启 FSRS 时设 true（让卡片按新算法重新调度），
//   关闭时设 false（无新算法需要应用）。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DeckConfigService } from '../backend/DeckConfigService';
import type {
  DeckConfig,
  DeckConfigsForUpdateView,
  UpdateDeckConfigsInput
} from '../proto/messages/DeckConfigMessages';
import { UPDATE_DECK_CONFIGS_MODE_NORMAL } from '../proto/messages/DeckConfigMessages';

const STORE_NAME: string = 'jidecards_settings';
const FSRS_INITIALIZED_KEY: string = 'fsrs_initialized';
const CONTEXT_KEY: string = 'abilityContext';
const DEFAULT_DECK_ID: number = 1;

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

async function loadInitialized(): Promise<boolean> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return false;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const value: preferences.ValueType = await store.get(FSRS_INITIALIZED_KEY, false);
    return value === true;
  } catch (error) {
    return false;
  }
}

async function markInitialized(): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(FSRS_INITIALIZED_KEY, true);
    await store.flush();
  } catch (error) {
    // 偏好不可用时不阻断；下次启动可能再次尝试开启。
  }
}

/** 从 view 构造 UpdateDeckConfigsInput，仅覆盖 fsrs/fsrsReschedule，其他字段原样回传。 */
function buildRequest(view: DeckConfigsForUpdateView, fsrs: boolean, fsrsReschedule: boolean): UpdateDeckConfigsInput {
  const configs: DeckConfig[] = [];
  for (let i: number = 0; i < view.allConfigs.length; i++) {
    configs.push(view.allConfigs[i].config);
  }
  return {
    targetDeckId: DEFAULT_DECK_ID,
    configs: configs,
    removedConfigIds: [],
    mode: UPDATE_DECK_CONFIGS_MODE_NORMAL,
    cardStateCustomizer: view.cardStateCustomizer,
    limits: view.currentDeck === null ? null : view.currentDeck.limits,
    newCardsIgnoreReviewLimit: view.newCardsIgnoreReviewLimit,
    fsrs: fsrs,
    applyAllParentLimits: view.applyAllParentLimits,
    fsrsReschedule: fsrsReschedule,
    fsrsHealthCheck: view.fsrsHealthCheck
  };
}

/**
 * App 首次启动时调用一次：若 fsrs 未初始化且当前为 false，则自动开启 FSRS。
 * 已初始化过则跳过，保留用户后续在设置页的关闭状态。
 * 失败静默降级，不阻断首页加载。
 */
export async function ensureFsrsEnabledOnce(): Promise<void> {
  const initialized: boolean = await loadInitialized();
  if (initialized) {
    return;
  }
  const service: DeckConfigService = new DeckConfigService();
  try {
    const view: DeckConfigsForUpdateView = await service.getDeckConfigsForUpdate(DEFAULT_DECK_ID);
    if (!view.fsrs) {
      const request: UpdateDeckConfigsInput = buildRequest(view, true, true);
      await service.updateDeckConfigs(request);
    }
  } catch (error) {
    // 后端不可用时不写 initialized 标记，下次启动重试。
    return;
  }
  await markInitialized();
}

/**
 * 设置页切换 FSRS 开关：拉取最新 view 后仅覆盖 fsrs/fsrsReschedule 字段回写。
 * 返回最终落盘的 fsrs 值（成功时与入参一致；失败时抛出异常，由调用方决定回滚 UI）。
 */
export async function setFsrsEnabled(enabled: boolean): Promise<boolean> {
  const service: DeckConfigService = new DeckConfigService();
  const view: DeckConfigsForUpdateView = await service.getDeckConfigsForUpdate(DEFAULT_DECK_ID);
  const request: UpdateDeckConfigsInput = buildRequest(view, enabled, enabled);
  await service.updateDeckConfigs(request);
  return enabled;
}

/**
 * 读取当前 FSRS 开关状态（从后端 view 拉）。设置页打开时调用一次同步 UI。
 * 失败时返回 null，UI 可显示"加载失败"或隐藏开关。
 */
export async function loadFsrsEnabled(): Promise<boolean | null> {
  const service: DeckConfigService = new DeckConfigService();
  try {
    const view: DeckConfigsForUpdateView = await service.getDeckConfigsForUpdate(DEFAULT_DECK_ID);
    return view.fsrs;
  } catch (error) {
    return null;
  }
}
