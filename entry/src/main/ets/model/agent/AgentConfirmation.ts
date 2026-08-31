// SPDX-License-Identifier: AGPL-3.0-or-later

export interface AgentConfirmationToken {
  id: string;
  draftId: string;
  level: number;
  expiresAt: number;
}

interface ConfirmationRecord {
  token: AgentConfirmationToken;
  used: boolean;
}

export class AgentConfirmationError extends Error {
  readonly code: string;
  constructor(code: string) { super(code); this.code = code; }
}

/** 仅存在于当前应用进程的短时一次性确认令牌。 */
export class AgentConfirmationManager {
  private readonly ttlMs: number;
  private readonly records: Map<string, ConfirmationRecord> = new Map<string, ConfirmationRecord>();
  private sequence: number = 0;

  constructor(ttlMs: number = 120000) { this.ttlMs = Math.max(100, ttlMs); }

  issue(draftId: string, level: number, now: number = Date.now()): AgentConfirmationToken {
    if (draftId.length === 0 || (level !== 1 && level !== 2)) {
      throw new AgentConfirmationError('invalid_confirmation_request');
    }
    this.sequence += 1;
    const token: AgentConfirmationToken = {
      id: `${now}-${this.sequence}-${level}`,
      draftId: draftId,
      level: level,
      expiresAt: now + this.ttlMs
    };
    this.records.set(token.id, { token: token, used: false });
    return token;
  }

  consume(token: AgentConfirmationToken, draftId: string, level: number,
    now: number = Date.now()): void {
    const record: ConfirmationRecord = this.validate(token, draftId, level, now);
    record.used = true;
  }

  /** 校验令牌但不消耗，供高风险操作从第一确认过渡到第二确认。 */
  check(token: AgentConfirmationToken, draftId: string, level: number,
    now: number = Date.now()): void {
    this.validate(token, draftId, level, now);
  }

  consumePair(first: AgentConfirmationToken, second: AgentConfirmationToken,
    draftId: string, now: number = Date.now()): void {
    if (first.id === second.id) {
      throw new AgentConfirmationError('confirmation_tokens_not_distinct');
    }
    const firstRecord: ConfirmationRecord = this.validate(first, draftId, 1, now);
    const secondRecord: ConfirmationRecord = this.validate(second, draftId, 2, now);
    firstRecord.used = true;
    secondRecord.used = true;
  }

  clear(): void { this.records.clear(); }

  private validate(token: AgentConfirmationToken, draftId: string, level: number,
    now: number): ConfirmationRecord {
    const record: ConfirmationRecord | undefined = this.records.get(token.id);
    if (record === undefined || record.token.draftId !== draftId ||
      record.token.level !== level || token.draftId !== draftId || token.level !== level) {
      throw new AgentConfirmationError('confirmation_mismatch');
    }
    if (record.used) {
      throw new AgentConfirmationError('confirmation_already_used');
    }
    if (now > record.token.expiresAt) {
      throw new AgentConfirmationError('confirmation_expired');
    }
    return record;
  }
}
