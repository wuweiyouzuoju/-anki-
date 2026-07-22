// SPDX-License-Identifier: AGPL-3.0-or-later

export enum DeckTone {
  Blue,
  Purple,
  Mint,
  Amber,
  Black,
  Red,
  None
}

/** 把持久化的字符串值安全转回 DeckTone；非法/未设置时返回 null。 */
export function parseDeckTone(raw: string | undefined | null): DeckTone | null {
  switch (raw) {
    case 'blue':
      return DeckTone.Blue;
    case 'purple':
      return DeckTone.Purple;
    case 'mint':
      return DeckTone.Mint;
    case 'amber':
      return DeckTone.Amber;
    case 'black':
      return DeckTone.Black;
    case 'red':
      return DeckTone.Red;
    case 'none':
      return DeckTone.None;
    default:
      return null;
  }
}

/** DeckTone → 持久化字符串值。 */
export function deckToneKey(tone: DeckTone): string {
  switch (tone) {
    case DeckTone.Purple:
      return 'purple';
    case DeckTone.Mint:
      return 'mint';
    case DeckTone.Amber:
      return 'amber';
    case DeckTone.Black:
      return 'black';
    case DeckTone.Red:
      return 'red';
    case DeckTone.None:
      return 'none';
    case DeckTone.Blue:
    default:
      return 'blue';
  }
}

export interface DeckSummary {
  id: string;
  name: string;
  fullName: string;
  depth: number;
  parentId: string;
  hasChildren: boolean;
  ancestorIds: string[];
  description: string;
  newCount: number;
  learningCount: number;
  reviewCount: number;
  totalCards: number;
  tone: DeckTone;
  // 用户自定义别名（来自本地 preferences，不动后端 deck name）。
  // 空串表示无覆盖，UI 显示时回退到 name；非空时 UI 优先显示此值。
  displayName: string;
  // 牌组背景图沙盒路径（来自本地 preferences + filesDir，不动后端）。
  // 空串表示无背景图，DeckListItem 走原 surface_card 背景；非空时 Stack 底层叠 Image(objectFit=Cover)。
  backgroundImage: string;
}

export interface StudySummary {
  completedCount: number;
  pendingCount: number;
  deckCount: number;
}

// 记忆状态卡片的展示状态（B12-X 改造 2026-07-21）：
// 旧实现基于 retrievability.average（全库 FSRS 卡平均可提取率），但这是"全库平均"而非"今日表现"，
// 用户主观感受"今天答不会的卡很多"会被全库 mature 卡拉高的 97% 掩盖（详见 decisions.md B12-X）。
// 新口径改用 Anki Desktop today.ts 同款算法：today.againRate = (answer - correct) / answer。
// - today_answered: 今天已答卡，显示今日不会率 + mature 正确率 + 全库平均可提取率（副标题）
// - today_empty: 今天还没答卡，空态提示去学习
// - load_error: graphs 拉取失败
// - loading: 首次拉取中
export type MemoryState = 'today_answered' | 'today_empty' | 'load_error' | 'loading';

export interface MemorySummary {
  state: MemoryState;
  // 主指标：今日不会率（0-1）= (answerCount - correctCount) / answerCount
  // state='today_answered' 时有意义；其余状态保持 0。
  todayAgainRate: number;
  // 今日已答次数（副标题"今日共答 N 次"用），仅 today_answered 时 > 0
  todayAnsweredCount: number;
  // 今日 mature 卡正确率（0-1，副标题用）
  // hasMatureData=false 时 matureCorrectRate 保持 0 且不显示
  matureCorrectRate: number;
  hasMatureData: boolean;
  // 全库平均可提取率（0-1，副标题用）
  // hasRetrievability=false 时（FSRS 未开 / 无 memory_state 卡）保持 0 且不显示
  averageRetrievability: number;
  hasRetrievability: boolean;
}

export interface HomeSnapshot {
  today: StudySummary;
  decks: DeckSummary[];
  reviewCountsByDate: Map<string, number>;
  memory: MemorySummary;
}

export type HomeLoadState = 'loading' | 'ready' | 'empty' | 'error';

export class DeckDataSource implements IDataSource {
  private decks: DeckSummary[];
  private readonly listeners: DataChangeListener[] = [];

  constructor(decks: DeckSummary[]) {
    this.decks = decks;
  }

  totalCount(): number {
    return this.decks.length;
  }

  getData(index: number): DeckSummary {
    return this.decks[index];
  }

  replaceAll(decks: DeckSummary[]): void {
    this.decks = decks;
    for (let index: number = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }

  /**
   * 拖拽排序：把 from 位置的项移动到 to 位置（仅内存，不落盘；调用方需另行 saveDeckOrder）。
   * ArkUI List.onMove 回调语义：from > to 表示前移，from < to 表示后移。
   * 实现按 splice 移除再插入，与 ArkUI 默认预期一致。
   * 调用方需自行校验 from/to 在同一 parent（同 depth 同 ancestorIds），跨 parent 不允许移动。
   */
  moveItem(from: number, to: number): void {
    if (from === to || from < 0 || to < 0
      || from >= this.decks.length || to >= this.decks.length) {
      return;
    }
    const moved: DeckSummary = this.decks[from];
    this.decks.splice(from, 1);
    this.decks.splice(to, 0, moved);
    for (let index: number = 0; index < this.listeners.length; index++) {
      this.listeners[index].onDataReloaded();
    }
  }

  /** 取当前列表数据快照（用于计算某 parent 下的最新顺序并持久化）。 */
  snapshotDecks(): DeckSummary[] {
    return this.decks.slice();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }
}

export function pendingCount(deck: DeckSummary): number {
  return deck.newCount + deck.learningCount + deck.reviewCount;
}

/** UI 显示用的牌组名：有 displayName 覆盖时优先用，否则回退到后端真实 name。 */
export function deckDisplayName(deck: DeckSummary): string {
  return deck.displayName !== '' ? deck.displayName : deck.name;
}

export const EMPTY_DECK_SUMMARY: DeckSummary = {
  id: '',
  name: '',
  fullName: '',
  depth: 0,
  parentId: '',
  hasChildren: false,
  ancestorIds: [],
  description: '',
  newCount: 0,
  learningCount: 0,
  reviewCount: 0,
  totalCards: 0,
  tone: DeckTone.Blue,
  displayName: '',
  backgroundImage: ''
};

export const EMPTY_HOME_SNAPSHOT: HomeSnapshot = {
  today: {
    completedCount: 0,
    pendingCount: 0,
    deckCount: 0
  },
  decks: [],
  reviewCountsByDate: new Map<string, number>(),
  memory: {
    state: 'loading',
    todayAgainRate: 0,
    todayAnsweredCount: 0,
    matureCorrectRate: 0,
    hasMatureData: false,
    averageRetrievability: 0,
    hasRetrievability: false
  }
};
