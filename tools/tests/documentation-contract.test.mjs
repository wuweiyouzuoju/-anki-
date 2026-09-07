// SPDX-License-Identifier: AGPL-3.0-or-later
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), 'utf8');
}

function markdownFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return markdownFiles(absolute);
    }
    return entry.name.endsWith('.md') ? [absolute] : [];
  });
}

test('current documentation follows application and SDK configuration', () => {
  const app = read('AppScope/app.json5');
  const buildProfile = read('build-profile.json5');
  const readme = read('README.md');
  const status = read('docs/DEVELOPMENT_PLAN.md');

  const versionName = app.match(/versionName:\s*'([^']+)'/)?.[1];
  const versionCode = app.match(/versionCode:\s*(\d+)/)?.[1];
  const compatibleApi = buildProfile.match(/compatibleSdkVersion:\s*'[^']+\((\d+)\)'/)?.[1];
  const targetApi = buildProfile.match(/targetSdkVersion:\s*'[^']+\((\d+)\)'/)?.[1];

  assert.ok(versionName);
  assert.ok(versionCode);
  assert.ok(compatibleApi);
  assert.ok(targetApi);
  assert.match(readme, new RegExp(`当前源码版本：${versionName.replaceAll('.', '\\.')}`));
  assert.match(status, new RegExp(`应用版本 \\| ${versionName.replaceAll('.', '\\.')} / versionCode ${versionCode}`));
  assert.match(status, new RegExp(`最低兼容 SDK \\| HarmonyOS [^|]+（API ${compatibleApi}）`));
  assert.match(status, new RegExp(`目标 SDK \\| HarmonyOS [^|]+（API ${targetApi}）`));
  assert.doesNotMatch(status, /当前实施记录|最低系统版本 \| HarmonyOS 5\.0\.0（API 12）/);
});

test('active Markdown uses valid relative links', () => {
  const activeFiles = [
    'README.md',
    'NOTICE.md',
    'docs/README.md',
    'docs/DEVELOPMENT_PLAN.md',
    'docs/architecture.md',
    'docs/agent-2-design.md',
    'docs/cloud-deck-hosting.md',
    'docs/official-announcement-hosting.md',
    'docs/releases/3.0.0.md',
    'docs/superpowers/README.md',
  ];
  const broken = [];

  for (const relativeFile of activeFiles) {
    const source = read(relativeFile);
    for (const match of source.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
      const link = match[1];
      if (/^(?:https?:|mailto:|#)/.test(link)) {
        continue;
      }
      const pathPart = decodeURIComponent(link.split('#')[0]);
      if (!pathPart) {
        continue;
      }
      const target = path.resolve(root, path.dirname(relativeFile), pathPart);
      if (!existsSync(target)) {
        broken.push(`${relativeFile} -> ${link}`);
      }
    }
  }

  assert.deepEqual(broken, []);
});

test('historical plans and specs are visibly archived', () => {
  const archiveRoot = path.join(root, 'docs', 'superpowers');
  const records = markdownFiles(archiveRoot)
    .filter((file) => path.basename(file) !== 'README.md');

  assert.ok(records.length > 0);
  for (const record of records) {
    assert.match(readFileSync(record, 'utf8'), /> 归档状态：这是一次性历史设计\/执行记录/,
      path.relative(root, record));
  }
  assert.match(read('docs/releases/3.0.0.md'), /草案（未发布）/);
});
