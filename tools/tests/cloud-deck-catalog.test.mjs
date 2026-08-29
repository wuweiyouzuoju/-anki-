import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { 解析云端牌组目录 } from '../../entry/src/main/ets/model/云端牌组模型.ts';

const 目录路径 = new URL('../../hosting/cloud-decks.json', import.meta.url);

test('此次云端牌组引导版本固定为 2.3.3', async () => {
  const 应用配置 = await readFile(new URL('../../AppScope/app.json5', import.meta.url), 'utf8');
  assert.match(应用配置, /versionCode:\s*2303/);
  assert.match(应用配置, /versionName:\s*'2\.3\.3'/);
});

test('托管目录提供六个带准确卡片数量的公开牌组', async () => {
  const 目录文本 = await readFile(目录路径, 'utf8');
  const 目录 = 解析云端牌组目录(目录文本);

  assert.equal(目录.schemaVersion, 1);
  assert.deepEqual(
    目录.decks.map(({ id, name, size, cardCount, accessType }) => ({ id, name, size, cardCount, accessType })),
    [
      { id: 'cet-46-vocabulary', name: 'CET四六级词汇', size: 362721820, cardCount: 14311, accessType: 'public' },
      { id: 'high-school-english-vocabulary', name: '高考英语词汇', size: 184166749, cardCount: 8453, accessType: 'public' },
      { id: 'middle-school-english-vocabulary', name: '中考英语词汇', size: 89582440, cardCount: 3305, accessType: 'public' },
      { id: 'ai-machine-learning', name: 'AI机器学习', size: 13955271, cardCount: 1450, accessType: 'public' },
      { id: 'ai-computer-terms', name: 'AI计算机专业工具名词术语', size: 473723, cardCount: 2190, accessType: 'public' },
      { id: 'china-law-professional', name: '中国法律专业版', size: 1351898, cardCount: 2500, accessType: 'public' },
    ],
  );

  for (const 牌组 of 目录.decks) {
    const 下载地址 = new URL(牌组.downloadUrl);
    assert.equal(下载地址.protocol, 'https:');
    assert.equal(下载地址.hostname, '4001784660.cdn.123clouddisk.com');
    assert.match(decodeURIComponent(下载地址.pathname), /\.apkg$/);
  }
});
