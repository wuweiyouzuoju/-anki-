// SPDX-License-Identifier: AGPL-3.0-or-later

import {
  EDGE_MARGIN,
  BOTTOM_RESERVED,
  TOP_RESERVED,
  toolbarWidth,
  toolbarHeight,
  ToolbarId,
  SnapSide
} from './ToolbarDimens';

/** 学习阶段（与 StudyFloatingToolbar.StudyPhase 同语义，独立声明避免循环依赖）。 */
export type StudyPhase = 'loading' | 'question' | 'answer' | 'done' | 'error';

/** 吸附计算结果：松手后的位置 + 吸附侧 + 是否为吸附态。 */
export interface SnapResult {
  x: number;
  y: number;
  snapSide: SnapSide;
  snapped: boolean;
}

/** inferSnapSide 返回类型：仅含吸附侧 + 是否吸附，不含坐标。 */
export interface InferSnapSideResult {
  snapSide: SnapSide;
  snapped: boolean;
}

/** X 方向夹紧：保证工具栏不超出左右边界。 */
export function clampX(x: number, screenW: number, id: ToolbarId, snapped: boolean): number {
  const min: number = EDGE_MARGIN;
  const max: number = Math.max(min, screenW - toolbarWidth(id, snapped) - EDGE_MARGIN);
  if (x < min) {
    return min;
  }
  if (x > max) {
    return max;
  }
  return x;
}

/** Y 方向夹紧：保证工具栏不超出顶/底边界。 */
export function clampY(
  y: number,
  screenH: number,
  id: ToolbarId,
  snapped: boolean,
  phase: StudyPhase
): number {
  const min: number = TOP_RESERVED;
  const max: number = Math.max(min, screenH - toolbarHeight(id, snapped, phase) - BOTTOM_RESERVED);
  if (y < min) {
    return min;
  }
  if (y > max) {
    return max;
  }
  return y;
}

/**
 * 松手吸附：根据工具栏中心点判断更靠近哪一边（左/右/顶/底）；
 * 左/右 → 竖版贴侧边（snapped=true）；顶/底 → 横版贴顶/底（snapped=false）。
 * 中心点计算用竖版尺寸（松手后切换为竖版），所以传入 phase 仅 main 区分 question/answer。
 */
export function snapToSide(
  posX: number,
  posY: number,
  screenW: number,
  screenH: number,
  id: ToolbarId,
  phase: StudyPhase
): SnapResult {
  // 用竖版尺寸（snapped=true）算中心点，因为松手后切换为竖版
  const currentW: number = toolbarWidth(id, true);
  const currentH: number = toolbarHeight(id, true, phase);
  const centerX: number = posX + currentW / 2;
  const centerY: number = posY + currentH / 2;
  const distLeft: number = centerX;
  const distRight: number = screenW - centerX;
  const distTop: number = centerY - TOP_RESERVED;
  const distBottom: number = screenH - BOTTOM_RESERVED - centerY;
  const minDist: number = Math.min(distLeft, distRight, distTop, distBottom);

  let snapSide: SnapSide;
  let snapped: boolean;
  if (minDist === distLeft) {
    snapSide = 'left';
    snapped = true;
  } else if (minDist === distRight) {
    snapSide = 'right';
    snapped = true;
  } else if (minDist === distTop) {
    snapSide = 'top';
    snapped = false;
  } else {
    snapSide = 'bottom';
    snapped = false;
  }

  // 切换布局后的最终尺寸
  const finalW: number = toolbarWidth(id, snapped);
  const finalH: number = toolbarHeight(id, snapped, phase);
  let snappedX: number;
  let snappedY: number;
  if (snapSide === 'left') {
    snappedX = EDGE_MARGIN;
    snappedY = clampY(posY, screenH, id, snapped, phase);
  } else if (snapSide === 'right') {
    snappedX = Math.max(EDGE_MARGIN, screenW - finalW - EDGE_MARGIN);
    snappedY = clampY(posY, screenH, id, snapped, phase);
  } else if (snapSide === 'top') {
    snappedX = clampX(posX, screenW, id, snapped);
    snappedY = TOP_RESERVED;
  } else {  // bottom
    snappedX = clampX(posX, screenW, id, snapped);
    snappedY = Math.max(TOP_RESERVED, screenH - finalH - BOTTOM_RESERVED);
  }
  const result: SnapResult = { x: snappedX, y: snappedY, snapSide, snapped };
  return result;
}

/**
 * 推断保存位置的吸附侧（用于 loadInitialPosition 时恢复 snapSide）。
 * 与 snapToSide 同语义，但只返回 snapSide + snapped 不计算最终位置。
 */
export function inferSnapSide(
  posX: number,
  posY: number,
  screenW: number,
  screenH: number,
  id: ToolbarId,
  phase: StudyPhase
): InferSnapSideResult {
  const w: number = toolbarWidth(id, true);
  const h: number = toolbarHeight(id, true, phase);
  const centerX: number = posX + w / 2;
  const centerY: number = posY + h / 2;
  const distLeft: number = centerX;
  const distRight: number = screenW - centerX;
  const distTop: number = centerY - TOP_RESERVED;
  const distBottom: number = screenH - BOTTOM_RESERVED - centerY;
  const minDist: number = Math.min(distLeft, distRight, distTop, distBottom);
  if (minDist === distLeft) {
    const r: InferSnapSideResult = { snapSide: 'left', snapped: true };
    return r;
  }
  if (minDist === distRight) {
    const r: InferSnapSideResult = { snapSide: 'right', snapped: true };
    return r;
  }
  if (minDist === distTop) {
    const r: InferSnapSideResult = { snapSide: 'top', snapped: false };
    return r;
  }
  const r: InferSnapSideResult = { snapSide: 'bottom', snapped: false };
  return r;
}
