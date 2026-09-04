// SPDX-License-Identifier: AGPL-3.0-or-later

import { AgentApprovalRequired, createAgentAction } from './AgentAction';

export interface AgentSearchSnapshot {
  id: string;
  kind: string;
  query: string;
  ids: number[];
}
export interface AgentSearchPage {
  ids: number[];
  query: string;
  totalMatched: number;
  nextCursor: string;
  returnedCount: number;
  offset: number;
}
export interface AgentRetrievalState {
  snapshots: AgentSearchSnapshot[];
  readNoteIds: number[];
  approvedNoteIds: number[];
}

/** 稳定 ID 快照分页，查询结果不因页面选择或后续排序变化而漏读。 */
export class AgentRetrieval {
  private snapshots: AgentSearchSnapshot[] = [];
  private readonly readNoteIds: Set<number> = new Set<number>();
  private readonly approvedNoteIds: Set<number> = new Set<number>();
  private sequence: number = 0;

  begin(kind: string, query: string, ids: number[], limit: number): AgentSearchPage {
    this.sequence += 1;
    const snapshot: AgentSearchSnapshot = { id: `search-${Date.now()}-${this.sequence}`,
      kind: kind, query: query, ids: ids.slice().sort((left: number, right: number): number => left - right) };
    this.snapshots.push(snapshot);
    return this.page(snapshot, 0, limit);
  }

  next(kind: string, cursor: string, limit: number): AgentSearchPage {
    const split: number = cursor.lastIndexOf(':');
    const id: string = cursor.slice(0, split);
    const offset: number = Number(cursor.slice(split + 1));
    const snapshot: AgentSearchSnapshot | undefined = this.snapshots.find(
      (item: AgentSearchSnapshot): boolean => item.id === id && item.kind === kind);
    if (split < 0 || snapshot === undefined || !Number.isSafeInteger(offset) || offset < 0 ||
      offset > snapshot.ids.length) { throw new Error('search_cursor_expired'); }
    return this.page(snapshot, offset, limit);
  }

  private page(snapshot: AgentSearchSnapshot, offset: number, limit: number): AgentSearchPage {
    const ids: number[] = snapshot.ids.slice(offset, offset + Math.min(200, Math.max(1, limit || 50)));
    const end: number = offset + ids.length;
    return { ids: ids, query: snapshot.query, totalMatched: snapshot.ids.length,
      nextCursor: end < snapshot.ids.length ? `${snapshot.id}:${end}` : '', returnedCount: ids.length, offset: offset };
  }

  beforeRead(ids: number[]): void {
    const pending: Set<number> = new Set<number>();
    for (const id of ids) {
      if (!this.readNoteIds.has(id) && !this.approvedNoteIds.has(id)) { pending.add(id); }
    }
    let ordinaryReadCount: number = 0;
    for (const id of this.readNoteIds) { if (!this.approvedNoteIds.has(id)) { ordinaryReadCount += 1; } }
    if (pending.size > 0 && ordinaryReadCount + pending.size > 200) {
      const latest: AgentSearchSnapshot | undefined = this.snapshots[this.snapshots.length - 1];
      throw new AgentApprovalRequired(createAgentAction('analysis', JSON.stringify({
        query: latest === undefined ? '' : latest.query,
        totalMatched: latest === undefined ? this.readNoteIds.size + pending.size : latest.ids.length,
        alreadyRead: this.readNoteIds.size, requestedNoteIds: Array.from(pending)
      })));
    }
  }

  recordRead(id: number): void { this.readNoteIds.add(id); }
  approveAnalysis(noteIds: number[]): void {
    for (const id of noteIds) { this.approvedNoteIds.add(id); }
  }
  readCount(): number { return this.readNoteIds.size; }
  exportState(): AgentRetrievalState {
    return { snapshots: this.snapshots.slice(), readNoteIds: Array.from(this.readNoteIds), approvedNoteIds: Array.from(this.approvedNoteIds) };
  }
  restore(state: AgentRetrievalState): void {
    this.snapshots = state.snapshots.slice();
    this.readNoteIds.clear();
    for (const id of state.readNoteIds) { this.readNoteIds.add(id); }
    // 分析许可只覆盖用户曾确认的稳定 ID，不随新匹配对象自动扩大。
    this.approvedNoteIds.clear();
    for (const id of state.approvedNoteIds) { this.approvedNoteIds.add(id); }
  }

  clear(): void { this.snapshots = []; this.readNoteIds.clear(); this.approvedNoteIds.clear(); }
}
