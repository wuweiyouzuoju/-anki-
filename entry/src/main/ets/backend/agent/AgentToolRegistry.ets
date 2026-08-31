// SPDX-License-Identifier: AGPL-3.0-or-later

import type { AgentToolCall, ChangeDraft, ToolRisk } from '../../model/agent/AgentTypes';
import { toolRiskOf } from '../../model/agent/AgentPolicy';

export interface AgentReadToolHandler {
  execute(argumentsJson: string): Promise<string>;
}

export interface AgentDraftToolHandler {
  propose(argumentsJson: string): Promise<ChangeDraft>;
}

export interface AgentToolResult {
  outputJson: string;
  draft: ChangeDraft | null;
}

export class AgentToolRegistryError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

/** 只注册语义级读工具和“生成草稿”工具；本类没有提交写入的方法。 */
export class AgentToolRegistry {
  private readonly readHandlers: Map<string, AgentReadToolHandler> =
    new Map<string, AgentReadToolHandler>();
  private readonly draftHandlers: Map<string, AgentDraftToolHandler> =
    new Map<string, AgentDraftToolHandler>();
  private readonly highRiskDraftHandlers: Map<string, AgentDraftToolHandler> =
    new Map<string, AgentDraftToolHandler>();

  registerRead(name: string, handler: AgentReadToolHandler): void {
    if (toolRiskOf(name) !== 'read') {
      throw new AgentToolRegistryError('tool_registration_rejected');
    }
    this.readHandlers.set(name, handler);
  }

  registerDraft(name: string, handler: AgentDraftToolHandler): void {
    if (toolRiskOf(name) !== 'write') {
      throw new AgentToolRegistryError('tool_registration_rejected');
    }
    this.draftHandlers.set(name, handler);
  }

  registerHighRiskDraft(name: string, handler: AgentDraftToolHandler): void {
    if (toolRiskOf(name) !== 'high_risk' || !name.startsWith('propose_')) {
      throw new AgentToolRegistryError('tool_registration_rejected');
    }
    this.highRiskDraftHandlers.set(name, handler);
  }

  async execute(call: AgentToolCall): Promise<AgentToolResult> {
    const risk: ToolRisk = toolRiskOf(call.name);
    if (risk === 'read') {
      const handler: AgentReadToolHandler | undefined = this.readHandlers.get(call.name);
      if (handler === undefined) {
        throw new AgentToolRegistryError('tool_unavailable');
      }
      const output: string = await handler.execute(call.argumentsJson);
      return { outputJson: output, draft: null };
    }
    if (risk === 'write') {
      const handler: AgentDraftToolHandler | undefined = this.draftHandlers.get(call.name);
      if (handler === undefined) {
        throw new AgentToolRegistryError('tool_unavailable');
      }
      const draft: ChangeDraft = await handler.propose(call.argumentsJson);
      return { outputJson: JSON.stringify(draft), draft: draft };
    }
    if (risk === 'high_risk' && call.name.startsWith('propose_')) {
      const handler: AgentDraftToolHandler | undefined = this.highRiskDraftHandlers.get(call.name);
      if (handler === undefined) {
        throw new AgentToolRegistryError('tool_unavailable');
      }
      const draft: ChangeDraft = await handler.propose(call.argumentsJson);
      if (draft.risk !== 'high_risk') {
        throw new AgentToolRegistryError('tool_result_risk_mismatch');
      }
      return { outputJson: JSON.stringify(draft), draft: draft };
    }
    throw new AgentToolRegistryError('tool_blocked');
  }
}
