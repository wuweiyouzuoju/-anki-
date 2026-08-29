import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { 解析云端牌组目录 } from '../../entry/src/main/ets/model/云端牌组模型.ts';

const 目录路径 = new URL('../../hosting/cloud-decks.json', import.meta.url);

test('托管目录提供五个可独立下载的公开牌组', async () => {
  const 目录文本 = await readFile(目录路径, 'utf8');
  const 目录 = 解析云端牌组目录(目录文本);

  assert.equal(目录.schemaVersion, 1);
  assert.deepEqual(
    目录.decks.map(({ id, name, size, accessType }) => ({ id, name, size, accessType })),
    [
      { id: 'cet-46-vocabulary', name: 'CET四六级词汇', size: 362721820, accessType: 'public' },
      { id: 'middle-school-english-vocabulary', name: '中考英语词汇', size: 89582440, accessType: 'public' },
      { id: 'ai-machine-learning', name: 'AI机器学习', size: 13955271, accessType: 'public' },
      { id: 'ai-computer-terms', name: 'AI计算机专业工具名词术语', size: 473723, accessType: 'public' },
      { id: 'china-law-professional', name: '中国法律专业版', size: 1351898, accessType: 'public' },
    ],
  );

  for (const 牌组 of 目录.decks) {
    const 下载地址 = new URL(牌组.downloadUrl);
    assert.equal(下载地址.protocol, 'https:');
    assert.equal(下载地址.hostname, '4001784660.cdn.123clouddisk.com');
    assert.match(decodeURIComponent(下载地址.pathname), /\.apkg$/);
  }
});
