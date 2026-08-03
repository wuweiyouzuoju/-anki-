// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UTIL-FILE-IMPORT-001
// @名称 文件导入助手边界
//
// @作用
// 系统文档选择器边界。文件传输 I/O 由 数据传输服务 负责：
// 选择器返回的是 provider URI，由服务按描述符打开。
//
// @输入
// UIAbility 上下文、文件后缀过滤列表
//
// @输出
// Promise<string | null>：用户选中的文件 URI；取消或失败返回 null
//
// @副作用
// 调起系统选择器 UI，可能授予应用临时 URI 读权限。
// ========================================================

import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

/**
 * ========================================================
 * @块ID UTIL-FILE-IMPORT-002
 * @名称 选取Apkg文件
 *
 * @作用
 * 调起系统文档选择器，让用户选一个 Anki 牌组包（.apkg）。
 *
 * @输入
 * context: UIAbility 上下文
 *
 * @输出
 * Promise<string | null>：选中文件 URI；用户取消返回 null
 *
 * @副作用
 * 调起系统文档选择器 UI。
 * ========================================================
 */
export async function 选取Apkg文件(context: common.UIAbilityContext): Promise<string | null> {
  return 选取数据文件(context, ['.apkg']);
}

/**
 * ========================================================
 * @块ID UTIL-FILE-IMPORT-003
 * @名称 选取数据文件
 *
 * @作用
 * 通过 Harmony 文档选择器授予应用一个 provider URI。
 *
 * @输入
 * context: UIAbility 上下文
 * suffixes: 允许的文件后缀过滤列表
 *
 * @输出
 * Promise<string | null>：选中文件 URI；用户取消返回 null
 *
 * @副作用
 * 调起系统文档选择器 UI，可能授予临时 URI 读权限。
 * ========================================================
 */
export async function 选取数据文件(
  context: common.UIAbilityContext,
  后缀过滤: string[]
): Promise<string | null> {
  const 选项: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  选项.maxSelectNumber = 1;
  选项.fileSuffixFilters = 后缀过滤;
  const 文档选择器: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const uri列表: Array<string> = await 文档选择器.select(选项);
  return uri列表.length > 0 ? uri列表[0] : null;
}

/**
 * ========================================================
 * @块ID UTIL-FILE-IMPORT-004
 * @名称 从图库选取图片
 *
 * @作用
 * 调起系统图库选择单张图片，返回图片 uri（PhotoViewPicker 比 DocumentViewPicker 更适合图库场景：
 * 默认进入相册 tab、可滑动预览、返回的 uri 直接可被 Image 组件加载）。
 * 失败或用户取消返回 null，调用方静默处理。
 *
 * @输入
 * context: UIAbility 上下文
 *
 * @输出
 * Promise<string | null>：选中图片 URI；取消或失败返回 null
 *
 * @副作用
 * 调起系统图库选择 UI。
 * ========================================================
 */
export async function 从图库选取图片(context: common.UIAbilityContext): Promise<string | null> {
  try {
    const 选项: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    选项.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    选项.maxSelectNumber = 1;
    const 图片选择器: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const 结果: photoAccessHelper.PhotoSelectResult = await 图片选择器.select(选项);
    const uri列表: Array<string> = 结果.photoUris;
    return uri列表.length > 0 ? uri列表[0] : null;
  } catch (错误) {
    return null;
  }
}
