// SPDX-License-Identifier: AGPL-3.0-or-later

import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import { 牌组色调 } from './主页模型';
import type { 牌组汇总 } from './主页模型';

const 色调轮转池: 牌组色调[] = [牌组色调.Blue, 牌组色调.Purple, 牌组色调.Mint, 牌组色调.Amber];

export function 规范化牌组路径(原始: string): string | null {
  let 规范化结果: string = 原始.trim()
    .replace(/：/g, '::')
    .replace(/:{3,}/g, '::');
  规范化结果 = 规范化结果.replace(/(^|[^:]):(?=[^:]|$)/g, '$1::');
  const 各段: string[] = 规范化结果.split('::').map((段: string): string => 段.trim());
  if (各段.length === 0 || 各段.some((段: string): boolean => 段.length === 0)) {
    return null;
  }
  return 各段.join('::');
}

export function 组合牌组路径(父路径: string, 叶节点: string): string | null {
  const 规范化叶节点: string | null = 规范化牌组路径(叶节点);
  if (规范化叶节点 === null) {
    return null;
  }
  const 规范化父路径: string | null = 父路径 === '' ? '' : 规范化牌组路径(父路径);
  if (规范化父路径 === null) {
    return null;
  }
  return 规范化父路径 === '' ? 规范化叶节点 : `${规范化父路径}::${规范化叶节点}`;
}

export function 平铺牌组树(根节点: DeckTreeNode,
  色调覆盖: Map<string, 牌组色调> | null = null,
  别名覆盖: Map<string, string> | null = null,
  顺序覆盖: Map<string, string[]> | null = null,
  背景图覆盖: Map<string, string> | null = null): 牌组汇总[] {
  const 行集: 牌组汇总[] = [];

  const 访问 = (节点: DeckTreeNode, 完整名: string, 深度: number,
    父ID: string, 祖先ID列表: string[]):void => {
    const 当前ID: string = 节点.deckId.toString();
    const 兜底色调: 牌组色调 = 色调轮转池[Math.abs(节点.deckId) % 色调轮转池.length];
    const 覆盖色调: 牌组色调 | undefined =
      色调覆盖 !== null ? 色调覆盖.get(当前ID) : undefined;
    const 当前色调: 牌组色调 = 覆盖色调 === undefined ? 兜底色调 : 覆盖色调;
    const 当前别名: string =
      别名覆盖 !== null ? (别名覆盖.get(当前ID) ?? '') : '';
    const 当前背景图: string =
      背景图覆盖 !== null ? (背景图覆盖.get(当前ID) ?? '') : '';
    行集.push({
      id: 当前ID,
      name: 节点.name,
      fullName: 完整名,
      depth: 深度,
      parentId: 父ID,
      hasChildren: 节点.children.length > 0,
      ancestorIds: 祖先ID列表,
      description: '',
      newCount: 节点.newCount,
      learningCount: 节点.learnCount,
      reviewCount: 节点.reviewCount,
      totalCards: 节点.totalIncludingChildren,
      tone: 当前色调,
      displayName: 当前别名,
      backgroundImage: 当前背景图
    });
    const 下层祖先: string[] = 祖先ID列表.concat(当前ID);
    const 重排后子节点: DeckTreeNode[] = 重排子节点(节点.children, 当前ID, 顺序覆盖);
    for (const 子节点 of 重排后子节点) {
      const 子节点完整名: string = 完整名 === '' ? 子节点.name : `${完整名}::${子节点.name}`;
      访问(子节点, 子节点完整名, 深度 + 1, 当前ID, 下层祖先);
    }
  };

  const 重排后顶层: DeckTreeNode[] = 重排子节点(根节点.children, '', 顺序覆盖);
  for (const 顶层节点 of 重排后顶层) {
    访问(顶层节点, 顶层节点.name, 0, '', []);
  }
  return 行集;
}

function 重排子节点(子节点列表: DeckTreeNode[], 父ID: string,
  顺序覆盖: Map<string, string[]> | null): DeckTreeNode[] {
  if (顺序覆盖 === null || 子节点列表.length <= 1) {
    return 子节点列表;
  }
  const 顺序项: string[] | undefined = 顺序覆盖.get(父ID);
  if (顺序项 === undefined || 顺序项.length === 0) {
    return 子节点列表;
  }
  const 按ID索引: Map<string, DeckTreeNode> = new Map<string, DeckTreeNode>();
  for (let i: number = 0; i < 子节点列表.length; i++) {
    按ID索引.set(子节点列表[i].deckId.toString(), 子节点列表[i]);
  }
  const 输出: DeckTreeNode[] = [];
  const 已用: Set<string> = new Set<string>();
  for (let i: number = 0; i < 顺序项.length; i++) {
    const 当前ID: string = 顺序项[i];
    if (已用.has(当前ID)) {
      continue;
    }
    const 命中节点: DeckTreeNode | undefined = 按ID索引.get(当前ID);
    if (命中节点 !== undefined) {
      输出.push(命中节点);
      已用.add(当前ID);
    }
  }
  for (let i: number = 0; i < 子节点列表.length; i++) {
    const 当前ID: string = 子节点列表[i].deckId.toString();
    if (!已用.has(当前ID)) {
      输出.push(子节点列表[i]);
      已用.add(当前ID);
    }
  }
  return 输出;
}

export function 可见牌组行(行集: 牌组汇总[], 展开ID集合: Set<string>,
  隐藏ID集合: Set<string> | null = null): 牌组汇总[] {
  const 隐藏集: Set<string> = 隐藏ID集合 ?? new Set<string>();
  return 行集.filter((行: 牌组汇总): boolean =>
    !隐藏集.has(行.id) &&
    行.ancestorIds.every((祖先ID: string): boolean => 展开ID集合.has(祖先ID)));
}
