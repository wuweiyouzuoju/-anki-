// SPDX-License-Identifier: AGPL-3.0-or-later

/** 文档解析后的纯文本统一在这里清洗，避免各格式保留不可见控制字符。 */
export function normalizeAgentDocumentText(content: string): string {
  return content
    .replace(new RegExp('\\r\\n?', 'g'), '\n')
    .replace(new RegExp('[ \\t]+\\n', 'g'), '\n')
    .replace(new RegExp('\\n[ \\t]+', 'g'), '\n')
    .replace(new RegExp('\\n{3,}', 'g'), '\n\n')
    .trim();
}

function decodeNumericEntity(value: string, radix: number, original: string): string {
  const code: number = Number.parseInt(value, radix);
  if (!Number.isFinite(code) || code < 0 || code > 0x10FFFF) { return original; }
  try {
    return String.fromCodePoint(code);
  } catch (error) {
    return original;
  }
}

export function decodeAgentMarkupEntities(content: string): string {
  if (content.indexOf('&') < 0) { return content; }
  return content
    .replace(new RegExp('&#([0-9]+);', 'g'), (original: string, value: string): string =>
      decodeNumericEntity(value, 10, original))
    .replace(new RegExp('&#x([0-9a-fA-F]+);', 'g'), (original: string, value: string): string =>
      decodeNumericEntity(value, 16, original))
    .replace(new RegExp('&nbsp;', 'gi'), ' ')
    .replace(new RegExp('&amp;', 'gi'), '&')
    .replace(new RegExp('&lt;', 'gi'), '<')
    .replace(new RegExp('&gt;', 'gi'), '>')
    .replace(new RegExp('&quot;', 'gi'), '"')
    .replace(new RegExp('&apos;|&#39;', 'gi'), "'");
}

/** HTML/XML/OOXML 共用的保守文字提取器。 */
export function agentMarkupToPlainText(content: string): string {
  const withoutHidden: string = content
    .replace(new RegExp('<!--[\\s\\S]*?-->', 'g'), '')
    .replace(new RegExp('<script\\b[^>]*>[\\s\\S]*?<\\/script>', 'gi'), '')
    .replace(new RegExp('<style\\b[^>]*>[\\s\\S]*?<\\/style>', 'gi'), '');
  const withBreaks: string = withoutHidden
    .replace(new RegExp('<(?:br|w:br|w:cr)\\b[^>]*\\/?>', 'gi'), '\n')
    .replace(new RegExp('<w:tab\\b[^>]*\\/?>', 'gi'), '\t')
    .replace(new RegExp('<\\/(?:p|div|li|tr|h[1-6]|w:p|a:p|text:p|text:h)>', 'gi'), '\n')
    .replace(new RegExp('<\\/(?:td|th|w:tc|table:table-cell)>', 'gi'), '\t');
  const withoutTags: string = withBreaks.replace(new RegExp('<[^>]+>', 'g'), '');
  return normalizeAgentDocumentText(decodeAgentMarkupEntities(withoutTags));
}

export function extractAgentSharedStrings(content: string): string[] {
  const values: string[] = [];
  const itemPattern: RegExp = new RegExp('<si\\b[^>]*>([\\s\\S]*?)<\\/si>', 'gi');
  let match: RegExpExecArray | null = itemPattern.exec(content);
  while (match !== null) {
    values.push(agentMarkupToPlainText(match[1]));
    match = itemPattern.exec(content);
  }
  return values;
}

function firstXmlValue(content: string, tag: string): string {
  const pattern: RegExp = new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
  const match: RegExpMatchArray | null = content.match(pattern);
  return match === null ? '' : decodeAgentMarkupEntities(match[1]);
}

function spreadsheetColumnIndex(attributes: string): number {
  const referenceMatch: RegExpMatchArray | null = attributes.match(
    new RegExp('\\br=["\']([A-Za-z]+)[0-9]+["\']', 'i'));
  if (referenceMatch === null) { return -1; }
  const letters: string = referenceMatch[1].toLocaleUpperCase();
  let value: number = 0;
  for (let index: number = 0; index < letters.length; index++) {
    value = value * 26 + letters.charCodeAt(index) - 64;
  }
  return value - 1;
}

/** 把 XLSX 工作表还原成稳定的 TSV 文本，供模型理解行列关系。 */
export function extractAgentWorksheetText(content: string, sharedStrings: string[]): string {
  const outputRows: string[] = [];
  const rowPattern: RegExp = new RegExp('<row\\b[^>]*>([\\s\\S]*?)<\\/row>', 'gi');
  let rowMatch: RegExpExecArray | null = rowPattern.exec(content);
  while (rowMatch !== null) {
    const values: string[] = [];
    const cellPattern: RegExp = new RegExp('<c\\b([^>]*)>([\\s\\S]*?)<\\/c>', 'gi');
    let cellMatch: RegExpExecArray | null = cellPattern.exec(rowMatch[1]);
    while (cellMatch !== null) {
      const attributes: string = cellMatch[1];
      const body: string = cellMatch[2];
      const columnIndex: number = spreadsheetColumnIndex(attributes);
      while (columnIndex >= 0 && values.length < columnIndex) { values.push(''); }
      const typeMatch: RegExpMatchArray | null = attributes.match(new RegExp('\\bt=["\']([^"\']+)["\']', 'i'));
      const type: string = typeMatch === null ? '' : typeMatch[1];
      let value: string = firstXmlValue(body, 'v');
      if (type === 's') {
        const index: number = Number.parseInt(value, 10);
        value = Number.isFinite(index) && index >= 0 && index < sharedStrings.length ? sharedStrings[index] : value;
      } else if (type === 'inlineStr') {
        value = agentMarkupToPlainText(body);
      }
      values.push(normalizeAgentDocumentText(value));
      cellMatch = cellPattern.exec(rowMatch[1]);
    }
    if (values.length > 0) { outputRows.push(values.join('\t')); }
    rowMatch = rowPattern.exec(content);
  }
  return normalizeAgentDocumentText(outputRows.join('\n'));
}

/** RTF 只保留可见文本；嵌入对象和控制字不会进入 Agent 上下文。 */
export function extractAgentRtfText(content: string): string {
  let text: string = content
    .replace(new RegExp('\\\\(?:fonttbl|colortbl|stylesheet|info|pict|object)\\b[\\s\\S]*?\\}', 'gi'), '')
    .replace(new RegExp("\\\\'[0-9a-fA-F]{2}", 'g'), ' ')
    .replace(new RegExp('\\\\(?:par|line)\\b', 'g'), '\n')
    .replace(new RegExp('\\\\tab\\b', 'g'), '\t');
  text = text.replace(new RegExp('\\\\u(-?[0-9]+)\\??', 'g'),
    (original: string, value: string): string => {
      let code: number = Number.parseInt(value, 10);
      if (!Number.isFinite(code)) { return original; }
      if (code < 0) { code += 65536; }
      return String.fromCharCode(code);
    });
  text = text
    .replace(new RegExp('\\\\[a-zA-Z]+-?[0-9]* ?', 'g'), '')
    .replace(new RegExp('\\\\([\\\\{}])', 'g'), '$1')
    .replace(new RegExp('[{}]', 'g'), '');
  return normalizeAgentDocumentText(text);
}
