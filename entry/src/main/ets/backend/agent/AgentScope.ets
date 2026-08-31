// SPDX-License-Identifier: AGPL-3.0-or-later

export class AgentScopeError extends Error {
  readonly code: string;

  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

/** 一轮会话可引用的稳定 ID 集合；模型不能凭空构造卡库对象 ID。 */
export class AgentScope {
  private readonly cardIds: Set<number> = new Set<number>();
  private readonly noteIds: Set<number> = new Set<number>();
  private readonly deckIds: Set<number> = new Set<number>();
  private readonly notetypeIds: Set<number> = new Set<number>();
  private readonly draftIds: Set<string> = new Set<string>();
  private batchLimit: number = 100;
  private createDeckId: number = 0;
  private createNotetypeId: number = 0;
  private requireYearCloze: boolean = false;

  registerCardIds(ids: number[]): void { this.registerIds(this.cardIds, ids); }
  registerNoteIds(ids: number[]): void { this.registerIds(this.noteIds, ids); }
  registerDeckIds(ids: number[]): void { this.registerIds(this.deckIds, ids); }
  registerNotetypeIds(ids: number[]): void { this.registerIds(this.notetypeIds, ids); }

  assertCardIdsInScope(ids: number[]): void { this.assertIds(this.cardIds, ids); }
  assertNoteIdsInScope(ids: number[]): void { this.assertIds(this.noteIds, ids); }
  assertDeckIdsInScope(ids: number[]): void { this.assertIds(this.deckIds, ids); }
  assertNotetypeIdsInScope(ids: number[]): void { this.assertIds(this.notetypeIds, ids); }

  configureBatchLimit(value: number): void {
    if (!Number.isFinite(value) || value <= 0) { this.batchLimit = 100; return; }
    this.batchLimit = Math.min(1000, Math.max(1, Math.floor(value)));
  }

  assertBatchCount(count: number): void {
    if (!Number.isSafeInteger(count) || count < 0 || count > this.batchLimit) {
      throw new AgentScopeError('tool_batch_too_large');
    }
  }

  configureCreateTarget(deckId: number, notetypeId: number): void {
    this.createDeckId = deckId;
    this.createNotetypeId = notetypeId;
  }

  configureCreateConstraints(requireYearCloze: boolean): void {
    this.requireYearCloze = requireYearCloze;
  }

  createRequiresYearCloze(): boolean { return this.requireYearCloze; }

  assertCreateTarget(deckId: number, notetypeId: number): void {
    if (this.createDeckId <= 0 || this.createNotetypeId <= 0 ||
      deckId !== this.createDeckId || notetypeId !== this.createNotetypeId) {
      throw new AgentScopeError('create_target_out_of_scope');
    }
  }

  registerDraftId(id: string): boolean {
    if (id.length === 0 || this.draftIds.has(id)) {
      return false;
    }
    this.draftIds.add(id);
    return true;
  }

  reset(): void {
    this.cardIds.clear();
    this.noteIds.clear();
    this.deckIds.clear();
    this.notetypeIds.clear();
    this.draftIds.clear();
    this.createDeckId = 0;
    this.createNotetypeId = 0;
    this.requireYearCloze = false;
  }

  private registerIds(target: Set<number>, ids: number[]): void {
    for (const id of ids) {
      if (!Number.isSafeInteger(id) || id <= 0) {
        throw new AgentScopeError('invalid_stable_id');
      }
      target.add(id);
    }
  }

  private assertIds(target: Set<number>, ids: number[]): void {
    for (const id of ids) {
      if (!target.has(id)) {
        throw new AgentScopeError('id_out_of_scope');
      }
    }
  }
}
