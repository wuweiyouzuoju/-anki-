// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderInputItem } from './ProviderProtocol';
import type { AgentAction } from './AgentAction';
import type { AgentRetrievalState } from './AgentRetrieval';
import { sanitizeAgentToolJson } from './AgentToolDiagnostics';

export interface AgentSessionState {
  input: ProviderInputItem[];
  readableIds: number[][];
  retrieval: AgentRetrievalState;
  action: AgentAction | null;
  waitingCallId: string;
  paused: boolean;
  expectedDraftCount?: number;
  requireYearCloze?: boolean;
}

/** 检查点保留协议配对和读取进度，不持久化密钥、模型推理或导入文件原文。 */
export function safeAgentSessionState(state: AgentSessionState): AgentSessionState {
  const input: ProviderInputItem[] = [];
  for (const item of state.input) {
    if (item.kind === 'reasoning' || item.kind === 'output_item') { continue; }
    let content: string = item.content;
    const imported: number = content.indexOf('以下是用户主动导入的本地文件内容');
    if (imported >= 0) { content = content.slice(0, imported) + '[Imported content omitted; ask user to reattach if needed.]'; }
    input.push({ kind: item.kind, role: item.role, content: sanitizeAgentToolJson(content, 240000).text,
      callId: item.callId, name: item.name, argumentsJson: sanitizeAgentToolJson(item.argumentsJson, Number.MAX_SAFE_INTEGER).text,
      output: sanitizeAgentToolJson(item.output, Number.MAX_SAFE_INTEGER).text });
  }
  return { input: input, readableIds: state.readableIds, retrieval: state.retrieval,
    action: state.action === null ? null : safeAgentAction(state.action),
    waitingCallId: state.waitingCallId, paused: state.paused, expectedDraftCount: state.expectedDraftCount ?? 0,
    requireYearCloze: state.requireYearCloze === true };
}

export function safeAgentAction(action: AgentAction): AgentAction {
  const json: string = JSON.stringify(action);
  return JSON.parse(sanitizeAgentToolJson(json, Number.MAX_SAFE_INTEGER).text) as AgentAction;
}

/** 只在完整用户回合边界裁剪；工具调用及结果始终一起保留。 */
export function boundAgentSessionInput(input: ProviderInputItem[], limit: number = 180000): ProviderInputItem[] {
  let size: number = 0;
  let start: number = input.length;
  for (let index: number = input.length - 1; index >= 0; index--) {
    const item: ProviderInputItem = input[index];
    size += item.content.length + item.argumentsJson.length + item.output.length;
    if (item.kind === 'message' && item.role === 'user') {
      if (size > limit && start < input.length) { break; }
      start = index;
    }
  }
  if (start === 0 || start === input.length) { return input.slice(); }
  const result: ProviderInputItem[] = input.slice(start);
  result.unshift({ kind: 'message', role: 'user',
    content: 'Earlier conversation was omitted for context size. Search snapshots remain available. Do not assume omitted card contents or completed writes; read current state when needed.',
    callId: '', name: '', argumentsJson: '', output: '' });
  return result;
}

interface RetrievalOutputSummary {
  query?: string; nextCursor?: string; nextOffset?: number;
  totalMatched?: number; totalRequested?: number; readCount?: number;
  noteIds?: number[]; cardIds?: number[];
}

/** 已读的长正文可退出模型窗口，但保留游标和真实覆盖数，绝不截出无效 JSON。 */
export function compactAgentToolOutputs(input: ProviderInputItem[], limit: number = 160000): void {
  let total: number = 0;
  for (let index: number = input.length - 1; index >= 0; index--) {
    const item: ProviderInputItem = input[index];
    const size: number = item.content.length + item.argumentsJson.length + item.output.length;
    if (total + size > limit && item.kind === 'function_call_output' && item.output.length > 4000) {
      let summary: RetrievalOutputSummary = {};
      try {
        const parsed: RetrievalOutputSummary | null = JSON.parse(item.output) as RetrievalOutputSummary | null;
        if (parsed !== null) { summary = parsed; }
      } catch (error) {}
      item.output = JSON.stringify({ status: 'earlier_tool_content_omitted', query: summary.query,
        nextCursor: summary.nextCursor, nextOffset: summary.nextOffset, totalMatched: summary.totalMatched,
        totalRequested: summary.totalRequested, readCount: summary.readCount,
        noteIds: summary.noteIds, cardIds: summary.cardIds,
        instruction: 'The original content left the context window. Resume from its cursor; reread specific fields when needed. Do not claim omitted text is still visible.' });
    }
    total += item.content.length + item.argumentsJson.length + item.output.length;
  }
}

/** 补齐取消时尚未返回的工具结果；恢复请求不能包含悬空 function_call。 */
export function closeUnansweredCalls(input: ProviderInputItem[]): void {
  const answered: Set<string> = new Set<string>();
  for (const item of input) { if (item.kind === 'function_call_output') { answered.add(item.callId); } }
  const calls: ProviderInputItem[] = input.filter((item: ProviderInputItem): boolean =>
    item.kind === 'function_call' && !answered.has(item.callId));
  for (const call of calls) {
    input.push({ kind: 'function_call_output', role: '', content: '', callId: call.callId,
      name: '', argumentsJson: '', output: '{"status":"interrupted_before_result","instruction":"Read current state before retrying."}' });
  }
}
