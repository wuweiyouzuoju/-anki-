#!/usr/bin/env node
// SPDX-License-Identifier: AGPL-3.0-or-later
// 一键发布脱敏：从带注释开发版生成发布版（脱注释 + 脱辅助文件 + 脱敏签名）
// 用法：node tools/strip-for-release.mjs [输出目录，默认 ../jidecards02]

import { cpSync, rmSync, existsSync, readFileSync, writeFileSync, readdirSync, statSync, renameSync, mkdirSync } from 'node:fs';
import { join, resolve, relative, dirname, sep, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = resolve(__dirname, '..');
const OUT = process.argv[2] ? resolve(process.argv[2]) : resolve(SRC, '..', 'jidecards02');

// 跳过的目录段（匹配任意层级的同名目录/文件）
// 与 .gitignore 对齐：.cxx / .hvigor / .idea / third_party / .trae / .agents 等都不复制
const SKIP_DIRS = new Set([
  '.git', 'node_modules', 'oh_modules', 'build', 'target', '.trae', '.agents',
  '.idea', '.idea.dist', '.ai-index', 'docs', 'skills',
  'hap-check-tmp', '.smoke',
  '.cxx', '.hvigor', 'third_party'
]);
const SKIP_FILES = new Set([
  'AGENTS.md', 'PROJECT_CONTEXT.md', 'strip-for-release.mjs',
  'build_log.txt', 'file'
]);

console.log(`[发布脱敏] 源: ${SRC}`);
console.log(`[发布脱敏] 输出: ${OUT}`);

if (OUT === SRC || OUT.startsWith(SRC + sep)) {
  console.error('[发布脱敏] 错误：输出目录不能在源目录内');
  process.exit(1);
}

// 1. 清空输出目录（保留 OUT/third_party 若已存在——上游 Anki 源码由用户手动 clone，不纳入脱敏流程）
let thirdPartyBackup = null;
const thirdPartyPath = join(OUT, 'third_party');
if (existsSync(thirdPartyPath)) {
  thirdPartyBackup = join(dirname(OUT), `${basename(OUT)}.third_party.bak`);
  if (existsSync(thirdPartyBackup)) rmSync(thirdPartyBackup, { recursive: true, force: true });
  renameSync(thirdPartyPath, thirdPartyBackup);
  console.log(`[发布脱敏] 已暂存 OUT/third_party → ${thirdPartyBackup}`);
}
if (existsSync(OUT)) {
  rmSync(OUT, { recursive: true, force: true });
  console.log('[发布脱敏] 已清空旧输出目录');
}
if (thirdPartyBackup) {
  mkdirSync(OUT, { recursive: true });
  renameSync(thirdPartyBackup, join(OUT, 'third_party'));
  console.log('[发布脱敏] 已恢复 OUT/third_party');
}

// 2. 复制（跳过辅助目录/文件）
cpSync(SRC, OUT, {
  recursive: true,
  filter: (src) => {
    const rel = relative(SRC, src).replace(/\\/g, '/');
    if (rel === '') return true;
    const segments = rel.split('/');
    const last = segments[segments.length - 1];
    if (SKIP_DIRS.has(last)) return false;
    if (SKIP_FILES.has(last)) return false;
    return true;
  }
});
console.log('[发布脱敏] 文件复制完成（已跳过辅助目录/文件）');

// 3. 脱注释（仅 entry/src/main/ets/ 下的 .ets/.ts，不碰 third_party 上游代码）
const stripRoot = join(OUT, 'entry', 'src', 'main', 'ets');
let stripCount = 0;
if (existsSync(stripRoot)) {
  walkDir(stripRoot, (filePath) => {
    if (filePath.endsWith('.ets') || filePath.endsWith('.ts')) {
      const original = readFileSync(filePath, 'utf8');
      const cleaned = stripComments(original);
      if (cleaned !== original) {
        writeFileSync(filePath, cleaned, 'utf8');
        stripCount++;
      }
    }
  });
}
console.log(`[发布脱敏] 脱注释: ${stripCount} 个 .ets/.ts 文件`);

// 4. 脱敏 build-profile.json5（根 + entry 两处）
for (const bp of [join(OUT, 'build-profile.json5'), join(OUT, 'entry', 'build-profile.json5')]) {
  if (existsSync(bp)) {
    let content = readFileSync(bp, 'utf8');
    for (const field of ['certpath', 'keyAlias', 'keyPassword', 'profile', 'storeFile', 'storePassword']) {
      content = content.replace(new RegExp(`"${field}"\\s*:\\s*"[^"]*"`, 'g'), `"${field}": ""`);
    }
    writeFileSync(bp, content, 'utf8');
  }
}
console.log('[发布脱敏] build-profile.json5 签名字段已清空');

console.log('[发布脱敏] === 完成 ===');
console.log('[发布脱敏] 下一步：');
console.log('  1. 在输出目录运行 npm test 验证完整性');
console.log('  2. 在 build-profile.json5 填入发布签名材料');
console.log('  3. 构建 release .hap');

// --- 辅助函数 ---

function walkDir(dir, fn) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) {
      walkDir(p, fn);
    } else {
      fn(p);
    }
  }
}

function stripComments(source) {
  // 保留首行 SPDX 许可证头
  let header = '';
  let body = source;
  if (source.startsWith('// SPDX-License-Identifier')) {
    const nl = source.indexOf('\n');
    if (nl >= 0) {
      header = source.slice(0, nl + 1);
      body = source.slice(nl + 1);
    } else {
      header = source;
      body = '';
    }
  }

  const len = body.length;
  let result = '';
  let i = 0;

  while (i < len) {
    const ch = body[i];
    const next = body[i + 1];

    // 行注释 //（保留三斜杠 /// 指令）
    if (ch === '/' && next === '/') {
      if (body[i + 2] === '/') {
        result += ch;
        i++;
        continue;
      }
      while (i < len && body[i] !== '\n') i++;
      continue;
    }

    // 块注释 /* */
    if (ch === '/' && next === '*') {
      i += 2;
      while (i < len && !(body[i] === '*' && body[i + 1] === '/')) i++;
      i += 2;
      continue;
    }

    // 字符串（单引号/双引号/模板字符串）
    if (ch === '"' || ch === "'" || ch === '`') {
      const quote = ch;
      result += ch; i++;
      while (i < len && body[i] !== quote) {
        if (body[i] === '\\' && i + 1 < len) {
          result += body[i] + body[i + 1];
          i += 2;
        } else {
          result += body[i++];
        }
      }
      if (i < len) result += body[i++];
      continue;
    }

    result += ch;
    i++;
  }

  let output = header + result;
  // 清理行尾空白
  output = output.replace(/[ \t]+$/gm, '');
  // 3+ 连续空行 → 单空行
  output = output.replace(/\n{3,}/g, '\n\n');
  return output;
}
