// SPDX-License-Identifier: AGPL-3.0-or-later

/** Agent 语义工具的固定参数布局；禁止动态 RPC/数据库/文件参数。 */

import type { AgentToolDiagnostic } from './AgentTypes';
import { agentFunctionTools } from './AgentToolCatalog';

export interface AgentToolArguments {
  cardIds: number[];
  noteIds: number[];
  deckIds: number[];
  notetypeIds: number[];
  query: string;
  limit: number;
  draftId: string;
  targetDeckId: number;
  targetNotetypeId: number;
  fieldUpdatesJson: string;
  fieldMappingJson: string;
  templateMappingJson: string;
  templateJson: string;
  css: string;
  tags: string[];
  reason: string;
  createNotes: AgentCreateNote[];
}

export interface AgentCreateNote {
  fields: string[];
}

interface RawAgentCreateNote {
  fields?: string[];
}

interface RawAgentToolArguments {
  cardIds?: number[];
  noteIds?: number[];
  deckIds?: number[];
  notetypeIds?: number[];
  query?: string;
  limit?: number;
  draftId?: string;
  targetDeckId?: number;
  targetNotetypeId?: number;
  fieldUpdatesJson?: string;
  fieldMappingJson?: string;
  templateMappingJson?: string;
  templateJson?: string;
  css?: string;
  tags?: string[];
  reason?: string;
  notes?: RawAgentCreateNote[];
}

export class AgentToolSchemaError extends Error {
  readonly code: string;
  readonly path: string;
  readonly detailMessage: string;
  readonly receivedKeys: string[];
  readonly allowedKeys: string[];
  readonly validTemplateJson: string;

  constructor(code: string, path: string = '', detailMessage: string = '',
    receivedKeys: string[] = [], allowedKeys: string[] = [], validTemplateJson: string = '') {
    super(code === 'tool_batch_too_large' ? code : 'invalid_tool_arguments');
    this.code = code;
    this.path = path;
    this.detailMessage = detailMessage;
    this.receivedKeys = receivedKeys.slice();
    this.allowedKeys = allowedKeys.slice();
    this.validTemplateJson = validTemplateJson;
  }

  diagnostic(): AgentToolDiagnostic {
    return {
      code: this.code, path: this.path, message: this.detailMessage,
      receivedKeys: this.receivedKeys.slice(), allowedKeys: this.allowedKeys.slice(),
      validTemplateJson: this.validTemplateJson
    };
  }
}

function validTemplate(toolName: string): string {
  const tools = agentFunctionTools(1000, 'edit');
  for (const item of tools) {
    if (item.name === toolName) { return item.exampleArgumentsJson; }
  }
  return '{}';
}

function schemaError(toolName: string, code: string, path: string, message: string,
  receivedKeys: string[] = [], allowed: string[] = []): AgentToolSchemaError {
  return new AgentToolSchemaError(code, path, message, receivedKeys, allowed, validTemplate(toolName));
}

function emptyArguments(): AgentToolArguments {
  return {
    cardIds: [], noteIds: [], deckIds: [], notetypeIds: [],
    query: '', limit: 0, draftId: '', targetDeckId: 0, targetNotetypeId: 0,
    fieldUpdatesJson: '', fieldMappingJson: '', templateMappingJson: '',
    templateJson: '', css: '', tags: [], reason: '', createNotes: []
  };
}

function allowedKeys(toolName: string): string[] {
  switch (toolName) {
    case 'get_note_type_capabilities':
      return ['notetypeIds'];
    case 'get_note_context':
      return ['cardIds', 'noteIds'];
    case 'search_cards':
      return ['query', 'limit'];
    case 'list_decks':
      return ['query', 'limit'];
    case 'propose_create_notes':
      return ['targetDeckId', 'targetNotetypeId', 'notes', 'draftId', 'reason'];
    case 'propose_update_notes':
      return ['noteIds', 'fieldUpdatesJson', 'tags', 'draftId', 'reason'];
    case 'propose_move_cards':
      return ['cardIds', 'targetDeckId', 'draftId', 'reason'];
    case 'propose_delete_notes':
      return ['noteIds', 'draftId', 'reason'];
    case 'propose_delete_cards':
      return ['cardIds', 'draftId', 'reason'];
    case 'propose_change_note_type':
      return ['noteIds', 'targetNotetypeId', 'fieldMappingJson', 'templateMappingJson', 'draftId', 'reason'];
    case 'propose_update_note_type_templates':
      return ['notetypeIds', 'templateJson', 'css', 'draftId', 'reason'];
    case 'propose_delete_deck':
      return ['deckIds', 'draftId', 'reason'];
    case 'propose_delete_note_type':
      return ['notetypeIds', 'draftId', 'reason'];
    default:
      return [];
  }
}

function isAllowed(key: string, allowed: string[]): boolean {
  for (const value of allowed) {
    if (value === key) {
      return true;
    }
  }
  return false;
}

function validateIds(toolName: string, path: string, value: number[] | undefined): number[] {
  if (value === undefined) {
    return [];
  }
  if (!Array.isArray(value)) {
    throw schemaError(toolName, 'invalid_type', path, `${path} must be an array of positive integer IDs`);
  }
  if (value.length > 1000) {
    throw schemaError(toolName, 'tool_batch_too_large', path, `${path} exceeds the 1000 item safety limit`);
  }
  const output: number[] = [];
  const seen: Set<number> = new Set<number>();
  for (let index: number = 0; index < value.length; index++) {
    const id: number = value[index];
    if (!Number.isSafeInteger(id) || id <= 0) {
      throw schemaError(toolName, 'invalid_value', `${path}[${index}]`, 'ID must be a positive safe integer');
    }
    if (!seen.has(id)) {
      seen.add(id);
      output.push(id);
    }
  }
  return output;
}

function stringValue(toolName: string, path: string, value: string | undefined): string {
  if (value === undefined) {
    return '';
  }
  if (typeof value !== 'string') {
    throw schemaError(toolName, 'invalid_type', path, `${path} must be a string`);
  }
  return value;
}

function positiveId(toolName: string, path: string, value: number | undefined): number {
  if (value === undefined) {
    return 0;
  }
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw schemaError(toolName, 'invalid_value', path, `${path} must be a positive safe integer`);
  }
  return value;
}

function validateCreateNotes(toolName: string, value: RawAgentCreateNote[] | undefined): AgentCreateNote[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 1000) {
    const code: string = Array.isArray(value) && value.length > 1000 ? 'tool_batch_too_large' : 'invalid_value';
    throw schemaError(toolName, code, 'notes', 'notes must be a non-empty array within the safety limit');
  }
  const result: AgentCreateNote[] = [];
  for (let noteIndex: number = 0; noteIndex < value.length; noteIndex++) {
    const item: RawAgentCreateNote = value[noteIndex];
    if (item === null || typeof item !== 'object' || Array.isArray(item)) {
      throw schemaError(toolName, 'invalid_type', `notes[${noteIndex}]`, 'Each notes[] item must be an object');
    }
    const keys: string[] = Object.keys(item);
    for (const key of keys) {
      if (key !== 'fields') {
        throw schemaError(toolName, 'unexpected_property', `notes[${noteIndex}].${key}`,
          `${key} is not allowed inside notes[]; reason is allowed only at the top level`,
          keys, ['fields']);
      }
    }
    if (item.fields === undefined) {
      throw schemaError(toolName, 'missing_property', `notes[${noteIndex}].fields`,
        'Each notes[] item requires fields', keys, ['fields']);
    }
    if (!Array.isArray(item.fields)) {
      throw schemaError(toolName, 'invalid_type', `notes[${noteIndex}].fields`, 'fields must be a string array');
    }
    if (item.fields.length === 0 || item.fields.length > 100) {
      throw schemaError(toolName, 'invalid_value', `notes[${noteIndex}].fields`,
        'fields must contain between 1 and 100 strings');
    }
    const fields: string[] = [];
    for (let fieldIndex: number = 0; fieldIndex < item.fields.length; fieldIndex++) {
      const field: string = item.fields[fieldIndex];
      if (typeof field !== 'string') {
        throw schemaError(toolName, 'invalid_type', `notes[${noteIndex}].fields[${fieldIndex}]`,
          'Every field value must be a string');
      }
      fields.push(field);
    }
    result.push({ fields: fields });
  }
  return result;
}

export function decodeAgentToolArguments(toolName: string, argumentsJson: string): AgentToolArguments {
  const allowed: string[] = allowedKeys(toolName);
  if (allowed.length === 0) {
    throw new AgentToolSchemaError('invalid_tool_arguments');
  }
  let raw: RawAgentToolArguments;
  try {
    raw = JSON.parse(argumentsJson) as RawAgentToolArguments;
  } catch (error) {
    throw schemaError(toolName, 'invalid_json', '$', 'Tool arguments must be one valid JSON object');
  }
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw schemaError(toolName, 'invalid_type', '$', 'Tool arguments must be one JSON object');
  }
  const receivedKeys: string[] = Object.keys(raw);
  for (const key of receivedKeys) {
    if (!isAllowed(key, allowed)) {
      throw schemaError(toolName, 'unexpected_property', key, `${key} is not a declared tool argument`,
        receivedKeys, allowed);
    }
  }
  const output: AgentToolArguments = emptyArguments();
  output.cardIds = validateIds(toolName, 'cardIds', raw.cardIds);
  output.noteIds = validateIds(toolName, 'noteIds', raw.noteIds);
  output.deckIds = validateIds(toolName, 'deckIds', raw.deckIds);
  output.notetypeIds = validateIds(toolName, 'notetypeIds', raw.notetypeIds);
  output.query = stringValue(toolName, 'query', raw.query).trim();
  output.draftId = stringValue(toolName, 'draftId', raw.draftId).trim();
  output.fieldUpdatesJson = stringValue(toolName, 'fieldUpdatesJson', raw.fieldUpdatesJson);
  output.fieldMappingJson = stringValue(toolName, 'fieldMappingJson', raw.fieldMappingJson);
  output.templateMappingJson = stringValue(toolName, 'templateMappingJson', raw.templateMappingJson);
  output.templateJson = stringValue(toolName, 'templateJson', raw.templateJson);
  output.css = stringValue(toolName, 'css', raw.css);
  output.reason = stringValue(toolName, 'reason', raw.reason).trim();
  output.targetDeckId = positiveId(toolName, 'targetDeckId', raw.targetDeckId);
  output.targetNotetypeId = positiveId(toolName, 'targetNotetypeId', raw.targetNotetypeId);
  if (toolName === 'propose_create_notes') {
    output.createNotes = validateCreateNotes(toolName, raw.notes);
  }
  if (raw.limit !== undefined) {
    if (!Number.isSafeInteger(raw.limit) || raw.limit <= 0 || raw.limit > 1000) {
      throw schemaError(toolName, 'invalid_value', 'limit', 'limit must be an integer between 1 and 1000');
    }
    output.limit = raw.limit;
  }
  if (raw.tags !== undefined) {
    if (!Array.isArray(raw.tags) || raw.tags.length > 100) {
      throw schemaError(toolName, 'invalid_value', 'tags', 'tags must be an array with at most 100 items');
    }
    for (let tagIndex: number = 0; tagIndex < raw.tags.length; tagIndex++) {
      const tag: string = raw.tags[tagIndex];
      if (typeof tag !== 'string' || tag.length > 200) {
        throw schemaError(toolName, 'invalid_value', `tags[${tagIndex}]`, 'tag must be a string of at most 200 characters');
      }
      output.tags.push(tag);
    }
  }
  return output;
}
