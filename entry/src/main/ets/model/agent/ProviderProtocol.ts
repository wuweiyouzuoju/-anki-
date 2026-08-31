// SPDX-License-Identifier: AGPL-3.0-or-later

import type { SearchMode } from './AgentTypes';

/** Provider 请求的纯数据契约；密钥只由 HTTP 传输层写入 Authorization 头。 */

export type ProviderInputKind =
  'message' | 'function_call' | 'function_call_output' | 'reasoning' | 'output_item';

export interface ProviderInputItem {
  kind: ProviderInputKind;
  role: string;
  content: string;
  callId: string;
  name: string;
  argumentsJson: string;
  output: string;
}

export interface ProviderFunctionTool {
  name: string;
  description: string;
  parametersJson: string;
  exampleArgumentsJson: string;
  rules: string;
}

export interface ProviderTurnRequest {
  apiKey: string;
  baseUrl: string;
  model: string;
  instructions: string;
  input: ProviderInputItem[];
  functionTools: ProviderFunctionTool[];
  searchMode: SearchMode;
  /** 用户是否明确要求联网；为 true 时必须观察到真实 HTTPS 来源。 */
  requiresSearchEvidence: boolean;
  /** 制卡模式必须产生真实 ChangeDraft，不接受模型在正文中声称已完成。 */
  requiresDraft: boolean;
  /** 0=未显式指定；正数=最终创建草稿必须恰好等于该数量。 */
  expectedDraftCount: number;
  reasoningEffort: string;
  maxOutputTokens: number;
}

interface ResponsesMessageInput {
  role: string;
  content: string;
}

interface ResponsesFunctionCallInput {
  type: string;
  call_id: string;
  name: string;
  arguments: string;
}

interface ResponsesFunctionOutputInput {
  type: string;
  call_id: string;
  output: string;
}

interface ResponsesReasoningInput {
  type: string;
  content: ResponsesReasoningContent[];
}

interface ResponsesReasoningContent {
  type: string;
  text: string;
}

interface ResponsesOpaqueOutputInput {
  type: string;
  content?: object[];
}

type ResponsesInput = ResponsesMessageInput | ResponsesFunctionCallInput |
  ResponsesFunctionOutputInput | ResponsesReasoningInput | ResponsesOpaqueOutputInput;

interface ResponsesFunctionTool {
  type: string;
  name: string;
  description: string;
  parameters: object;
}

interface ResponsesWebSearchTool {
  type: string;
}

type ResponsesTool = ResponsesFunctionTool | ResponsesWebSearchTool;

interface ResponsesNamedToolChoice {
  type: string;
}

interface ResponsesReasoning {
  effort: string;
  summary: string;
}

interface ResponsesRequestBody {
  model: string;
  instructions: string;
  input: ResponsesInput[];
  tools: ResponsesTool[];
  tool_choice: string | ResponsesNamedToolChoice;
  reasoning: ResponsesReasoning;
  max_output_tokens: number;
  stream: boolean;
  store: boolean;
  include: string[];
}

export class ProviderProtocolError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

export function buildResponsesUrl(baseUrl: string): string {
  const normalized: string = baseUrl.trim().replace(/\/+$/, '');
  if (normalized.endsWith('/responses')) {
    return normalized;
  }
  return `${normalized}/responses`;
}

function buildInput(item: ProviderInputItem): ResponsesInput {
  if (item.kind === 'message') {
    return { role: item.role, content: item.content };
  }
  if (item.kind === 'function_call') {
    return {
      type: 'function_call',
      call_id: item.callId,
      name: item.name,
      arguments: item.argumentsJson
    };
  }
  if (item.kind === 'function_call_output') {
    return { type: 'function_call_output', call_id: item.callId, output: item.output };
  }
  if (item.kind === 'reasoning') {
    return {
      type: 'reasoning',
      content: [{ type: 'reasoning_text', text: item.content }]
    };
  }
  if (item.kind === 'output_item') {
    let value: ResponsesOpaqueOutputInput;
    try { value = JSON.parse(item.content) as ResponsesOpaqueOutputInput; } catch (error) {
      throw new ProviderProtocolError('invalid_provider_input');
    }
    if (value === null || typeof value !== 'object' || Array.isArray(value) ||
      (value.type !== 'web_search_call' && value.type !== 'reasoning') ||
      (value.type === 'reasoning' && !Array.isArray(value.content))) {
      throw new ProviderProtocolError('invalid_provider_input');
    }
    return value;
  }
  throw new ProviderProtocolError('invalid_provider_input');
}

function parseToolParameters(parametersJson: string): object {
  let parameters: object;
  try {
    parameters = JSON.parse(parametersJson) as object;
  } catch (error) {
    throw new ProviderProtocolError('invalid_tool_schema');
  }
  if (parameters === null || typeof parameters !== 'object' || Array.isArray(parameters)) {
    throw new ProviderProtocolError('invalid_tool_schema');
  }
  return parameters;
}

export function buildResponsesPayload(request: ProviderTurnRequest): string {
  const input: ResponsesInput[] = [];
  for (const item of request.input) {
    input.push(buildInput(item));
  }
  const tools: ResponsesTool[] = [];
  for (const tool of request.functionTools) {
    if (tool.name.length === 0) {
      throw new ProviderProtocolError('invalid_tool_schema');
    }
    tools.push({
      type: 'function',
      name: tool.name,
      description: `${tool.description}\n\nStandard arguments template:\n${tool.exampleArgumentsJson}` +
        `\n\nRules:\n${tool.rules}`,
      parameters: parseToolParameters(tool.parametersJson)
    });
  }
  if (request.searchMode !== 'off') {
    tools.push({ type: 'web_search' });
  }
  let toolChoice: string | ResponsesNamedToolChoice = 'auto';
  if (request.searchMode === 'always') {
    toolChoice = { type: 'web_search' };
  }
  const body: ResponsesRequestBody = {
    model: request.model,
    instructions: request.instructions,
    input: input,
    tools: tools,
    tool_choice: toolChoice,
    reasoning: {
      effort: request.reasoningEffort.length === 0 ? 'medium' : request.reasoningEffort,
      summary: 'auto'
    },
    max_output_tokens: Math.max(1, Math.floor(request.maxOutputTokens)),
    stream: true,
    store: false,
    include: ['web_search_call.action.sources']
  };
  return JSON.stringify(body);
}
