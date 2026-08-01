// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

export async function 选取Apkg文件(context: common.UIAbilityContext): Promise<string | null> {
  return 选取数据文件(context, ['.apkg']);
}

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
