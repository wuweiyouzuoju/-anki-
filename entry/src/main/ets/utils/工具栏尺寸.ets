// SPDX-License-Identifier: AGPL-3.0-or-later

export const 主工具栏_横版_宽度: number = 300;
export const 主工具栏_横版_高度: number = 116;
export const 辅助工具栏_横版_宽度: number = 176;
export const 辅助工具栏_横版_高度: number = 52;

export const 主工具栏_竖版_宽度: number = 96;
export const 主工具栏_竖版_高度_问题阶段: number = 80;
export const 主工具栏_竖版_高度_答案阶段: number = 360;
export const 辅助工具栏_竖版_宽度: number = 96;
export const 辅助工具栏_竖版_高度: number = 176;

export const 边缘留白: number = 12;

export const 顶部预留: number = 80;

export const 底部预留: number = 12;

export type 工具栏标识 = 'main' | 'aux';

export type 吸附侧 = 'left' | 'right' | 'top' | 'bottom';

export function 工具栏宽度(工具栏类型: 工具栏标识, 是否吸附态: boolean): number {
  if (是否吸附态) {
    return 工具栏类型 === 'main' ? 主工具栏_竖版_宽度 : 辅助工具栏_竖版_宽度;
  }
  return 工具栏类型 === 'main' ? 主工具栏_横版_宽度 : 辅助工具栏_横版_宽度;
}

export function 工具栏高度(
  工具栏类型: 工具栏标识,
  是否吸附态: boolean,
  学习阶段: 'loading' | 'question' | 'answer' | 'done' | 'error'
): number {
  if (是否吸附态) {
    if (工具栏类型 === 'main') {
      return 学习阶段 === 'question' ? 主工具栏_竖版_高度_问题阶段 : 主工具栏_竖版_高度_答案阶段;
    }
    return 辅助工具栏_竖版_高度;
  }
  return 工具栏类型 === 'main' ? 主工具栏_横版_高度 : 辅助工具栏_横版_高度;
}
