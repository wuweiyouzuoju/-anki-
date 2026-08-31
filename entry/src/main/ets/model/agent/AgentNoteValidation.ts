// SPDX-License-Identifier: AGPL-3.0-or-later

import type { NotetypeCapabilities } from '../../proto/messages/NotetypeMessages';
import { NOTE_TYPE_KIND_CLOZE } from '../../proto/messages/NotetypeMessages';

export interface AgentNoteValidationOptions {
  requireYearCloze: boolean;
}

function allowedClozeContainsYear(fields: string[], allowed: Set<number>): boolean {
  const answerPattern: RegExp = /\{\{c[1-9]\d*::([\s\S]+?)(?:::[\s\S]*?)?\}\}/g;
  const yearPattern: RegExp = /(?:1\d{3}|20\d{2}|21\d{2})/;
  for (let index: number = 0; index < fields.length; index++) {
    if (!allowed.has(index)) { continue; }
    answerPattern.lastIndex = 0;
    let match: RegExpExecArray | null = answerPattern.exec(fields[index]);
    while (match !== null) {
      if (yearPattern.test(match[1])) { return true; }
      match = answerPattern.exec(fields[index]);
    }
  }
  return false;
}

/**
 * 工具参数进入草稿前的笔记类型级校验。返回空串表示通过，否则返回
 * 可直接回传模型的稳定错误码，让 Agent 在同一轮自我修正。
 */
export function validateAgentNoteFields(capability: NotetypeCapabilities, fields: string[],
  options?: AgentNoteValidationOptions): string {
  if (fields.length !== capability.fieldNames.length || fields.length === 0) {
    return 'invalid_note_field_count';
  }
  if (fields[0].trim().length === 0) {
    return 'empty_note_first_field';
  }
  const clozePattern: RegExp = /\{\{c[1-9]\d*::[\s\S]+?\}\}/;
  const clozePrefixPattern: RegExp = /\{\{c\d+::/;
  if (capability.kind !== NOTE_TYPE_KIND_CLOZE) {
    for (const field of fields) {
      if (clozePrefixPattern.test(field)) { return 'cloze_in_normal_notetype'; }
    }
    return '';
  }
  if (capability.clozeFieldOrds.length === 0) { return 'unsupported_cloze_notetype'; }
  const allowed: Set<number> = new Set<number>();
  for (const ord of capability.clozeFieldOrds) {
    if (!Number.isSafeInteger(ord) || ord < 0 || ord >= fields.length) {
      return 'unsupported_cloze_notetype';
    }
    allowed.add(ord);
  }
  let hasValidCloze: boolean = false;
  for (let index: number = 0; index < fields.length; index++) {
    const hasPrefix: boolean = clozePrefixPattern.test(fields[index]);
    if (hasPrefix && !allowed.has(index)) { return 'cloze_in_disallowed_field'; }
    if (allowed.has(index) && clozePattern.test(fields[index])) { hasValidCloze = true; }
  }
  if (!hasValidCloze) { return 'missing_valid_cloze'; }
  if (options !== undefined && options.requireYearCloze && !allowedClozeContainsYear(fields, allowed)) {
    return 'missing_year_cloze';
  }
  return '';
}
