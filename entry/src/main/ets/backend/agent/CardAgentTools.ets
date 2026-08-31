// SPDX-License-Identifier: AGPL-3.0-or-later

import type { Card } from '../../proto/messages/CardsMessages';
import type { DeckTreeNode } from '../../proto/messages/DeckMessages';
import type { EditableNote } from '../../proto/messages/NoteMessages';
import type { NotetypeCapabilities } from '../../proto/messages/NotetypeMessages';
import type { AgentMode, ChangeDraft, DraftOperation } from '../../model/agent/AgentTypes';
import { validateAgentNoteFields } from '../../model/agent/AgentNoteValidation';
import { AgentToolArguments, AgentToolSchemaError, decodeAgentToolArguments } from '../../model/agent/AgentToolSchemas';
import { 卡片服务 } from '../卡片服务';
import { 搜索服务 } from '../搜索服务';
import { 牌组服务 } from '../牌组服务';
import { 笔记服务 } from '../笔记服务';
import { 笔记类型服务 } from '../笔记类型服务';
import { AgentScope } from './AgentScope';
import {
  AgentDraftToolHandler,
  AgentReadToolHandler,
  AgentToolRegistry
} from './AgentToolRegistry';

interface FieldUpdate {
  noteId: number;
  fieldOrd: number;
  after: string;
}

interface RawFieldUpdate {
  noteId?: number;
  fieldOrd?: number;
  after?: string;
}

interface CreateOperationGroup {
  noteId: number;
  operations: DraftOperation[];
}

interface AgentDeckView {
  deckId: number;
  name: string;
  cardCount: number;
}

interface AgentNoteContextView {
  noteId: number;
  notetypeId: number;
  fields: string[];
  tags: string[];
  cardIds: number[];
  deckIds: number[];
  capability: NotetypeCapabilities;
}

function parseFieldUpdates(json: string): FieldUpdate[] {
  let raw: RawFieldUpdate[];
  try {
    raw = JSON.parse(json) as RawFieldUpdate[];
  } catch (error) {
    throw new AgentToolSchemaError('invalid_tool_arguments');
  }
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 1000) {
    throw new AgentToolSchemaError('invalid_tool_arguments');
  }
  const result: FieldUpdate[] = [];
  for (const item of raw) {
    if (item === null || typeof item !== 'object' ||
      !Number.isSafeInteger(item.noteId) || item.noteId === undefined || item.noteId < 0 ||
      !Number.isSafeInteger(item.fieldOrd) || item.fieldOrd === undefined || item.fieldOrd < 0 ||
      typeof item.after !== 'string') {
      throw new AgentToolSchemaError('invalid_tool_arguments');
    }
    result.push({ noteId: item.noteId, fieldOrd: item.fieldOrd, after: item.after });
  }
  return result;
}

function uniqueIds(ids: number[]): number[] {
  const output: number[] = [];
  const seen: Set<number> = new Set<number>();
  for (const id of ids) {
    if (!seen.has(id)) {
      seen.add(id);
      output.push(id);
    }
  }
  return output;
}

function flattenDeckTree(node: DeckTreeNode, output: AgentDeckView[]): void {
  if (node.deckId > 0) {
    output.push({ deckId: node.deckId, name: node.name, cardCount: node.totalIncludingChildren });
  }
  for (const child of node.children) {
    flattenDeckTree(child, output);
  }
}

class NamedReadHandler implements AgentReadToolHandler {
  private readonly owner: CardAgentTools;
  private readonly name: string;
  constructor(owner: CardAgentTools, name: string) { this.owner = owner; this.name = name; }
  execute(argumentsJson: string): Promise<string> { return this.owner.executeRead(this.name, argumentsJson); }
}

class NamedDraftHandler implements AgentDraftToolHandler {
  private readonly owner: CardAgentTools;
  private readonly name: string;
  constructor(owner: CardAgentTools, name: string) { this.owner = owner; this.name = name; }
  propose(argumentsJson: string): Promise<ChangeDraft> { return this.owner.proposeDraft(this.name, argumentsJson); }
}

/** 只读上下文和普通写草稿；本文件不调用任何写 Service。 */
export class CardAgentTools {
  private readonly scope: AgentScope;
  private readonly notes: 笔记服务 = new 笔记服务();
  private readonly cards: 卡片服务 = new 卡片服务();
  private readonly notetypes: 笔记类型服务 = new 笔记类型服务();
  private readonly searches: 搜索服务 = new 搜索服务();
  private readonly decks: 牌组服务 = new 牌组服务();

  constructor(scope: AgentScope) { this.scope = scope; }

  register(registry: AgentToolRegistry, mode: AgentMode = 'edit'): void {
    registry.registerRead('get_note_type_capabilities', new NamedReadHandler(this, 'get_note_type_capabilities'));
    registry.registerRead('get_note_context', new NamedReadHandler(this, 'get_note_context'));
    registry.registerRead('search_cards', new NamedReadHandler(this, 'search_cards'));
    registry.registerRead('list_decks', new NamedReadHandler(this, 'list_decks'));
    if (mode === 'create') {
      registry.registerDraft('propose_create_notes', new NamedDraftHandler(this, 'propose_create_notes'));
    } else {
      registry.registerDraft('propose_update_notes', new NamedDraftHandler(this, 'propose_update_notes'));
      registry.registerDraft('propose_move_cards', new NamedDraftHandler(this, 'propose_move_cards'));
    }
  }

  async executeRead(name: string, argumentsJson: string): Promise<string> {
    const args: AgentToolArguments = decodeAgentToolArguments(name, argumentsJson);
    if (name === 'get_note_type_capabilities') {
      this.scope.assertNotetypeIdsInScope(args.notetypeIds);
      const values: NotetypeCapabilities[] = [];
      for (const id of args.notetypeIds) {
        values.push(await this.notetypes.获取笔记类型能力(id));
      }
      return JSON.stringify(values);
    }
    if (name === 'get_note_context') {
      return this.getNoteContext(args);
    }
    if (name === 'search_cards') {
      const allIds: number[] = await this.searches.搜索卡片({
        search: args.query,
        order: { kind: 'none' }
      });
      const limit: number = Math.min(1000, args.limit === 0 ? 100 : args.limit);
      const ids: number[] = allIds.slice(0, limit);
      this.scope.registerCardIds(ids);
      return JSON.stringify({ cardIds: ids, totalMatched: allIds.length });
    }
    const tree: DeckTreeNode = await this.decks.获取牌组树();
    const allDecks: AgentDeckView[] = [];
    flattenDeckTree(tree, allDecks);
    const filtered: AgentDeckView[] = [];
    const query: string = args.query.toLocaleLowerCase();
    for (const deck of allDecks) {
      if (query.length === 0 || deck.name.toLocaleLowerCase().includes(query)) {
        filtered.push(deck);
      }
    }
    const limit: number = Math.min(1000, args.limit === 0 ? 100 : args.limit);
    const result: AgentDeckView[] = filtered.slice(0, limit);
    this.scope.registerDeckIds(result.map((deck: AgentDeckView): number => deck.deckId));
    return JSON.stringify({ decks: result, totalMatched: filtered.length });
  }

  async proposeDraft(name: string, argumentsJson: string): Promise<ChangeDraft> {
    const args: AgentToolArguments = decodeAgentToolArguments(name, argumentsJson);
    let draft: ChangeDraft;
    if (name === 'propose_create_notes') {
      draft = await this.proposeCreate(args);
    } else if (name === 'propose_update_notes') {
      draft = await this.proposeUpdate(args);
    } else {
      draft = await this.proposeMove(args);
    }
    if (!this.scope.registerDraftId(args.draftId)) {
      throw new AgentToolSchemaError('duplicate_draft_id');
    }
    return draft;
  }

  private async getNoteContext(args: AgentToolArguments): Promise<string> {
    this.scope.assertCardIdsInScope(args.cardIds);
    this.scope.assertNoteIdsInScope(args.noteIds);
    const noteIds: number[] = args.noteIds.slice();
    for (const cardId of args.cardIds) {
      const card: Card = await this.cards.获取卡片(cardId);
      noteIds.push(card.noteId);
      this.scope.registerNoteIds([card.noteId]);
      this.scope.registerDeckIds([card.deckId]);
    }
    const contexts: AgentNoteContextView[] = [];
    for (const noteId of uniqueIds(noteIds)) {
      const note: EditableNote = await this.notes.获取笔记(noteId);
      const cardIds: number[] = await this.notes.获取笔记的卡片(noteId);
      const deckIds: number[] = [];
      for (const cardId of cardIds) {
        const card: Card = await this.cards.获取卡片(cardId);
        deckIds.push(card.deckId);
      }
      const capability: NotetypeCapabilities = await this.notetypes.获取笔记类型能力(note.notetypeId);
      this.scope.registerCardIds(cardIds);
      this.scope.registerNotetypeIds([note.notetypeId]);
      this.scope.registerDeckIds(uniqueIds(deckIds));
      contexts.push({
        noteId: note.id,
        notetypeId: note.notetypeId,
        fields: note.fields.slice(),
        tags: note.tags.slice(),
        cardIds: cardIds,
        deckIds: uniqueIds(deckIds),
        capability: capability
      });
    }
    return JSON.stringify(contexts);
  }

  private async proposeCreate(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertDeckIdsInScope([args.targetDeckId]);
    this.scope.assertNotetypeIdsInScope([args.targetNotetypeId]);
    this.scope.assertCreateTarget(args.targetDeckId, args.targetNotetypeId);
    this.scope.assertBatchCount(args.createNotes.length);
    const capability: NotetypeCapabilities = await this.notetypes.获取笔记类型能力(args.targetNotetypeId);
    for (let index: number = 0; index < args.createNotes.length; index++) {
      const item = args.createNotes[index];
      const validationError: string = validateAgentNoteFields(capability, item.fields,
        { requireYearCloze: this.scope.createRequiresYearCloze() });
      if (validationError.length > 0) {
        throw new AgentToolSchemaError(validationError, `notes[${index}].fields`,
          validationError === 'missing_year_cloze' ?
            'Every requested card must contain a four-digit year inside an allowed cloze answer' :
            'The note fields do not satisfy the selected note type');
      }
    }
    const operations: DraftOperation[] = [];
    const groups: CreateOperationGroup[] = this.parseCreateNotes(args);
    for (const group of groups) {
      for (const operation of group.operations) {
        operations.push(operation);
      }
    }
    return {
      id: args.draftId, risk: 'write', summary: args.reason,
      baselineHash: '', confirmationLevel: 1, status: 'pending',
      affectedNoteIds: [], affectedCardIds: [], affectedDeckIds: [args.targetDeckId],
      affectedNotetypeIds: [args.targetNotetypeId], operations: operations
    };
  }

  private parseCreateNotes(args: AgentToolArguments): CreateOperationGroup[] {
    const result: CreateOperationGroup[] = [];
    for (let index: number = 0; index < args.createNotes.length; index++) {
      const noteId: number = -(index + 1);
      const fields: string[] = args.createNotes[index].fields;
      const operations: DraftOperation[] = [];
      for (let fieldOrd: number = 0; fieldOrd < fields.length; fieldOrd++) {
        operations.push({
          kind: 'create_note', noteId: noteId, cardId: 0, deckId: args.targetDeckId,
          fieldOrd: fieldOrd, before: '', after: fields[fieldOrd]
        });
      }
      result.push({ noteId: noteId, operations: operations });
    }
    return result;
  }

  private async proposeUpdate(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertNoteIdsInScope(args.noteIds);
    const updates: FieldUpdate[] = parseFieldUpdates(args.fieldUpdatesJson);
    const operations: DraftOperation[] = [];
    const affectedCards: number[] = [];
    for (const noteId of args.noteIds) {
      const note: EditableNote = await this.notes.获取笔记(noteId);
      const cardIds: number[] = await this.notes.获取笔记的卡片(noteId);
      affectedCards.push(...cardIds);
      for (const update of updates) {
        if (update.noteId === noteId) {
          if (update.fieldOrd >= note.fields.length) {
            throw new AgentToolSchemaError('invalid_tool_arguments');
          }
          operations.push({
            kind: 'update_field', noteId: noteId, cardId: 0, deckId: 0,
            fieldOrd: update.fieldOrd, before: note.fields[update.fieldOrd], after: update.after
          });
        }
      }
      if (args.tags.length > 0) {
        operations.push({
          kind: 'update_tags', noteId: noteId, cardId: 0, deckId: 0, fieldOrd: -1,
          before: JSON.stringify(note.tags), after: JSON.stringify(args.tags)
        });
      }
    }
    return {
      id: args.draftId, risk: 'write', summary: args.reason,
      baselineHash: JSON.stringify(operations), confirmationLevel: 1, status: 'pending',
      affectedNoteIds: args.noteIds.slice(), affectedCardIds: uniqueIds(affectedCards),
      affectedDeckIds: [], affectedNotetypeIds: [],
      operations: operations
    };
  }

  private async proposeMove(args: AgentToolArguments): Promise<ChangeDraft> {
    this.scope.assertCardIdsInScope(args.cardIds);
    this.scope.assertDeckIdsInScope([args.targetDeckId]);
    const operations: DraftOperation[] = [];
    const noteIds: number[] = [];
    for (const cardId of args.cardIds) {
      const card: Card = await this.cards.获取卡片(cardId);
      noteIds.push(card.noteId);
      operations.push({
        kind: 'move_card', noteId: card.noteId, cardId: card.id, deckId: args.targetDeckId,
        fieldOrd: -1, before: String(card.deckId), after: String(args.targetDeckId)
      });
    }
    return {
      id: args.draftId, risk: 'write', summary: args.reason,
      baselineHash: JSON.stringify(operations), confirmationLevel: 1, status: 'pending',
      affectedNoteIds: uniqueIds(noteIds), affectedCardIds: args.cardIds.slice(),
      affectedDeckIds: [args.targetDeckId], affectedNotetypeIds: [],
      operations: operations
    };
  }
}
