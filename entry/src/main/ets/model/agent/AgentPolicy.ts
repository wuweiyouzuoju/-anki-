// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ToolRisk } from './AgentTypes';

export const DEFAULT_BATCH_LIMIT: number = 100;
export const MAX_BATCH_LIMIT: number = 1000;

export interface AgentSearchSourceEvent {
  kind: 'search_source';
  url: string;
  title: string;
}

export interface AgentTextDeltaEvent {
  kind: 'text_delta';
  text: string;
}

export type SearchEvidenceEvent = AgentSearchSourceEvent | AgentTextDeltaEvent;

export class SearchEvidenceError extends Error {
  readonly code: string = 'web_search_unsupported';

  constructor() {
    super('web_search_unsupported');
  }
}

export function toolRiskOf(toolName: string): ToolRisk {
  switch (toolName) {
    case 'get_note_type_capabilities':
    case 'get_note_context':
    case 'search_cards':
    case 'list_decks':
    case 'web_search':
      return 'read';
    case 'propose_create_notes':
    case 'propose_update_notes':
    case 'propose_move_cards':
      return 'write';
    case 'remove_notes':
    case 'remove_cards':
    case 'remove_deck':
    case 'remove_note_type':
    case 'change_note_type':
    case 'update_note_type_templates':
    case 'propose_delete_notes':
    case 'propose_delete_cards':
    case 'propose_delete_deck':
    case 'propose_delete_note_type':
    case 'propose_change_note_type':
    case 'propose_update_note_type_templates':
      return 'high_risk';
    default:
      return 'blocked';
  }
}

export function normalizeBatchLimit(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return DEFAULT_BATCH_LIMIT;
  }
  return Math.min(MAX_BATCH_LIMIT, Math.max(1, Math.floor(value)));
}

export function splitAffectedCardIds(cardIds: number[], requestedLimit: number): number[][] {
  const limit: number = normalizeBatchLimit(requestedLimit);
  const batches: number[][] = [];
  for (let offset: number = 0; offset < cardIds.length; offset += limit) {
    batches.push(cardIds.slice(offset, offset + limit));
  }
  return batches;
}

export function registerToolCallId(seenIds: Set<string>, toolCallId: string): boolean {
  if (toolCallId.length === 0 || seenIds.has(toolCallId)) {
    return false;
  }
  seenIds.add(toolCallId);
  return true;
}

export function enforceSearchEvidence(requested: boolean, events: SearchEvidenceEvent[]): void {
  if (!requested) {
    return;
  }
  for (const event of events) {
    if (event.kind === 'search_source' && event.url.startsWith('https://')) {
      return;
    }
  }
  throw new SearchEvidenceError();
}

/** 只识别明确的公网检索意图，避免把“搜索卡库”误判为联网请求。 */
export function explicitWebSearchRequested(text: string): boolean {
  const normalized: string = text.trim().toLocaleLowerCase();
  if (normalized.length === 0) { return false; }
  const markers: string[] = [
    '联网', '网页', '网站', '网上', '网络搜索', '搜索网络', '在线查',
    '最新资料', '最新消息', '有道词典', '百度百科', '维基百科',
    'search the web', 'web search', 'browse the web', 'look up online',
    'online source', 'cite sources', 'website'
  ];
  for (const marker of markers) {
    if (normalized.includes(marker)) { return true; }
  }
  return false;
}
