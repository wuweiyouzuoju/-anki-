// SPDX-License-Identifier: AGPL-3.0-or-later

/** Agent 的纯数据契约；本文件不得导入 HarmonyOS Kit。 */

export type AgentMode = 'create' | 'edit';
export type ProviderId = 'deepseek' | 'openai' | 'custom';
export type SearchMode = 'auto' | 'always' | 'off';
export type ToolRisk = 'read' | 'write' | 'high_risk' | 'blocked';

export interface ProviderCapabilities {
  text: boolean;
  image: boolean;
  audio: boolean;
  streaming: boolean;
  toolCalls: boolean;
  reasoning: boolean;
  webSearch: boolean;
}

export interface SearchSource {
  url: string;
  title: string;
}

export interface AgentToolCall {
  id: string;
  name: string;
  argumentsJson: string;
}

export type AgentToolTraceStatus = 'started' | 'completed' | 'failed';

/** 模型工具参数或执行失败的固定诊断；空值以空串/空数组表示。 */
export interface AgentToolDiagnostic {
  code: string;
  path: string;
  message: string;
  receivedKeys: string[];
  allowedKeys: string[];
  validTemplateJson: string;
}

/** 一次真实工具调用的可见审计；同一 callId 从 started 更新到最终状态。 */
export interface AgentToolTrace {
  callId: string;
  toolName: string;
  status: AgentToolTraceStatus;
  providerRound: number;
  sequence: number;
  argumentsJson: string;
  outputJson: string;
  errorCode: string;
  errorPath: string;
  errorMessage: string;
  receivedKeys: string[];
  allowedKeys: string[];
  validTemplateJson: string;
  repeatCount: number;
  argumentsTruncated: boolean;
  outputTruncated: boolean;
  diagnosticTruncated: boolean;
  expanded: boolean;
  legacySummary: string;
}

export type AgentEventKind =
  'status' | 'text_delta' | 'reasoning_delta' | 'reasoning_summary' |
  'tool_call' | 'tool_started' | 'tool_completed' | 'tool_failed' |
  'search_source' | 'continuation_item' | 'completed' | 'error';

/** 固定对象布局，避免 ArkTS 动态对象。未使用字段保持空串/null。 */
export interface AgentEvent {
  kind: AgentEventKind;
  text: string;
  toolCall: AgentToolCall | null;
  toolTrace: AgentToolTrace | null;
  source: SearchSource | null;
  errorCode: string;
}

export type DraftOperationKind =
  'create_note' | 'update_field' | 'update_tags' | 'move_card' |
  'change_note_type' | 'update_template' | 'delete_note' | 'delete_card' |
  'delete_deck' | 'delete_note_type';

export type ChangeDraftStatus = 'pending' | 'prepared' | 'executing' |
  'partial' | 'completed' | 'conflict' | 'failed';

export interface DraftOperation {
  kind: DraftOperationKind;
  noteId: number;
  cardId: number;
  deckId: number;
  fieldOrd: number;
  before: string;
  after: string;
}

export interface ChangeDraft {
  id: string;
  risk: ToolRisk;
  summary: string;
  baselineHash: string;
  confirmationLevel: number;
  status: ChangeDraftStatus;
  affectedNoteIds: number[];
  affectedCardIds: number[];
  affectedDeckIds: number[];
  affectedNotetypeIds: number[];
  operations: DraftOperation[];
}

export interface AgentTurnLimits {
  maxProviderCalls: number;
  maxToolCalls: number;
}

export const DEFAULT_AGENT_TURN_LIMITS: AgentTurnLimits = {
  maxProviderCalls: 8,
  maxToolCalls: 16
};
