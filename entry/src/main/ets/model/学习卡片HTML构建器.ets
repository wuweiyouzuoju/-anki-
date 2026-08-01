// SPDX-License-Identifier: AGPL-3.0-or-later

import type { RenderedCard, TemplateNode } from '../proto/messages/CardRenderingMessages';

export const 媒体基地址: string = 'https://jidecards-media.local/';

export type 卡片正反面 = 'question' | 'answer';

const 基础样式: string = `
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
#typeans { white-space: pre-wrap; font-family: monospace; display: inline-block; text-align: left; }
.typeGood { color: #0a7d20; }
.typeBad { color: #c62828; }
.typeMissed { color: #888; }
#typearrow { color: #888; }
`;

export function 重写媒体地址(html: string): string {
  return html
    .replace(/(src\s*=\s*")([^":/][^":]*)"/g, (_匹配: string, 前缀: string, 文件名: string): string => {
      return `${前缀}${媒体基地址}${encodeURIComponent(文件名)}"`;
    })
    .replace(/(href\s*=\s*")([^":/][^":]*)"/g, (_匹配: string, 前缀: string, 文件名: string): string => {
      if (文件名.startsWith('#')) {
        return `${前缀}${文件名}"`;
      }
      return `${前缀}${媒体基地址}${encodeURIComponent(文件名)}"`;
    });
}

function 节点流转HTML(节点列表: TemplateNode[]): string {
  const 片段: string[] = [];
  for (const 节点 of 节点列表) {
    if (节点.text !== null) {
      片段.push(节点.text);
    } else if (节点.replacement !== null) {
      片段.push(节点.replacement.currentText);
    }
  }
  return 片段.join('');
}

export function 原始侧HTML(渲染结果: RenderedCard, 侧面: 卡片正反面): string {
  const 节点列表: TemplateNode[] = 侧面 === 'question' ? 渲染结果.questionNodes : 渲染结果.answerNodes;
  return 节点流转HTML(节点列表);
}

function 剥除音频标签(html: string): string {
  return html.replace(/\[sound:([^\]]+)\]/g, '<span class="sound-flag">♪</span>');
}

const 图片遮罩渲染样式: string = `
#image-occlusion-container {
  position: relative;
  display: inline-block;
  max-width: 100%;
}
#image-occlusion-container img {
  display: block;
  max-width: 100%;
  height: auto;
}
#image-occlusion-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}
`;

const 图片遮罩渲染脚本: string = `<script>
(function () {
  window.anki = window.anki || {};
  if (window.anki.imageOcclusion) { return; }
  var hidden = true;
  function drawRects(ctx, canvas, selector, fill, drawAll) {
    var nodes = document.querySelectorAll(selector);
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.tagName !== 'DIV') { continue; }
      if (node.dataset.shape !== 'rect') { continue; }
      var left = parseFloat(node.dataset.left);
      var top = parseFloat(node.dataset.top);
      var width = parseFloat(node.dataset.width);
      var height = parseFloat(node.dataset.height);
      if (!isFinite(left) || !isFinite(top) || !isFinite(width) || !isFinite(height)) { continue; }
      if (width <= 0 || height <= 0) { continue; }
      if (!drawAll && node.dataset.occludeinactive !== '1') { continue; }
      ctx.fillStyle = fill;
      ctx.fillRect(
        Math.round(left * canvas.width),
        Math.round(top * canvas.height),
        Math.round(width * canvas.width),
        Math.round(height * canvas.height)
      );
    }
  }
  function redraw() {
    var canvas = document.querySelector('#image-occlusion-canvas');
    var img = document.querySelector('#image-occlusion-container img');
    if (!canvas || !img || !img.complete || !img.naturalWidth) { return; }
    var w = img.naturalWidth, h = img.naturalHeight;
    canvas.width = w;
    canvas.height = h;
    var ctx = canvas.getContext('2d');
    if (!ctx) { return; }
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    var clozeFill = hidden ? '#ff8e8e' : 'rgba(255,142,142,0)';
    drawRects(ctx, canvas, '.cloze', clozeFill, true);
    drawRects(ctx, canvas, '.cloze-inactive', '#ffeba2', false);
    drawRects(ctx, canvas, '.cloze-highlight', 'rgba(255,142,142,0)', true);
  }
  window.anki.imageOcclusion = {
    setup: function () {
      var canvas = document.querySelector('#image-occlusion-canvas');
      if (!canvas) { return; }
      var img = document.querySelector('#image-occlusion-container img');
      if (!img) {
        var err = document.getElementById('err');
        if (err) { err.innerHTML = 'No image to show'; }
        return;
      }
      if (img.complete && img.naturalWidth) {
        redraw();
      } else {
        img.addEventListener('load', redraw);
        img.addEventListener('error', redraw);
      }
      var btn = document.getElementById('toggle');
      if (btn) {
        btn.style.display = 'none';
      }
    },
    toggle: function () {
      hidden = !hidden;
      redraw();
    }
  };
})();
</script>`;

export function 构建卡片HTML(渲染结果: RenderedCard, 侧面: 卡片正反面): string {
  const 正文: string = 剥除音频标签(重写媒体地址(原始侧HTML(渲染结果, 侧面)));
  const 样式: string = `${渲染结果.css}\n${基础样式}\n${图片遮罩渲染样式}`;
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>${样式}</style>
${图片遮罩渲染脚本}
</head>
<body class="card">${正文}</body>
</html>`;
}

export interface 拼写标记 {
  fieldName: string;
  combining: boolean;
  cloze: boolean;
}

export function 提取拼写标记(节点列表: TemplateNode[]): 拼写标记 | null {
  const 正则 = /\[\[type:([a-zA-Z0-9_]+)(?::([a-zA-Z0-9_]+))?\]\]/;
  for (const 节点 of 节点列表) {
    if (节点.replacement !== null) {
      const 匹配: RegExpMatchArray | null = 节点.replacement.currentText.match(正则);
      if (匹配 !== null) {
        const 模式: string = 匹配[1];
        const 第二段: string | undefined = 匹配[2];
        if (模式 === 'nc') {
          const 结果: 拼写标记 = { fieldName: 第二段 ?? '', combining: false, cloze: false };
          return 结果;
        }
        if (模式 === 'cloze') {
          const 结果: 拼写标记 = { fieldName: 第二段 ?? '', combining: true, cloze: true };
          return 结果;
        }
        const 结果: 拼写标记 = { fieldName: 模式, combining: true, cloze: false };
        return 结果;
      }
    }
  }
  return null;
}

export function 剥除拼写标记(html: string): string {
  return html.replace(/\[\[type:[^\]]+\]\]/g, '');
}

export function 注入拼写结果(html: string, 结果HTML: string): string {
  return html.replace(/\[\[type:[^\]]+\]\]/, 结果HTML);
}
