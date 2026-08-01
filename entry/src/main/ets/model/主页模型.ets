// SPDX-License-Identifier: AGPL-3.0-or-later

export enum 牌组色调 {
  Blue,
  Purple,
  Mint,
  Amber,
  Black,
  Red,
  None
}

export function 解析牌组色调(原始值: string | undefined | null): 牌组色调 | null {
  switch (原始值) {
    case 'blue':
      return 牌组色调.Blue;
    case 'purple':
      return 牌组色调.Purple;
    case 'mint':
      return 牌组色调.Mint;
    case 'amber':
      return 牌组色调.Amber;
    case 'black':
      return 牌组色调.Black;
    case 'red':
      return 牌组色调.Red;
    case 'none':
      return 牌组色调.None;
    default:
      return null;
  }
}

export function 牌组色调键(色调: 牌组色调): string {
  switch (色调) {
    case 牌组色调.Purple:
      return 'purple';
    case 牌组色调.Mint:
      return 'mint';
    case 牌组色调.Amber:
      return 'amber';
    case 牌组色调.Black:
      return 'black';
    case 牌组色调.Red:
      return 'red';
    case 牌组色调.None:
      return 'none';
    case 牌组色调.Blue:
    default:
      return 'blue';
  }
}

export interface 牌组汇总 {
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
  tone: 牌组色调;
  displayName: string;
  backgroundImage: string;
}

export interface 今日学习汇总 {
  completedCount: number;
  pendingCount: number;
  deckCount: number;
}

export type 记忆状态 = 'today_answered' | 'today_empty' | 'load_error' | 'loading';

export interface 记忆表现汇总 {
  state: 记忆状态;
  todayAgainRate: number;
  todayAnsweredCount: number;
  matureCorrectRate: number;
  hasMatureData: boolean;
  averageRetrievability: number;
  hasRetrievability: boolean;
}

export interface 主页快照 {
  today: 今日学习汇总;
  decks: 牌组汇总[];
  reviewCountsByDate: Map<string, number>;
  memory: 记忆表现汇总;
}

export type 主页加载状态 = 'loading' | 'ready' | 'empty' | 'error';

export class 牌组列表数据源 implements IDataSource {
  private 牌组列表: 牌组汇总[];
  private readonly 监听器列表: DataChangeListener[] = [];

  constructor(初始牌组: 牌组汇总[]) {
    this.牌组列表 = 初始牌组;
  }

  totalCount(): number {
    return this.牌组列表.length;
  }

  getData(索引: number): 牌组汇总 {
    return this.牌组列表[索引];
  }

  replaceAll(新牌组: 牌组汇总[]): void {
    this.牌组列表 = 新牌组;
    for (let 索引: number = 0; 索引 < this.监听器列表.length; 索引++) {
      this.监听器列表[索引].onDataReloaded();
    }
  }

  moveItem(起点: number, 终点: number): void {
    if (起点 === 终点 || 起点 < 0 || 终点 < 0
      || 起点 >= this.牌组列表.length || 终点 >= this.牌组列表.length) {
      return;
    }
    const 移动项: 牌组汇总 = this.牌组列表[起点];
    this.牌组列表.splice(起点, 1);
    this.牌组列表.splice(终点, 0, 移动项);
    for (let 索引: number = 0; 索引 < this.监听器列表.length; 索引++) {
      this.监听器列表[索引].onDataReloaded();
    }
  }

  snapshotDecks(): 牌组汇总[] {
    return this.牌组列表.slice();
  }

  registerDataChangeListener(监听器: DataChangeListener): void {
    if (this.监听器列表.indexOf(监听器) < 0) {
      this.监听器列表.push(监听器);
    }
  }

  unregisterDataChangeListener(监听器: DataChangeListener): void {
    const 索引: number = this.监听器列表.indexOf(监听器);
    if (索引 >= 0) {
      this.监听器列表.splice(索引, 1);
    }
  }
}

export function 待办数(牌组: 牌组汇总): number {
  return 牌组.newCount + 牌组.learningCount + 牌组.reviewCount;
}

export function 牌组显示名(牌组: 牌组汇总): string {
  return 牌组.displayName !== '' ? 牌组.displayName : 牌组.name;
}

export const 空牌组汇总: 牌组汇总 = {
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
  tone: 牌组色调.Blue,
  displayName: '',
  backgroundImage: ''
};

export const 空主页快照: 主页快照 = {
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
