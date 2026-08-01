// SPDX-License-Identifier: AGPL-3.0-or-later

import assert from 'node:assert/strict';
import test from 'node:test';
import {
  生成Occlusions字符串,
  编号颜色
} from '../../entry/src/main/ets/model/图片遮罩模型.ts';

test('生成Occlusions字符串_单个c1矩形', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0.2, 顶: 0.3, 宽: 0.4, 高: 0.1, 编号: 1 }
  ];
  assert.equal(
    生成Occlusions字符串(输入),
    '{{c1::image-occlusion:rect:left=0.2:top=0.3:width=0.4:height=0.1}}'
  );
});

test('生成Occlusions字符串_三个不同ordinal矩形', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0.1, 顶: 0.1, 宽: 0.2, 高: 0.2, 编号: 1 },
    { 形状: 'rect', 左: 0.3, 顶: 0.3, 宽: 0.2, 高: 0.2, 编号: 2 },
    { 形状: 'rect', 左: 0.5, 顶: 0.5, 宽: 0.2, 高: 0.2, 编号: 3 }
  ];
  const 期望 =
    '{{c1::image-occlusion:rect:left=0.1:top=0.1:width=0.2:height=0.2}}' +
    '{{c2::image-occlusion:rect:left=0.3:top=0.3:width=0.2:height=0.2}}' +
    '{{c3::image-occlusion:rect:left=0.5:top=0.5:width=0.2:height=0.2}}';
  assert.equal(生成Occlusions字符串(输入), 期望);
});

test('生成Occlusions字符串_整图遮罩边界值', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0, 顶: 0, 宽: 1, 高: 1, 编号: 1 }
  ];
  assert.equal(
    生成Occlusions字符串(输入),
    '{{c1::image-occlusion:rect:left=0:top=0:width=1:height=1}}'
  );
});

test('生成Occlusions字符串_编号越界按c6输出', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0.1, 顶: 0.1, 宽: 0.1, 高: 0.1, 编号: 6 }
  ];
  assert.equal(
    生成Occlusions字符串(输入),
    '{{c6::image-occlusion:rect:left=0.1:top=0.1:width=0.1:height=0.1}}'
  );
});

test('生成Occlusions字符串_空列表返回空字符串', () => {
  assert.equal(生成Occlusions字符串([]), '');
});

test('生成Occlusions字符串_浮点尾数四舍五入到4位', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0.123456, 顶: 0.987654, 宽: 0.555555, 高: 0.0001, 编号: 1 }
  ];
  assert.equal(
    生成Occlusions字符串(输入),
    '{{c1::image-occlusion:rect:left=0.1235:top=0.9877:width=0.5556:height=0.0001}}'
  );
});

test('生成Occlusions字符串_同ordinal多矩形', () => {
  const 输入 = [
    { 形状: 'rect', 左: 0.1, 顶: 0.1, 宽: 0.2, 高: 0.2, 编号: 1 },
    { 形状: 'rect', 左: 0.5, 顶: 0.5, 宽: 0.2, 高: 0.2, 编号: 1 }
  ];
  const 期望 =
    '{{c1::image-occlusion:rect:left=0.1:top=0.1:width=0.2:height=0.2}}' +
    '{{c1::image-occlusion:rect:left=0.5:top=0.5:width=0.2:height=0.2}}';
  assert.equal(生成Occlusions字符串(输入), 期望);
});

test('编号颜色_c1到c5返回固定色', () => {
  assert.equal(编号颜色(1), '#E53935');
  assert.equal(编号颜色(2), '#FB8C00');
  assert.equal(编号颜色(3), '#FDD835');
  assert.equal(编号颜色(4), '#43A047');
  assert.equal(编号颜色(5), '#1E88E5');
});

test('编号颜色_越界返回默认灰', () => {
  assert.equal(编号颜色(0), '#9E9E9E');
  assert.equal(编号颜色(6), '#9E9E9E');
  assert.equal(编号颜色(-1), '#9E9E9E');
});
