// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import { 解析主题色板 } from '../../entry/src/main/ets/model/颜色主题.ets';
import { 对比度 } from '../../entry/src/main/ets/model/色阶生成.ets';

const 深色卡片底色 = '#18202B';
const 有色主题 = ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon'];
const 深色页面期望 = ['#121823', '#101a1e', '#141723', '#111b22', '#17191d', '#171b1e'];

test('colored dark themes use restrained accessible surfaces', () => {
  for (let i = 0; i < 有色主题.length; i++) {
    const 色板 = 解析主题色板(有色主题[i], true);
    const 容器对比度 = 对比度(色板.主色容器, 深色卡片底色);
    const 悬停对比度 = 对比度(色板.主色容器悬停, 深色卡片底色);

    assert.equal(色板.页面底色微染, 深色页面期望[i], 有色主题[i]);
    assert.ok(容器对比度 >= 2.2 && 容器对比度 < 2.35, `${有色主题[i]} container ${容器对比度}`);
    assert.ok(悬停对比度 >= 2.8 && 悬停对比度 < 3.0, `${有色主题[i]} hover ${悬停对比度}`);
    assert.ok(悬停对比度 > 容器对比度, 有色主题[i]);
  }
});

test('minimal gray keeps its accessible containers with a restrained page tint', () => {
  const 色板 = 解析主题色板('minimal_gray', true);

  assert.equal(色板.页面底色微染, '#151a22');
  assert.equal(色板.主色容器, '#555555');
  assert.equal(色板.主色容器悬停, '#666666');
  assert.ok(对比度(色板.主色容器, 深色卡片底色) >= 2.2);
});

test('light theme surface outputs remain unchanged', () => {
  assert.deepEqual(
    ['aurora', 'forest', 'midnight', 'lagoon', 'sunset', 'lemon', 'minimal_gray']
      .map((主题) => {
        const 色板 = 解析主题色板(主题, false);
        return [色板.页面底色微染, 色板.主色容器, 色板.主色容器悬停];
      }),
    [
      ['#e9eef7', '#7fa6ea', '#5582dd'],
      ['#e6f3ee', '#1fc13f', '#00B42A'],
      ['#edebf8', '#b37feb', '#9254de'],
      ['#e7f4f7', '#089ea3', '#00747d'],
      ['#f6f0eb', '#FF7D00', '#d96300'],
      ['#f5f3ed', '#d1940f', '#ab7004'],
      ['#ebedef', '#A6A6A6', '#B0B0B0']
    ]
  );
});
