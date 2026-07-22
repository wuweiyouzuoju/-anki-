// SPDX-License-Identifier: AGPL-3.0-or-later

/**
 * 浮动工具栏尺寸常量：把原 StudyFloatingToolbar 中散落在 struct 内的 13 个尺寸集中导出。
 * 分两类：
 *   1. 横版尺寸（H 后缀，拖动中布局）：main 4 评分按钮横向；aux 2 按钮横向。
 *   2. 竖版尺寸（V 后缀，吸附态）：按钮纵向排列，像侧边栏贴边。
 * main question 阶段只有「显示答案」一个按钮，高度小；answer 阶段 4 个评分按钮纵向，高度大。
 * 竖版高度加长，按钮内文字允许跨行（maxLines=2）。
 */

/** 横版尺寸（拖动中）。 */
export const MAIN_WIDTH_H: number = 300;
export const MAIN_HEIGHT_H: number = 116;
export const AUX_WIDTH_H: number = 176;
export const AUX_HEIGHT_H: number = 52;

/** 竖版尺寸（吸附态）。 */
export const MAIN_WIDTH_V: number = 96;
export const MAIN_HEIGHT_V_QUESTION: number = 80;
export const MAIN_HEIGHT_V_ANSWER: number = 360;
export const AUX_WIDTH_V: number = 96;
export const AUX_HEIGHT_V: number = 176;

/** 屏幕边缘留白（vp）：吸附后不贴边，方便手指抓取。侧边与底部统一此值。 */
export const EDGE_MARGIN: number = 12;

/** 顶部预留（vp）：避开顶栏（TOOLBAR_HEIGHT + STATUS_BAR 估计值）。 */
export const TOP_RESERVED: number = 80;

/** 底部预留（vp）：与侧边统一为 12，不再额外避开手势条（HarmonyOS 手势条高度约 24vp，
 *  若真机反馈手势条遮挡工具栏再调大）。 */
export const BOTTOM_RESERVED: number = 12;

/** 工具栏类型：main=主操作；aux=辅助操作（埋藏+暂停）。 */
export type ToolbarId = 'main' | 'aux';

/** 吸附侧别：left/right 为竖版贴侧边；top/bottom 为横版贴顶/底。 */
export type SnapSide = 'left' | 'right' | 'top' | 'bottom';

/**
 * 计算工具栏当前宽度。
 * @param id      工具栏类型
 * @param snapped 是否吸附态（true=竖版，false=横版）
 */
export function toolbarWidth(id: ToolbarId, snapped: boolean): number {
  if (snapped) {
    return id === 'main' ? MAIN_WIDTH_V : AUX_WIDTH_V;
  }
  return id === 'main' ? MAIN_WIDTH_H : AUX_WIDTH_H;
}

/**
 * 计算工具栏当前高度。
 * @param id      工具栏类型
 * @param snapped 是否吸附态
 * @param phase   学习阶段（仅 main 在竖版时区分 question/answer）
 */
export function toolbarHeight(
  id: ToolbarId,
  snapped: boolean,
  phase: 'loading' | 'question' | 'answer' | 'done' | 'error'
): number {
  if (snapped) {
    if (id === 'main') {
      return phase === 'question' ? MAIN_HEIGHT_V_QUESTION : MAIN_HEIGHT_V_ANSWER;
    }
    return AUX_HEIGHT_V;
  }
  return id === 'main' ? MAIN_HEIGHT_H : AUX_HEIGHT_H;
}
