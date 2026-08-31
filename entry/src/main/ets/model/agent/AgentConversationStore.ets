// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { AgentMode, AgentToolTrace, AgentToolTraceStatus, SearchSource } from './AgentTypes';
import { sanitizeAgentToolJson } from './AgentToolDiagnostics';

const STORE_NAME: string = 'jidecards_ai_agent_history';
const HISTORY_KEY: string = 'conversations_v1';
const MAX_CONVERSATIONS: number = 50;
const MAX_MESSAGES: number = 200;
const MAX_TEXT_LENGTH: number = 20000;
const MAX_AUDIT_TEXT_TOTAL: number = 200000;

export interface AgentHistoryMessage {
  role: string;
  text: string;
}

export interface AgentHistoryAudit extends AgentToolTrace {}

export interface AgentHistoryResult {
  draftId: string;
  status: string;
  succeeded: number;
  failed: number;
}

export interface AgentConversation {
  id: string;
  mode: AgentMode;
  title: string;
  updatedAt: number;
  messages: AgentHistoryMessage[];
  audits: AgentHistoryAudit[];
  sources: SearchSource[];
  results: AgentHistoryResult[];
}

function getContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>('abilityContext');
  return context === undefined ? null : context;
}

async function openStore(): Promise<preferences.Preferences | null> {
  const context: common.UIAbilityContext | null = getContext();
  if (context === null) { return null; }
  try { return await preferences.getPreferences(context, STORE_NAME); } catch (error) { return null; }
}

/** 历史只保存可见文本；内联媒体、常见密钥形态和授权头会被替换。 */
export function sanitizeHistoryText(value: string): string {
  return value
    .replace(/data:[^\s]+/g, '[media omitted]')
    .replace(/Bearer\s+[^\s]+/gi, 'Bearer [secret omitted]')
    .replace(/sk-[A-Za-z0-9_-]{8,}/g, '[secret omitted]')
    .slice(0, MAX_TEXT_LENGTH);
}

function safeAuditStatus(value: string): AgentToolTraceStatus {
  if (value === 'completed' || value === 'failed') { return value; }
  return 'started';
}

function safeAuditKeys(values: string[] | undefined): string[] {
  if (!Array.isArray(values)) { return []; }
  const output: string[] = [];
  for (const value of values.slice(0, 100)) {
    if (typeof value === 'string') { output.push(sanitizeHistoryText(value)); }
  }
  return output;
}

function safeAudit(audit: AgentHistoryAudit): AgentHistoryAudit {
  const legacy: boolean = typeof audit.callId !== 'string';
  const oldStatus: string = typeof audit.status === 'string' ? audit.status : '';
  const oldToolName: string = typeof audit.toolName === 'string' ? audit.toolName : '';
  const argumentsSafe = sanitizeAgentToolJson(
    typeof audit.argumentsJson === 'string' ? audit.argumentsJson : '', 8192);
  const outputSafe = sanitizeAgentToolJson(
    typeof audit.outputJson === 'string' ? audit.outputJson : '', 8192);
  const templateSafe = sanitizeAgentToolJson(
    typeof audit.validTemplateJson === 'string' ? audit.validTemplateJson : '', 4096);
  return {
    callId: legacy ? `legacy-${oldToolName}` : sanitizeHistoryText(audit.callId),
    toolName: sanitizeHistoryText(oldToolName),
    status: legacy ? 'completed' : safeAuditStatus(oldStatus),
    providerRound: legacy ? 0 : Math.max(0, Math.floor(audit.providerRound)),
    sequence: legacy ? 0 : Math.max(0, Math.floor(audit.sequence)),
    argumentsJson: argumentsSafe.text,
    outputJson: outputSafe.text,
    errorCode: sanitizeHistoryText(typeof audit.errorCode === 'string' ? audit.errorCode : ''),
    errorPath: sanitizeHistoryText(typeof audit.errorPath === 'string' ? audit.errorPath : ''),
    errorMessage: sanitizeHistoryText(typeof audit.errorMessage === 'string' ? audit.errorMessage : ''),
    receivedKeys: safeAuditKeys(audit.receivedKeys),
    allowedKeys: safeAuditKeys(audit.allowedKeys),
    validTemplateJson: templateSafe.text,
    repeatCount: legacy ? 0 : Math.max(0, Math.floor(audit.repeatCount)),
    argumentsTruncated: argumentsSafe.truncated || audit.argumentsTruncated === true,
    outputTruncated: outputSafe.truncated || audit.outputTruncated === true,
    diagnosticTruncated: templateSafe.truncated || audit.diagnosticTruncated === true,
    expanded: false,
    legacySummary: legacy ? sanitizeHistoryText(`${oldStatus}: ${oldToolName}`) :
      sanitizeHistoryText(typeof audit.legacySummary === 'string' ? audit.legacySummary : '')
  };
}

function safeConversation(value: AgentConversation): AgentConversation {
  const messages: AgentHistoryMessage[] = [];
  for (const message of value.messages.slice(-MAX_MESSAGES)) {
    if (message.role === 'user' || message.role === 'assistant') {
      messages.push({ role: message.role, text: sanitizeHistoryText(message.text) });
    }
  }
  const audits: AgentHistoryAudit[] = [];
  let auditTextTotal: number = 0;
  for (const audit of value.audits.slice(-MAX_MESSAGES)) {
    const safe: AgentHistoryAudit = safeAudit(audit);
    const size: number = safe.argumentsJson.length + safe.outputJson.length + safe.errorMessage.length +
      safe.validTemplateJson.length + safe.legacySummary.length;
    if (auditTextTotal + size <= MAX_AUDIT_TEXT_TOTAL) {
      audits.push(safe);
      auditTextTotal += size;
    }
  }
  const sources: SearchSource[] = [];
  for (const source of value.sources.slice(-MAX_MESSAGES)) {
    if (source.url.startsWith('https://')) {
      sources.push({ url: source.url.slice(0, 4096), title: sanitizeHistoryText(source.title) });
    }
  }
  const results: AgentHistoryResult[] = [];
  for (const result of value.results.slice(-MAX_MESSAGES)) {
    results.push({
      draftId: sanitizeHistoryText(result.draftId), status: sanitizeHistoryText(result.status),
      succeeded: Math.max(0, Math.floor(result.succeeded)), failed: Math.max(0, Math.floor(result.failed))
    });
  }
  return {
    id: sanitizeHistoryText(value.id), mode: value.mode,
    title: sanitizeHistoryText(value.title), updatedAt: value.updatedAt,
    messages: messages, audits: audits, sources: sources, results: results
  };
}

export async function loadAgentConversations(): Promise<AgentConversation[]> {
  const store: preferences.Preferences | null = await openStore();
  if (store === null) { return []; }
  try {
    const raw: preferences.ValueType = await store.get(HISTORY_KEY, '[]');
    if (typeof raw !== 'string') { return []; }
    const parsed: AgentConversation[] = JSON.parse(raw) as AgentConversation[];
    if (!Array.isArray(parsed)) { return []; }
    const output: AgentConversation[] = [];
    for (const value of parsed.slice(0, MAX_CONVERSATIONS)) {
      if (value !== null && typeof value === 'object' && typeof value.id === 'string' &&
        Array.isArray(value.messages) && Array.isArray(value.audits) &&
        Array.isArray(value.sources) && Array.isArray(value.results)) {
        output.push(safeConversation(value));
      }
    }
    return output;
  } catch (error) { return []; }
}

export async function saveAgentConversation(value: AgentConversation): Promise<void> {
  const store: preferences.Preferences | null = await openStore();
  if (store === null) { return; }
  const current: AgentConversation[] = await loadAgentConversations();
  const next: AgentConversation[] = [safeConversation(value)];
  for (const item of current) {
    if (item.id !== value.id && next.length < MAX_CONVERSATIONS) { next.push(item); }
  }
  await store.put(HISTORY_KEY, JSON.stringify(next));
  await store.flush();
}

export async function deleteAgentConversation(id: string): Promise<void> {
  const store: preferences.Preferences | null = await openStore();
  if (store === null) { return; }
  const current: AgentConversation[] = await loadAgentConversations();
  const next: AgentConversation[] = current.filter((item: AgentConversation): boolean => item.id !== id);
  await store.put(HISTORY_KEY, JSON.stringify(next));
  await store.flush();
}
