// SPDX-License-Identifier: AGPL-3.0-or-later

export interface AgentMemory {
  id: string;
  text: string;
  scope: string;
  revision: number;
  updatedAt: number;
}
export interface AgentDeckPreference { deckId: number; notetypeId: number; }
export interface AgentWorkspaceState {
  lastDeckId: number;
  deckPreferences: AgentDeckPreference[];
  memories: AgentMemory[];
}
export interface AgentMemoryChange {
  operation: string;
  memoryId: string;
  text: string;
  scope: string;
  before: AgentMemory | null;
}

/** 修改时比较用户确认的旧版本，不能覆盖确认期间发生的其他更新。 */
export function applyAgentMemoryChange(memories: AgentMemory[], change: AgentMemoryChange,
  id: string, now: number): AgentMemory[] {
  if (change.operation === 'create' && (change.memoryId.length > 0 || change.before !== null ||
    memories.some((item: AgentMemory): boolean => item.id === id))) { throw new Error('memory_conflict'); }
  const current: AgentMemory | undefined = memories.find((item: AgentMemory): boolean => item.id === change.memoryId);
  if (change.operation !== 'create' && (current === undefined || change.before === null ||
    JSON.stringify(current) !== JSON.stringify(change.before))) { throw new Error('memory_conflict'); }
  const result: AgentMemory[] = memories.filter((item: AgentMemory): boolean => item.id !== change.memoryId);
  if (change.operation === 'delete') { return result; }
  if (change.operation !== 'create' && change.operation !== 'update') { throw new Error('invalid_memory_change'); }
  if (change.text.trim().length === 0 || change.text.length > 2000) { throw new Error('invalid_memory_change'); }
  result.push({ id: change.operation === 'create' ? id : change.memoryId, text: change.text,
    scope: change.scope, revision: current === undefined ? 1 : current.revision + 1, updatedAt: now });
  return result;
}

export function relevantAgentMemories(memories: AgentMemory[], deckId: number): AgentMemory[] {
  return memories.filter((item: AgentMemory): boolean => item.scope === 'global' || item.scope === `deck:${deckId}`);
}
