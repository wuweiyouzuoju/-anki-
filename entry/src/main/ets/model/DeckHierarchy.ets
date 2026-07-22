// SPDX-License-Identifier: AGPL-3.0-or-later

import type { DeckTreeNode } from '../proto/messages/DeckMessages';
import { DeckTone } from './HomeModels';
import type { DeckSummary } from './HomeModels';

const TONE_ROTATION: DeckTone[] = [DeckTone.Blue, DeckTone.Purple, DeckTone.Mint, DeckTone.Amber];

/** Converts accepted Chinese and ASCII hierarchy separators to Anki's `::` form. */
export function normalizeDeckPath(raw: string): string | null {
  let normalized: string = raw.trim()
    .replace(/：/g, '::')
    .replace(/:{3,}/g, '::');
  normalized = normalized.replace(/(^|[^:]):(?=[^:]|$)/g, '$1::');
  const parts: string[] = normalized.split('::').map((part: string): string => part.trim());
  if (parts.length === 0 || parts.some((part: string): boolean => part.length === 0)) {
    return null;
  }
  return parts.join('::');
}

/** Combines a selected parent and user-provided leaf into a normalized full deck path. */
export function composeDeckPath(parentPath: string, leaf: string): string | null {
  const normalizedLeaf: string | null = normalizeDeckPath(leaf);
  if (normalizedLeaf === null) {
    return null;
  }
  const normalizedParent: string | null = parentPath === '' ? '' : normalizeDeckPath(parentPath);
  if (normalizedParent === null) {
    return null;
  }
  return normalizedParent === '' ? normalizedLeaf : `${normalizedParent}::${normalizedLeaf}`;
}

/** Flattens Anki's synthetic root into preorder rows without changing backend aggregate counts.
 *  toneOverrides：deckId → DeckTone，若该牌组有持久化记录则覆盖自动轮转；未传入时走原有轮转逻辑。
 *  displayNameOverrides：deckId → 自定义别名，命中时填入 DeckSummary.displayName（空串表示无覆盖）。
 *  orderOverrides：parentId → 子 deckId[]，按此顺序重排同 parent 的兄弟节点；未命中或子项不存在时保留原序追加。
 *    parentId='' 表示顶层（root 的直接子节点）。覆盖仅在前端展示层生效，后端 DeckTreeNode.children 顺序不变。
 *  backgroundImageOverrides：deckId → 沙盒背景图绝对路径，命中且非空时填入 DeckSummary.backgroundImage；
 *    未命中或 Map 为 null 时保持空串，DeckListItem 走原 surface_card 背景。 */
export function flattenDeckTree(root: DeckTreeNode,
  toneOverrides: Map<string, DeckTone> | null = null,
  displayNameOverrides: Map<string, string> | null = null,
  orderOverrides: Map<string, string[]> | null = null,
  backgroundImageOverrides: Map<string, string> | null = null): DeckSummary[] {
  const rows: DeckSummary[] = [];

  const visit = (node: DeckTreeNode, fullName: string, depth: number,
    parentId: string, ancestorIds: string[]):void => {
    const id: string = node.deckId.toString();
    // fallback tone 用 deckId 稳定 hash 而非 rows.length 索引：
    // 这样未主动设 tone 的牌组色条固定（与位置无关），用户拖动排序后色条不变。
    // 旧实现用 rows.length % len 会让连续创建的 deck 自动轮转 4 色，但拖动后位置变 fallback tone 跟着变，
    // 与用户期望「色条跟着牌组走」矛盾。
    const fallback: DeckTone = TONE_ROTATION[Math.abs(node.deckId) % TONE_ROTATION.length];
    const override: DeckTone | undefined =
      toneOverrides !== null ? toneOverrides.get(id) : undefined;
    const tone: DeckTone = override === undefined ? fallback : override;
    const displayName: string =
      displayNameOverrides !== null ? (displayNameOverrides.get(id) ?? '') : '';
    const backgroundImage: string =
      backgroundImageOverrides !== null ? (backgroundImageOverrides.get(id) ?? '') : '';
    rows.push({
      id: id,
      name: node.name,
      fullName: fullName,
      depth: depth,
      parentId: parentId,
      hasChildren: node.children.length > 0,
      ancestorIds: ancestorIds,
      description: '',
      newCount: node.newCount,
      learningCount: node.learnCount,
      reviewCount: node.reviewCount,
      totalCards: node.totalIncludingChildren,
      tone: tone,
      displayName: displayName,
      backgroundImage: backgroundImage
    });
    const nextAncestors: string[] = ancestorIds.concat(id);
    const orderedChildren: DeckTreeNode[] = reorderChildren(node.children, id, orderOverrides);
    for (const child of orderedChildren) {
      const childFullName: string = fullName === '' ? child.name : `${fullName}::${child.name}`;
      visit(child, childFullName, depth + 1, id, nextAncestors);
    }
  };

  // 顶层 children 用 parentId='' 查找 orderOverrides
  const orderedTop: DeckTreeNode[] = reorderChildren(root.children, '', orderOverrides);
  for (const child of orderedTop) {
    visit(child, child.name, 0, '', []);
  }
  return rows;
}

/**
 * 按用户持久化的顺序重排兄弟节点。
 * 规则：
 *  - orderOverrides 命中 parentId 且 entry 非空：按 entry 中的 id 顺序排
 *  - entry 中未出现的子节点追加到末尾（保留原顺序，防止新增牌组被丢失）
 *  - entry 中存在但 children 中已不存在的 id 跳过（防止删除牌组后顺序卡住）
 */
function reorderChildren(children: DeckTreeNode[], parentId: string,
  orderOverrides: Map<string, string[]> | null): DeckTreeNode[] {
  if (orderOverrides === null || children.length <= 1) {
    return children;
  }
  const orderEntry: string[] | undefined = orderOverrides.get(parentId);
  if (orderEntry === undefined || orderEntry.length === 0) {
    return children;
  }
  // 以 deckId 为索引建子节点查找表
  const byId: Map<string, DeckTreeNode> = new Map<string, DeckTreeNode>();
  for (let i: number = 0; i < children.length; i++) {
    byId.set(children[i].deckId.toString(), children[i]);
  }
  const out: DeckTreeNode[] = [];
  const used: Set<string> = new Set<string>();
  // 先按用户顺序追加
  for (let i: number = 0; i < orderEntry.length; i++) {
    const id: string = orderEntry[i];
    if (used.has(id)) {
      continue;
    }
    const child: DeckTreeNode | undefined = byId.get(id);
    if (child !== undefined) {
      out.push(child);
      used.add(id);
    }
  }
  // 再追加未在 entry 中出现的子节点（按原顺序，防止新增牌组被丢失）
  for (let i: number = 0; i < children.length; i++) {
    const id: string = children[i].deckId.toString();
    if (!used.has(id)) {
      out.push(children[i]);
      used.add(id);
    }
  }
  return out;
}

/** Returns preorder rows whose complete ancestor path has been expanded.
 *  hiddenIds：用户主动隐藏的 deck id 集合，命中的行直接过滤掉（不渲染、不计入列表）。
 *    传 null 或不传等同于空集（无隐藏），保持与旧调用方兼容。 */
export function visibleDeckRows(rows: DeckSummary[], expandedIds: Set<string>,
  hiddenIds: Set<string> | null = null): DeckSummary[] {
  const hidden: Set<string> = hiddenIds ?? new Set<string>();
  return rows.filter((row: DeckSummary): boolean =>
    !hidden.has(row.id) &&
    row.ancestorIds.every((ancestorId: string): boolean => expandedIds.has(ancestorId)));
}
