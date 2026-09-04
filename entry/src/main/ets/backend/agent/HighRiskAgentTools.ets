// SPDX-License-Identifier: AGPL-3.0-or-later

import type { Card } from '../../proto/messages/CardsMessages';
import type { DeckTreeNode } from '../../proto/messages/DeckMessages';
import type { EditableNote } from '../../proto/messages/NoteMessages';
import type { NotetypeCapabilities, 变更笔记类型信息 } from '../../proto/messages/NotetypeMessages';
import type { ChangeDraft, DraftOperation } from '../../model/agent/AgentTypes';
import { MAX_BATCH_LIMIT } from '../../model/agent/AgentPolicy';
import { AgentToolArguments, AgentToolSchemaError, decodeAgentToolArguments } from '../../model/agent/AgentToolSchemas';
import { 卡片服务 } from '../卡片服务';
import { 搜索服务 } from '../搜索服务';
import { 牌组服务 } from '../牌组服务';
import { 笔记服务 } from '../笔记服务';
import { 笔记类型服务 } from '../笔记类型服务';
import { AgentScope } from './AgentScope';
import { AgentDraftToolHandler, AgentToolRegistry } from './AgentToolRegistry';

function uniqueIds(values: number[]): number[] {
  const result: number[] = [];
  const seen: Set<number> = new Set<number>();
  for (const value of values) {
    if (!seen.has(value)) { seen.add(value); result.push(value); }
  }
  return result;
}

function assertHardLimit(cardIds: number[]): void {
  if (cardIds.length > MAX_BATCH_LIMIT) {
    throw new AgentToolSchemaError('high_risk_batch_too_large');
  }
}

function highRiskDraft(id: string, summary: string, operations: DraftOperation[],
  noteIds: number[], cardIds: number[], deckIds: number[], notetypeIds: number[]): ChangeDraft {
  return {
    id: id,
    risk: 'high_risk',
    summary: summary,
    baselineHash: JSON.stringify(operations),
    confirmationLevel: 2,
    status: 'pending',
    affectedNoteIds: uniqueIds(noteIds),
    affectedCardIds: uniqueIds(cardIds),
    affectedDeckIds: uniqueIds(deckIds),
    affectedNotetypeIds: uniqueIds(notetypeIds),
    operations: operations
  };
}

function findDeck(node: DeckTreeNode, deckId: number): DeckTreeNode | null {
  if (node.deckId === deckId) { return node; }
  for (const child of node.children) {
    const found: DeckTreeNode | null = findDeck(child, deckId);
    if (found !== null) { return found; }
  }
  return null;
}

function parseMapping(json: string): number[] {
  let values: number[];
  try { values = JSON.parse(json) as number[]; } catch (error) {
    throw new AgentToolSchemaError('invalid_tool_arguments');
  }
  if (!Array.isArray(values) || values.length > 100) {
    throw new AgentToolSchemaError('invalid_tool_arguments');
  }
  for (const value of values) {
    if (!Number.isSafeInteger(value) || value < -1) {
      throw new AgentToolSchemaError('invalid_tool_arguments');
    }
  }
  return values;
}

class HighRiskHandler implements AgentDraftToolHandler {
  private readonly owner: HighRiskAgentTools;
  private readonly name: string;
  constructor(owner: HighRiskAgentTools, name: string) { this.owner = owner; this.name = name; }
  propose(argumentsJson: string): Promise<ChangeDraft> { return this.owner.propose(this.name, argumentsJson); }
}

/** 高风险工具只计算精确影响并生成草稿，不执行删除或结构写入。 */
export class HighRiskAgentTools {
  private readonly scope: AgentScope;
  private readonly notes: 笔记服务 = new 笔记服务();
  private readonly cards: 卡片服务 = new 卡片服务();
  private readonly decks: 牌组服务 = new 牌组服务();
  private readonly notetypes: 笔记类型服务 = new 笔记类型服务();
  private readonly searches: 搜索服务 = new 搜索服务();

  constructor(scope: AgentScope) { this.scope = scope; }

  register(registry: AgentToolRegistry): void {
    registry.registerHighRiskDraft('propose_delete_notes', new HighRiskHandler(this, 'propose_delete_notes'));
    registry.registerHighRiskDraft('propose_delete_cards', new HighRiskHandler(this, 'propose_delete_cards'));
    registry.registerHighRiskDraft('propose_change_note_type', new HighRiskHandler(this, 'propose_change_note_type'));
    registry.registerHighRiskDraft('propose_update_note_type_templates', new HighRiskHandler(this, 'propose_update_note_type_templates'));
    registry.registerHighRiskDraft('propose_delete_deck', new HighRiskHandler(this, 'propose_delete_deck'));
    registry.registerHighRiskDraft('propose_delete_note_type', new HighRiskHandler(this, 'propose_delete_note_type'));
  }

  async propose(name: string, argumentsJson: string): Promise<ChangeDraft> {
    const args: AgentToolArguments = decodeAgentToolArguments(name, argumentsJson);
    if (!this.scope.registerDraftId(args.draftId)) {
      throw new AgentToolSchemaError('duplicate_draft_id');
    }
    if (name === 'propose_delete_notes') { return this.proposeDeleteNotes(args); }
    if (name === 'propose_delete_cards') { return this.proposeDeleteCards(args); }
    if (name === 'propose_change_note_type') { return this.proposeChangeNotetype(args); }
    if (name === 'propose_update_note_type_templates') { return this.proposeTemplates(args); }
    if (name === 'propose_delete_deck') { return this.proposeDeleteDeck(args); }
    return this.proposeDeleteNotetype(args);
  }

  private async proposeDeleteNotes(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableNoteIds(args.noteIds);
    const operations: DraftOperation[] = [];
    const cardIds: number[] = [];
    for (const noteId of args.noteIds) {
      const note: EditableNote = await this.notes.获取笔记(noteId);
      const siblings: number[] = await this.notes.获取笔记的卡片(noteId);
      cardIds.push(...siblings);
      operations.push({
        kind: 'delete_note', noteId: noteId, cardId: 0, deckId: 0, fieldOrd: -1,
        before: JSON.stringify(note), after: ''
      });
    }
    assertHardLimit(uniqueIds(cardIds));
    this.scope.assertBatchCount(uniqueIds(cardIds).length);
    return highRiskDraft(args.draftId, args.reason, operations, args.noteIds, cardIds, [], []);
  }

  private async proposeDeleteCards(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableCardIds(args.cardIds);
    assertHardLimit(args.cardIds);
    this.scope.assertBatchCount(args.cardIds.length);
    const operations: DraftOperation[] = [];
    const noteIds: number[] = [];
    for (const cardId of args.cardIds) {
      const card: Card = await this.cards.获取卡片(cardId);
      noteIds.push(card.noteId);
      operations.push({
        kind: 'delete_card', noteId: card.noteId, cardId: card.id, deckId: card.deckId,
        fieldOrd: -1, before: JSON.stringify(card), after: ''
      });
    }
    return highRiskDraft(args.draftId, args.reason, operations, noteIds, args.cardIds, [], []);
  }

  private async proposeChangeNotetype(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableNoteIds(args.noteIds);
    this.scope.assertReadableNotetypeIds([args.targetNotetypeId]);
    const oldId: number = await this.notes.获取笔记的唯一笔记类型(args.noteIds);
    const info: 变更笔记类型信息 = await this.notetypes.获取变更笔记类型信息(oldId, args.targetNotetypeId);
    const fields: number[] = parseMapping(args.fieldMappingJson);
    const templates: number[] = parseMapping(args.templateMappingJson);
    const cardIds: number[] = [];
    for (const noteId of args.noteIds) { cardIds.push(...await this.notes.获取笔记的卡片(noteId)); }
    assertHardLimit(uniqueIds(cardIds));
    this.scope.assertBatchCount(uniqueIds(cardIds).length);
    const operation: DraftOperation = {
      kind: 'change_note_type', noteId: 0, cardId: 0, deckId: 0, fieldOrd: -1,
      before: JSON.stringify(info.input),
      after: JSON.stringify({ noteIds: args.noteIds, newFields: fields, newTemplates: templates })
    };
    return highRiskDraft(args.draftId, args.reason, [operation], args.noteIds, cardIds, [], [oldId, args.targetNotetypeId]);
  }

  private async proposeTemplates(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableNotetypeIds(args.notetypeIds);
    if (args.notetypeIds.length !== 1) { throw new AgentToolSchemaError('invalid_tool_arguments'); }
    const id: number = args.notetypeIds[0];
    const before: string = await this.notetypes.获取笔记类型旧版(id);
    const query: string = await this.searches.构建搜索串({ kind: 'note', note: (await this.notetypes.获取笔记类型能力(id)).name });
    const noteIds: number[] = await this.searches.搜索笔记({ search: query, order: { kind: 'none' } });
    const cardIds: number[] = [];
    for (const noteId of noteIds) { cardIds.push(...await this.notes.获取笔记的卡片(noteId)); }
    assertHardLimit(uniqueIds(cardIds));
    this.scope.assertBatchCount(uniqueIds(cardIds).length);
    const operation: DraftOperation = {
      kind: 'update_template', noteId: 0, cardId: 0, deckId: 0, fieldOrd: -1,
      before: before, after: JSON.stringify({ templates: args.templateJson, css: args.css })
    };
    return highRiskDraft(args.draftId, args.reason, [operation], noteIds, cardIds, [], [id]);
  }

  private async proposeDeleteDeck(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableDeckIds(args.deckIds);
    if (args.deckIds.length !== 1) { throw new AgentToolSchemaError('invalid_tool_arguments'); }
    const tree: DeckTreeNode = await this.decks.获取牌组树();
    const deck: DeckTreeNode | null = findDeck(tree, args.deckIds[0]);
    if (deck === null) { throw new AgentToolSchemaError('id_out_of_scope'); }
    const query: string = await this.searches.构建搜索串({ kind: 'deck', deck: deck.name });
    const cardIds: number[] = await this.searches.搜索卡片({ search: query, order: { kind: 'none' } });
    assertHardLimit(uniqueIds(cardIds));
    this.scope.assertBatchCount(uniqueIds(cardIds).length);
    const noteIds: number[] = [];
    for (const cardId of cardIds) { noteIds.push((await this.cards.获取卡片(cardId)).noteId); }
    const operation: DraftOperation = {
      kind: 'delete_deck', noteId: 0, cardId: 0, deckId: deck.deckId, fieldOrd: -1,
      before: JSON.stringify(deck), after: ''
    };
    return highRiskDraft(args.draftId, args.reason, [operation], noteIds, cardIds, [deck.deckId], []);
  }

  private async proposeDeleteNotetype(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertReadableNotetypeIds(args.notetypeIds);
    if (args.notetypeIds.length !== 1) { throw new AgentToolSchemaError('invalid_tool_arguments'); }
    const id: number = args.notetypeIds[0];
    const capability: NotetypeCapabilities = await this.notetypes.获取笔记类型能力(id);
    const query: string = await this.searches.构建搜索串({ kind: 'note', note: capability.name });
    const noteIds: number[] = await this.searches.搜索笔记({ search: query, order: { kind: 'none' } });
    const cardIds: number[] = [];
    for (const noteId of noteIds) { cardIds.push(...await this.notes.获取笔记的卡片(noteId)); }
    assertHardLimit(uniqueIds(cardIds));
    this.scope.assertBatchCount(uniqueIds(cardIds).length);
    const operation: DraftOperation = {
      kind: 'delete_note_type', noteId: 0, cardId: 0, deckId: 0, fieldOrd: -1,
      before: JSON.stringify(capability), after: ''
    };
    return highRiskDraft(args.draftId, args.reason, [operation], noteIds, cardIds, [], [id]);
  }
}
