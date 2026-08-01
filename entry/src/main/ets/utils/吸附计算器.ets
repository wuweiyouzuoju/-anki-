// SPDX-License-Identifier: AGPL-3.0-or-later

import {
  边缘留白,
  底部预留,
  顶部预留,
  工具栏宽度,
  工具栏高度,
  工具栏标识,
  吸附侧
} from './工具栏尺寸';

export type 学习阶段 = 'loading' | 'question' | 'answer' | 'done' | 'error';

export interface 吸附结果 {
  x: number;
  y: number;
  吸附侧: 吸附侧;
  是否吸附: boolean;
}

export interface 推断吸附侧结果 {
  吸附侧: 吸附侧;
  是否吸附: boolean;
}

export function 夹紧X方向(x: number, 屏幕宽: number, 工具栏类型: 工具栏标识, 是否吸附态: boolean): number {
  const 最小: number = 边缘留白;
  const 最大: number = Math.max(最小, 屏幕宽 - 工具栏宽度(工具栏类型, 是否吸附态) - 边缘留白);
  if (x < 最小) {
    return 最小;
  }
  if (x > 最大) {
    return 最大;
  }
  return x;
}

export function 夹紧Y方向(
  y: number,
  屏幕高: number,
  工具栏类型: 工具栏标识,
  是否吸附态: boolean,
  学习阶段: 学习阶段
): number {
  const 最小: number = 顶部预留;
  const 最大: number = Math.max(最小, 屏幕高 - 工具栏高度(工具栏类型, 是否吸附态, 学习阶段) - 底部预留);
  if (y < 最小) {
    return 最小;
  }
  if (y > 最大) {
    return 最大;
  }
  return y;
}

export function 吸附到侧边(
  当前X: number,
  当前Y: number,
  屏幕宽: number,
  屏幕高: number,
  工具栏类型: 工具栏标识,
  学习阶段: 学习阶段
): 吸附结果 {
  const 当前宽: number = 工具栏宽度(工具栏类型, true);
  const 当前高: number = 工具栏高度(工具栏类型, true, 学习阶段);
  const 中心X: number = 当前X + 当前宽 / 2;
  const 中心Y: number = 当前Y + 当前高 / 2;
  const 距左: number = 中心X;
  const 距右: number = 屏幕宽 - 中心X;
  const 距顶: number = 中心Y - 顶部预留;
  const 距底: number = 屏幕高 - 底部预留 - 中心Y;
  const 最小距: number = Math.min(距左, 距右, 距顶, 距底);

  let 吸附侧结果: 吸附侧;
  let 是否吸附: boolean;
  if (最小距 === 距左) {
    吸附侧结果 = 'left';
    是否吸附 = true;
  } else if (最小距 === 距右) {
    吸附侧结果 = 'right';
    是否吸附 = true;
  } else if (最小距 === 距顶) {
    吸附侧结果 = 'top';
    是否吸附 = false;
  } else {
    吸附侧结果 = 'bottom';
    是否吸附 = false;
  }

  const 最终宽: number = 工具栏宽度(工具栏类型, 是否吸附);
  const 最终高: number = 工具栏高度(工具栏类型, 是否吸附, 学习阶段);
  let 吸附后X: number;
  let 吸附后Y: number;
  if (吸附侧结果 === 'left') {
    吸附后X = 边缘留白;
    吸附后Y = 夹紧Y方向(当前Y, 屏幕高, 工具栏类型, 是否吸附, 学习阶段);
  } else if (吸附侧结果 === 'right') {
    吸附后X = Math.max(边缘留白, 屏幕宽 - 最终宽 - 边缘留白);
    吸附后Y = 夹紧Y方向(当前Y, 屏幕高, 工具栏类型, 是否吸附, 学习阶段);
  } else if (吸附侧结果 === 'top') {
    吸附后X = 夹紧X方向(当前X, 屏幕宽, 工具栏类型, 是否吸附);
    吸附后Y = 顶部预留;
  } else {
    吸附后X = 夹紧X方向(当前X, 屏幕宽, 工具栏类型, 是否吸附);
    吸附后Y = Math.max(顶部预留, 屏幕高 - 最终高 - 底部预留);
  }
  const 结果: 吸附结果 = { x: 吸附后X, y: 吸附后Y, 吸附侧: 吸附侧结果, 是否吸附 };
  return 结果;
}

export function 推断吸附侧(
  当前X: number,
  当前Y: number,
  屏幕宽: number,
  屏幕高: number,
  工具栏类型: 工具栏标识,
  学习阶段: 学习阶段
): 推断吸附侧结果 {
  const 宽: number = 工具栏宽度(工具栏类型, true);
  const 高: number = 工具栏高度(工具栏类型, true, 学习阶段);
  const 中心X: number = 当前X + 宽 / 2;
  const 中心Y: number = 当前Y + 高 / 2;
  const 距左: number = 中心X;
  const 距右: number = 屏幕宽 - 中心X;
  const 距顶: number = 中心Y - 顶部预留;
  const 距底: number = 屏幕高 - 底部预留 - 中心Y;
  const 最小距: number = Math.min(距左, 距右, 距顶, 距底);
  if (最小距 === 距左) {
    const 结果: 推断吸附侧结果 = { 吸附侧: 'left', 是否吸附: true };
    return 结果;
  }
  if (最小距 === 距右) {
    const 结果: 推断吸附侧结果 = { 吸附侧: 'right', 是否吸附: true };
    return 结果;
  }
  if (最小距 === 距顶) {
    const 结果: 推断吸附侧结果 = { 吸附侧: 'top', 是否吸附: false };
    return 结果;
  }
  const 结果: 推断吸附侧结果 = { 吸附侧: 'bottom', 是否吸附: false };
  return 结果;
}
