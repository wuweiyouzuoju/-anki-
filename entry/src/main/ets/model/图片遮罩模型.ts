// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID MODEL-IMAGE-OCCLUSION-001
// @名称 图片遮罩模型
//
// @作用
// 定义图片遮盖（Image Occlusion）建卡流程中的纯数据与字符串生成逻辑：
//   1. 遮罩描述 接口：单个矩形遮罩的归一化坐标与编号
//   2. 生成Occlusions字符串：把遮罩列表渲染为 Anki 兼容的 cloze 字符串
//   3. 编号颜色：c1-c5 对应的固定展示色（红橙黄绿蓝），供编辑器组件高亮使用
//
// 与 Anki rslib image_occlusion/imageocclusion.rs 的 parse_image_cloze
// 严格对齐：每个遮罩渲染为
//   {{cN::image-occlusion:rect:left=L:top=T:width=W:height=H}}
// 多个遮罩直接串连，无分隔符。
//
// @输入
// 遮罩描述列表（坐标均归一化到 0-1，与 Anki 后端协议一致）
//
// @输出
// Anki cloze 字符串
//
// @业务规则
// 仅支持 rect 形状（覆盖 90% 用例），ellipse/polygon/text 不在本次范围。
// 编号 c1-c5 由调用方保证；编号越界（如 6）仍按 {{c6::...}} 输出，不强校验。
// 坐标保留至多 4 位小数，去除末尾 0（0.2000 → "0.2"，0.123456 → "0.1235"）。
// 该文件不依赖 HarmonyOS Kit 或 ArkUI，可被 node test runner 直接 import。
//
// @副作用
// 无。
// ========================================================

/** 单个矩形遮罩的归一化描述。坐标全部 0-1，与 Anki 后端协议一致。 */
export interface 遮罩描述 {
  /** 形状固定为 'rect'（保留字段以便后续扩展 ellipse/polygon/text） */
  形状: 'rect';
  /** 左上角横坐标，归一化 0-1 */
  左: number;
  /** 左上角纵坐标，归一化 0-1 */
  顶: number;
  /** 宽度，归一化 0-1 */
  宽: number;
  /** 高度，归一化 0-1 */
  高: number;
  /** cloze 编号（1-5 对应 c1-c5）；越界值原样输出 */
  编号: number;
}

// ========================================================
// @块ID MODEL-IMAGE-OCCLUSION-002
// @名称 格式化归一化坐标
//
// @作用
// 把归一化坐标格式化为 Anki 解析器可接受的字符串：
// 先四舍五入到 4 位小数（避免浮点尾数误差），再用 String() 转换，
// 自然去除末尾 0（0.2 → "0.2"，0 → "0"，1 → "1"）。
//
// @输入
// 归一化数值（理论上 0-1，但不强校验，由调用方保证）
//
// @输出
// 字符串形式的坐标
//
// @副作用
// 无。
// ========================================================
function 格式化归一化坐标(值: number): string {
  const 四舍五入: number = Math.round(值 * 10000) / 10000;
  return String(四舍五入);
}

// ========================================================
// @块ID MODEL-IMAGE-OCCLUSION-003
// @名称 生成Occlusions字符串
//
// @作用
// 把遮罩列表渲染为 Anki ImageOcclusion 笔记的 Occlusions 字段值：
//   {{c1::image-occlusion:rect:left=0.2:top=0.3:width=0.4:height=0.1}}
//   {{c2::image-occlusion:rect:left=...:top=...:width=...:height=...}}
// 多个遮罩直接串连，无分隔符（与 Anki rslib parse_image_occlusions 兼容）。
//
// @输入
// 遮罩描述列表
//
// @输出
// 串连后的 cloze 字符串；空列表返回空字符串
//
// @业务规则
// 字段顺序固定为 left/top/width/height（与 spec 示例一致；
// Anki 解析器基于 nom separated_pair 顺序无关，但保持稳定输出便于测试）。
// 不对编号范围、坐标范围做强校验：调用方负责保证业务约束。
//
// @副作用
// 无。
// ========================================================
export function 生成Occlusions字符串(遮罩列表: 遮罩描述[]): string {
  let 结果: string = '';
  for (let i = 0; i < 遮罩列表.length; i++) {
    const 遮罩: 遮罩描述 = 遮罩列表[i];
    const 左: string = 格式化归一化坐标(遮罩.左);
    const 顶: string = 格式化归一化坐标(遮罩.顶);
    const 宽: string = 格式化归一化坐标(遮罩.宽);
    const 高: string = 格式化归一化坐标(遮罩.高);
    结果 += `{{c${遮罩.编号}::image-occlusion:rect:left=${左}:top=${顶}:width=${宽}:height=${高}}}`;
  }
  return 结果;
}

// ========================================================
// @块ID MODEL-IMAGE-OCCLUSION-004
// @名称 编号颜色
//
// @作用
// c1-c5 对应的固定展示色（红/橙/黄/绿/蓝），供编辑器组件高亮当前选中的
// ordinal 与对应矩形。颜色取自 Material Design 色板，深浅色背景均可读。
// 越界编号返回中性灰色，不报错。
//
// @输入
// cloze 编号（1-5 为合法范围；其他值返回默认色）
//
// @输出
// hex 颜色字符串
//
// @副作用
// 无。
// ========================================================
export function 编号颜色(编号: number): string {
  switch (编号) {
    case 1:
      return '#E53935'; // c1 红
    case 2:
      return '#FB8C00'; // c2 橙
    case 3:
      return '#FDD835'; // c3 黄
    case 4:
      return '#43A047'; // c4 绿
    case 5:
      return '#1E88E5'; // c5 蓝
    default:
      return '#9E9E9E'; // 越界灰
  }
}
