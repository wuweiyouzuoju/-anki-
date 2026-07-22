// StudyCardHtmlBuilder：渲染节点流 → 学习页 HTML 的纯函数积木（M7）。
// 不依赖后端/Web 组件，可独立单元测试。
//
// 媒体路径策略：Anki 卡片 HTML 中媒体以相对文件名引用（<img src="foo.png">）。
// ArkWeb 对 file/resource 协议跨域请求一律拦截（官方文档：本地资源跨域），
// 因此把相对文件名重写为自建 https 域名 MEDIA_BASE_URL，由 StudyPage 的
// onInterceptRequest 拦截并映射到沙箱 collection.media/ 目录。
// 依据：developer.huawei.com ArkWeb「本地资源跨域」章节 + 社区示例。

import type { RenderedCard, TemplateNode } from '../proto/messages/CardRenderingMessages';

/** 自建媒体域名（onInterceptRequest 拦截锚点），不与真实域名冲突 */
export const MEDIA_BASE_URL: string = 'https://jidecards-media.local/';

const BASE_CSS: string = `
body {
  margin: 0;
  padding: 20px 16px;
  font-family: sans-serif;
  font-size: 17px;
  line-height: 1.6;
  color: #1A1A1A;
  background: transparent;
  text-align: center;
  word-wrap: break-word;
}
img { max-width: 100%; height: auto; }
a { color: #2E6BE6; }
hr { opacity: 0.3; }
.sound-flag { color: #2E6BE6; font-size: 0.75em; }
.nightMode body, body.nightMode { color: #E6E6E6; }
`;

/** 把卡片正文中的相对媒体文件名重写为 MEDIA_BASE_URL 绝对地址 */
export function rewriteMediaUrls(html: string): string {
  return html
    .replace(/(src\s*=\s*")([^":/][^":]*)"/g, (_match: string, prefix: string, fileName: string): string => {
      return `${prefix}${MEDIA_BASE_URL}${encodeURIComponent(fileName)}"`;
    })
    .replace(/(href\s*=\s*")([^":/][^":]*)"/g, (_match: string, prefix: string, fileName: string): string => {
      if (fileName.startsWith('#')) {
        return `${prefix}${fileName}"`;
      }
      return `${prefix}${MEDIA_BASE_URL}${encodeURIComponent(fileName)}"`;
    });
}

/** 节点流 → HTML 片段：text 节点为模板原文，replacement 节点为后端已渲染的字段 HTML */
function nodesToHtml(nodes: TemplateNode[]): string {
  const parts: string[] = [];
  for (const node of nodes) {
    if (node.text !== null) {
      parts.push(node.text);
    } else if (node.replacement !== null) {
      parts.push(node.replacement.currentText);
    }
  }
  return parts.join('');
}

/** 一侧卡片的原始字段 HTML（未剥标签、未重写地址），供后端 ExtractAvTags 提取音频 */
export function rawSideHtml(rendered: RenderedCard, side: 'question' | 'answer'): string {
  const nodes: TemplateNode[] = side === 'question' ? rendered.questionNodes : rendered.answerNodes;
  return nodesToHtml(nodes);
}

/** 剥除 Anki [sound:xxx] 标签，原位留小标记示意有音频；播放由原生 SoundPlayer 负责 */
function stripSoundTags(html: string): string {
  return html.replace(/\[sound:([^\]]+)\]/g, '<span class="sound-flag">♪</span>');
}

/**
 * 组装学习页完整 HTML 文档。
 * side='question' 取正面节点流，'answer' 取背面节点流；
 * 背面节点流在 Anki 模板中通常已包含正面（{{FrontSide}}），直接渲染即可。
 * 模板 CSS（rendered.css）在前，基础兜底 CSS 在后做最低可读保障。
 * 字段中的 [sound:xxx] 标签剥除为小标记，音频由原生 SoundPlayer 播放（真机 Web 自动播放无声）。
 */
export function buildCardHtml(rendered: RenderedCard, side: 'question' | 'answer'): string {
  const body: string = stripSoundTags(rewriteMediaUrls(rawSideHtml(rendered, side)));
  const css: string = `${rendered.css}\n${BASE_CSS}`;
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>${css}</style>
</head>
<body class="card">${body}</body>
</html>`;
}
