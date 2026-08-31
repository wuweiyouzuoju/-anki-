// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderFunctionTool } from './ProviderProtocol';
import { normalizeBatchLimit } from './AgentPolicy';
import type { AgentMode } from './AgentTypes';

function exampleArgumentsFor(name: string): string {
  switch (name) {
    case 'get_note_type_capabilities': return '{"notetypeIds":[1]}';
    case 'get_note_context': return '{"cardIds":[1],"noteIds":[1]}';
    case 'search_cards': return '{"query":"deck:example","limit":20}';
    case 'list_decks': return '{"query":"example","limit":20}';
    case 'propose_create_notes':
      return '{"targetDeckId":1,"targetNotetypeId":1,"notes":[{"fields":["<field-1>","<field-2>"]}],"draftId":"draft-1","reason":"<batch reason>"}';
    case 'propose_update_notes':
      return '{"noteIds":[1],"fieldUpdatesJson":"[{\\"noteId\\":1,\\"fieldOrd\\":0,\\"after\\":\\"updated\\"}]","draftId":"draft-1","reason":"<batch reason>"}';
    case 'propose_move_cards':
      return '{"cardIds":[1],"targetDeckId":1,"draftId":"draft-1","reason":"<batch reason>"}';
    case 'propose_delete_notes': return '{"noteIds":[1],"draftId":"draft-1","reason":"<high-risk reason>"}';
    case 'propose_delete_cards': return '{"cardIds":[1],"draftId":"draft-1","reason":"<high-risk reason>"}';
    case 'propose_change_note_type':
      return '{"noteIds":[1],"targetNotetypeId":1,"fieldMappingJson":"[0]","templateMappingJson":"[0]","draftId":"draft-1","reason":"<high-risk reason>"}';
    case 'propose_update_note_type_templates':
      return '{"notetypeIds":[1],"templateJson":"[]","css":"","draftId":"draft-1","reason":"<high-risk reason>"}';
    case 'propose_delete_deck': return '{"deckIds":[1],"draftId":"draft-1","reason":"<high-risk reason>"}';
    case 'propose_delete_note_type':
      return '{"notetypeIds":[1],"draftId":"draft-1","reason":"<high-risk reason>"}';
    default: return '{}';
  }
}

function rulesFor(name: string): string {
  if (name === 'propose_create_notes') {
    return 'reason is allowed only at the top level. Every notes[] item may contain only fields. ' +
      'fields must follow the real note-type field order. Cloze markup is allowed only in backend-declared ' +
      'cloze fields. Match an explicit requested card count exactly. This creates a draft, never a saved note.';
  }
  if (name.startsWith('propose_')) {
    return 'Use only stable in-scope IDs. This tool creates a draft and never writes immediately. ' +
      (name.startsWith('propose_delete_') || name === 'propose_change_note_type' ||
      name === 'propose_update_note_type_templates' ?
        'This high-risk draft requires separate user confirmations.' : 'User confirmation is required before writing.');
  }
  if (name === 'search_cards') { return 'This searches the local collection, not the public web.'; }
  return 'Use only stable IDs and values obtained from the current turn; never invent backend identifiers.';
}

function tool(name: string, description: string, properties: string,
  required: string): ProviderFunctionTool {
  return {
    name: name,
    description: description,
    parametersJson: `{"type":"object","properties":{${properties}},"required":[${required}],"additionalProperties":false}`,
    exampleArgumentsJson: exampleArgumentsFor(name),
    rules: rulesFor(name)
  };
}

const ID_ARRAY: string = '{"type":"array","items":{"type":"integer"},"maxItems":1000}';
const TEXT: string = '{"type":"string"}';
const ID: string = '{"type":"integer","minimum":1}';

/** 模型可见的完整语义工具表；不存在 RPC、数据库、文件或任意 HTTP 工具。 */
export function agentFunctionTools(batchLimit: number = 100, mode: AgentMode = 'edit'): ProviderFunctionTool[] {
  const createLimit: number = normalizeBatchLimit(batchLimit);
  const notes: string = `{"type":"array","minItems":1,"maxItems":${createLimit},"items":{"type":"object","properties":{"fields":{"type":"array","items":{"type":"string"}}},"required":["fields"],"additionalProperties":false}}`;
  const tools: ProviderFunctionTool[] = [
    tool('get_note_type_capabilities', '读取笔记类型结构、字段与填空字段序号。',
      `"notetypeIds":${ID_ARRAY}`, '"notetypeIds"'),
    tool('get_note_context', '读取当前笔记、卡片、字段、标签、牌组和兄弟卡片。',
      `"cardIds":${ID_ARRAY},"noteIds":${ID_ARRAY}`, '"cardIds","noteIds"'),
    tool('search_cards', '在当前 Anki 集合中搜索卡片，返回稳定 ID。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":1000}`, '"query","limit"'),
    tool('list_decks', '列出或按名称筛选牌组。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":1000}`, '"query","limit"'),
    tool('propose_create_notes', '提出一批可编辑笔记草稿；fields 必须按笔记类型字段顺序给出，只能提出，不能保存。',
      `"targetDeckId":${ID},"targetNotetypeId":${ID},"notes":${notes},"draftId":${TEXT},"reason":${TEXT}`,
      '"targetDeckId","targetNotetypeId","notes","draftId","reason"'),
    tool('propose_update_notes', '提出字段或标签修改草稿；只能提出，不能保存。',
      `"noteIds":${ID_ARRAY},"fieldUpdatesJson":${TEXT},"tags":{"type":"array","items":{"type":"string"}},"draftId":${TEXT},"reason":${TEXT}`,
      '"noteIds","fieldUpdatesJson","draftId","reason"'),
    tool('propose_move_cards', '提出移动卡片到牌组的草稿。',
      `"cardIds":${ID_ARRAY},"targetDeckId":${ID},"draftId":${TEXT},"reason":${TEXT}`,
      '"cardIds","targetDeckId","draftId","reason"'),
    tool('propose_delete_notes', '提出永久删除笔记及全部兄弟卡片的高风险草稿。',
      `"noteIds":${ID_ARRAY},"draftId":${TEXT},"reason":${TEXT}`, '"noteIds","draftId","reason"'),
    tool('propose_delete_cards', '提出永久删除指定卡片的高风险草稿。',
      `"cardIds":${ID_ARRAY},"draftId":${TEXT},"reason":${TEXT}`, '"cardIds","draftId","reason"'),
    tool('propose_change_note_type', '提出更改笔记类型和映射的高风险草稿。',
      `"noteIds":${ID_ARRAY},"targetNotetypeId":${ID},"fieldMappingJson":${TEXT},"templateMappingJson":${TEXT},"draftId":${TEXT},"reason":${TEXT}`,
      '"noteIds","targetNotetypeId","fieldMappingJson","templateMappingJson","draftId","reason"'),
    tool('propose_update_note_type_templates', '提出修改模板和 CSS 的高风险草稿。',
      `"notetypeIds":${ID_ARRAY},"templateJson":${TEXT},"css":${TEXT},"draftId":${TEXT},"reason":${TEXT}`,
      '"notetypeIds","templateJson","css","draftId","reason"'),
    tool('propose_delete_deck', '提出永久删除牌组及其子牌组内容的高风险草稿。',
      `"deckIds":${ID_ARRAY},"draftId":${TEXT},"reason":${TEXT}`, '"deckIds","draftId","reason"'),
    tool('propose_delete_note_type', '提出永久删除笔记类型及关联内容的高风险草稿。',
      `"notetypeIds":${ID_ARRAY},"draftId":${TEXT},"reason":${TEXT}`, '"notetypeIds","draftId","reason"')
  ];
  if (mode === 'edit') { return tools; }
  const createTools: ProviderFunctionTool[] = [];
  for (const value of tools) {
    if (value.name === 'get_note_type_capabilities' || value.name === 'list_decks' ||
      value.name === 'propose_create_notes') {
      createTools.push(value);
    }
  }
  return createTools;
}
