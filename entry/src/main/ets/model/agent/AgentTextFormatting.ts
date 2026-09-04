// SPDX-License-Identifier: AGPL-3.0-or-later

export interface AgentTextRun { text: string; bold: boolean; }

function codeEnd(text: string, start: number): number {
  let length: number = 1;
  while (text[start + length] === '`') { length += 1; }
  const end: number = text.indexOf('`'.repeat(length), start + length);
  return end < 0 ? text.length : end + length;
}

function isDoubleStar(text: string, index: number): boolean {
  return text.slice(index, index + 2) === '**' && text[index - 1] !== '*' && text[index + 2] !== '*';
}

function boldEnd(text: string, start: number): number {
  for (let index: number = start; index < text.length; index++) {
    if (text[index] === '\\') { index += 1; continue; }
    if (text[index] === '`') { index = codeEnd(text, index) - 1; continue; }
    if (isDoubleStar(text, index) && index > start && !/\s/.test(text[index - 1])) { return index; }
    if (text.slice(index, index + 2) === '\n\n') { return -1; }
  }
  return -1;
}

/** 仅改变显示：成对的 ** 加粗，未闭合的流式文本和代码中的星号保持原文。 */
export function parseAgentBoldRuns(text: string): AgentTextRun[] {
  const runs: AgentTextRun[] = [];
  let plain: string = '';
  let index: number = 0;
  while (index < text.length) {
    if (text[index] === '\\' && (text[index + 1] === '*' || text[index + 1] === '\\')) {
      plain += text[index + 1]; index += 2; continue;
    }
    if (text[index] === '`') {
      const end: number = codeEnd(text, index);
      plain += text.slice(index, end); index = end; continue;
    }
    if (isDoubleStar(text, index) && index + 2 < text.length && !/\s/.test(text[index + 2])) {
      const end: number = boldEnd(text, index + 2);
      if (end >= 0) {
        if (plain.length > 0) { runs.push({ text: plain, bold: false }); plain = ''; }
        runs.push({ text: text.slice(index + 2, end), bold: true });
        index = end + 2; continue;
      }
    }
    plain += text[index]; index += 1;
  }
  if (plain.length > 0) { runs.push({ text: plain, bold: false }); }
  return runs;
}
