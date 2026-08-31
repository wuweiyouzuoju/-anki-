// SPDX-License-Identifier: AGPL-3.0-or-later

const MAX_CONTEXT_FIELD_LENGTH: number = 12000;

/**
 * 文本 Agent 适配器不伪装已发送媒体。保留可理解的占位符，但移除内联数据、HTML
 * 媒体标签和 Anki 声音引用，避免把无法处理的二进制内容意外送给纯文本模型。
 */
export function sanitizeAgentContextField(value: string): string {
  return value
    .replace(/data:[^\s"')>]+/gi, '[inline media omitted]')
    .replace(/<img\b[^>]*>/gi, '[image omitted]')
    .replace(/<(?:audio|video)\b[^>]*>[\s\S]*?<\/(?:audio|video)>/gi, '[media omitted]')
    .replace(/<(?:audio|video)\b[^>]*\/?>/gi, '[media omitted]')
    .replace(/\[sound:[^\]]+\]/gi, '[audio omitted]')
    .slice(0, MAX_CONTEXT_FIELD_LENGTH);
}

export function agentContextFieldHasOmittedMedia(value: string): boolean {
  return sanitizeAgentContextField(value) !== value.slice(0, MAX_CONTEXT_FIELD_LENGTH) ||
    value.length > MAX_CONTEXT_FIELD_LENGTH;
}
