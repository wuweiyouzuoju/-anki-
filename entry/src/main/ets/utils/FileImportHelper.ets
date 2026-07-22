/**
 * System document-picker boundary. Transfer I/O belongs to DataTransferService:
 * picker results are provider URIs, so the service opens them by descriptor.
 */
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';

/** Opens the system picker for one Anki deck package. */
export async function pickApkgFile(context: common.UIAbilityContext): Promise<string | null> {
  return pickDataFile(context, ['.apkg']);
}

/** Selects one provider URI granted to the app by Harmony's document picker. */
export async function pickDataFile(
  context: common.UIAbilityContext,
  suffixes: string[]
): Promise<string | null> {
  const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  options.fileSuffixFilters = suffixes;
  const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
  const uris: Array<string> = await documentPicker.select(options);
  return uris.length > 0 ? uris[0] : null;
}

/**
 * 调起系统图库选择单张图片，返回图片 uri（PhotoViewPicker 比 DocumentViewPicker 更适合图库场景：
 * 默认进入相册 tab、可滑动预览、返回的 uri 直接可被 Image 组件加载）。
 * 失败或用户取消返回 null，调用方静默处理。
 */
export async function pickImageFromGallery(context: common.UIAbilityContext): Promise<string | null> {
  try {
    const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker(context);
    const result: picker.PhotoSelectResult = await photoPicker.select(options);
    const uris: Array<string> = result.photoUris;
    return uris.length > 0 ? uris[0] : null;
  } catch (error) {
    return null;
  }
}
