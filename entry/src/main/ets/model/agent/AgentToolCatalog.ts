// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ProviderFunctionTool } from './ProviderProtocol';
import { normalizeBatchLimit } from './AgentPolicy';
import type { AgentMode } from './AgentTypes';
import { agentExtensionTools } from './AgentExtensionTools';

function exampleArgumentsFor(name: string): string {
  switch (name) {
    case 'request_clarification':
      return '{"clarificationId":"scope-1","question":"Choose one card organization.","options":[{"id":"one-per-fact","label":"One per fact","description":"More focused cards"},{"id":"chapter-summary","label":"Chapter summary","description":"Fewer cards"}],"recommendedOptionId":"one-per-fact","allowFreeText":true}';
    case 'get_note_type_capabilities': return '{"notetypeIds":[1]}';
    case 'get_note_context': return '{"cardIds":[1],"noteIds":[1]}';
    case 'search_cards': return '{"query":"deck:example","limit":20}';
    case 'search_notes': return '{"query":"tag:important","limit":20}';
    case 'list_decks': return '{"query":"example","limit":20}';
    case 'list_notetypes': return '{"query":"basic","limit":20}';
    case 'list_tags': return '{"query":"important","limit":50}';
    case 'get_notetype_details': return '{"notetypeIds":[1]}';
    case 'read_note_field': return '{"noteId":1,"fieldOrd":0,"offset":0,"length":12000}';
    case 'get_card_statistics': return '{"cardIds":[1],"limit":50}';
    case 'search_images': return '{"query":"中国传统文化","limit":5}';
    case 'create_flashcards':
      return '{"cards":[{"fields":["<field-1>","<field-2>"]}]}';
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
  if (name === 'request_clarification') {
    return 'Ask when missing information materially changes the content, difficulty or scope. For an open question use options=[] and allowFreeText=true. Do not ask about reasonable defaults or already answered questions. Call alone; never writes.';
  }
  if (name === 'create_flashcards') {
    return 'Submit only card content. Every cards[] item may contain fields and optional images. The application supplies ' +
      'the selected deck, note type, draft identity, and summary; never include those values in arguments. ' +
      'A card may use a fields array or exact selected note-type field names with string values. ' +
      'fields must follow the real note-type field order. Cloze markup is allowed only in backend-declared ' +
      'cloze fields. Match an explicit requested card count exactly. Use only candidateId values from search_images. ' +
      'This creates a draft, never a saved note.';
  }
  if (name.startsWith('propose_')) {
    return 'Use only IDs actually discovered in this session. This tool creates a draft and never writes immediately. ' +
      (name.startsWith('propose_delete_') || name === 'propose_change_note_type' ||
      name === 'propose_update_note_type_templates' ?
        'This high-risk draft requires separate user confirmations.' : 'User confirmation is required before writing.');
  }
  if (name === 'search_cards' || name === 'search_notes') {
    return 'Search the whole local collection. Use deck:/note: only when requested. Continue with nextCursor and the same query until empty; totalMatched is not the number read. Found IDs may be proposed for changes, but only user-confirmed drafts can write.';
  }
  if (name === 'search_images') {
    return 'Search only Wikimedia Commons. This is read-only. Use returned candidateId values in image drafts; never invent URLs.';
  }
  return 'Use only stable IDs and values obtained from this session; never invent backend identifiers.';
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
const IMAGE_ATTACHMENT: string =
  '{"type":"object","properties":{"candidateId":{"type":"string","minLength":1,"maxLength":200},' +
  '"fieldOrd":{"type":"integer","minimum":0},"placement":{"type":"string","enum":["append"]},' +
  '"altText":{"type":"string","maxLength":200}},"required":["candidateId","fieldOrd"],"additionalProperties":false}';

/** 模型可见的完整语义工具表；不存在 RPC、数据库、文件或任意 HTTP 工具。 */
export function agentFunctionTools(batchLimit: number = 100, mode: AgentMode = 'edit'): ProviderFunctionTool[] {
  const createLimit: number = normalizeBatchLimit(batchLimit);
  const notes: string = `{"type":"array","minItems":1,"maxItems":${createLimit},"items":{"type":"object","properties":{"fields":{"type":"array","items":{"type":"string"}},"images":{"type":"array","maxItems":1,"items":${IMAGE_ATTACHMENT}}},"required":[],"additionalProperties":{"type":"string"}}}`;
  const tools: ProviderFunctionTool[] = [
    tool('request_clarification', '提出一个需要用户选择的澄清问题；只等待回答，绝不写入。',
      '"clarificationId":{"type":"string","minLength":1,"maxLength":64},"question":{"type":"string","minLength":1,"maxLength":600},"options":{"type":"array","minItems":0,"maxItems":4,"items":{"type":"object","properties":{"id":{"type":"string","minLength":1,"maxLength":64},"label":{"type":"string","minLength":1,"maxLength":80},"description":{"type":"string","maxLength":240}},"required":["id","label"],"additionalProperties":false}},"recommendedOptionId":{"type":"string","maxLength":64},"allowFreeText":{"type":"boolean"}',
      '"clarificationId","question","options","allowFreeText"'),
    tool('get_note_type_capabilities', '读取笔记类型结构、字段与填空字段序号。',
      `"notetypeIds":${ID_ARRAY}`, '"notetypeIds"'),
    tool('get_note_context', '读取当前笔记、卡片、字段、标签、牌组和兄弟卡片。',
      `"cardIds":${ID_ARRAY},"noteIds":${ID_ARRAY},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":5}`, '"cardIds","noteIds"'),
    tool('search_cards', '在当前 Anki 集合中搜索卡片，返回稳定 ID。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":200},"cursor":${TEXT}`, '"query","limit"'),
    tool('search_notes', '在当前 Anki 集合中搜索笔记，返回稳定 ID；结果只读，不扩大修改范围。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":200},"cursor":${TEXT}`, '"query","limit"'),
    tool('list_decks', '列出或按名称筛选牌组。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":1000},"offset":{"type":"integer","minimum":0}`, '"query","limit"'),
    tool('list_notetypes', '列出或按名称筛选笔记类型，返回稳定 ID 与结构摘要。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":1000},"offset":{"type":"integer","minimum":0}`, '"query","limit"'),
    tool('list_tags', '列出或按名称筛选标签。',
      `"query":${TEXT},"limit":{"type":"integer","minimum":1,"maximum":1000},"offset":{"type":"integer","minimum":0}`, '"query","limit"'),
    tool('get_notetype_details', '读取笔记类型结构；长模板/CSS 用 offset=nextOffset 续读，nextOffset=-1 表示读完。',
      `"notetypeIds":${ID_ARRAY},"offset":{"type":"integer","minimum":0},"length":{"type":"integer","minimum":1,"maximum":12000}`, '"notetypeIds"'),
    tool('read_note_field', '按字符位置续读笔记字段全文；nextOffset=-1 表示读完，禁止把片段当作全文。',
      '"noteId":'+ID+',"fieldOrd":{"type":"integer","minimum":0},"offset":{"type":"integer","minimum":0},"length":{"type":"integer","minimum":1,"maximum":12000}', '"noteId","fieldOrd"'),
    tool('get_card_statistics', '读取指定卡片的调度统计与最近复习历史；limit 是每张卡最多返回的历史条数。',
      `"cardIds":${ID_ARRAY},"limit":{"type":"integer","minimum":1,"maximum":200}`, '"cardIds","limit"'),
    tool('search_images', '搜索 Wikimedia Commons 图片候选；只读，返回候选 ID、预览、来源和许可证。',
      `"query":{"type":"string","minLength":1,"maxLength":200},"limit":{"type":"integer","minimum":1,"maximum":10}`,
      '"query","limit"'),
    tool('create_flashcards', '生成一批待确认闪卡；只提交 cards 内容，目标牌组、笔记类型和草稿标识由应用注入。可引用 search_images 返回的图片候选。',
      `"cards":${notes}`, '"cards"'),
    tool('propose_update_notes', '提出字段、标签或图片修改草稿；imagesJson 使用 search_images 返回的 candidateId；只能提出，不能保存。',
      `"noteIds":${ID_ARRAY},"fieldUpdatesJson":${TEXT},"imagesJson":${TEXT},"tags":{"type":"array","items":{"type":"string"}},"draftId":${TEXT},"reason":${TEXT}`,
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
  if (mode === 'edit') {
    return tools.filter((value: ProviderFunctionTool): boolean => value.name !== 'create_flashcards').concat(agentExtensionTools());
  }
  const createTools: ProviderFunctionTool[] = [];
  for (const value of tools) {
    if (!value.name.startsWith('propose_')) {
      createTools.push(value);
    }
  }
  return createTools.concat(agentExtensionTools());
}
