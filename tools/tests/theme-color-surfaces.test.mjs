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

test('light selected background is desaturated yet contrast compliant', () => {
  const hsvSaturation = (hex) => {
    const s = hex.replace('#', '');
    const r = parseInt(s.slice(0, 2), 16) / 255;
    const g = parseInt(s.slice(2, 4), 16) / 255;
    const b = parseInt(s.slice(4, 6), 16) / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    return max === 0 ? 0 : ((max - min) / max) * 100;
  };

  for (const 主题 of 有色主题) {
    const 色板 = 解析主题色板(主题, false);
    // 华为 2.1.4.2：可交互控件活动状态背板 vs 卡片底（白）≥2.2:1 必须保住
    assert.ok(对比度(色板.选中背景, '#FFFFFF') >= 2.2, `${主题} selected contrast ${色板.选中背景}`);
    // 用户反馈修复：选中行不得再出现高饱和大色块（旧值 forest S84 / sunset S100）
    assert.ok(hsvSaturation(色板.选中背景) <= 42, `${主题} selected saturation ${色板.选中背景}`);
    // 选中背景必须比 主色容器 更柔和或相等（软化只降饱和/明度，不放大）
    assert.ok(hsvSaturation(色板.选中背景) <= hsvSaturation(色板.主色容器) + 2, 主题);
  }

  // 明确回归锚点：两个曾被投诉主题的软化结果
  assert.equal(解析主题色板('forest', false).选中背景, '#74bc83');
  assert.equal(解析主题色板('sunset', false).选中背景, '#cca47e');
});
