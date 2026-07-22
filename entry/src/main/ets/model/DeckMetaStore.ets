// SPDX-License-Identifier: AGPL-3.0-or-later
//
// 牌组级元数据持久化（单卡可定制信息：色标条 tone / 自定义别名 displayName / 背景图 backgroundImage）。
// 用 preferences（@kit.ArkData）存储元数据，key 形如 `deck_tone_<deckId>`，
// tone value 为 deckToneKey() 返回的小写字符串（'blue'/'purple'/'mint'/'amber'/'black'/'red'/'none'）。
// 背景图文件存到沙盒 filesDir/deck_backgrounds/<deckId>.jpg，preferences 仅存路径。
// 复用 ThemeStore 的 abilityContext 获取模式，store 名独立避免与全局设置互相覆盖。

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { DeckTone, deckToneKey, parseDeckTone } from './HomeModels';

const STORE_NAME: string = 'jidecards_deck_meta';
const TONE_KEY_PREFIX: string = 'deck_tone_';
const DISPLAY_NAME_KEY_PREFIX: string = 'deck_display_name_';
const BACKGROUND_KEY_PREFIX: string = 'deck_background_';
const BACKGROUND_DIR: string = 'deck_backgrounds';
const CONTEXT_KEY: string = 'abilityContext';

function abilityContext(): common.UIAbilityContext | null {
  const context: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(CONTEXT_KEY);
  return context === undefined ? null : context;
}

function toneKey(deckId: string): string {
  return `${TONE_KEY_PREFIX}${deckId}`;
}

function displayNameKey(deckId: string): string {
  return `${DISPLAY_NAME_KEY_PREFIX}${deckId}`;
}

function backgroundKey(deckId: string): string {
  return `${BACKGROUND_KEY_PREFIX}${deckId}`;
}

/** 沙盒内单张牌组背景图绝对路径：filesDir/deck_backgrounds/<deckId>_<timestamp>.jpg。
 *  时间戳保证每次保存路径不同 → LazyForEach keyItem 变化 → ListItem 重建 → PixelMap 重载。 */
function backgroundFilePath(context: common.UIAbilityContext, deckId: string): string {
  return `${context.filesDir}/${BACKGROUND_DIR}/${deckId}_${Date.now()}.jpg`;
}

/** 确保 deck_backgrounds 目录存在；已存在不重复创建。 */
async function ensureBackgroundDir(context: common.UIAbilityContext): Promise<void> {
  const dirPath: string = `${context.filesDir}/${BACKGROUND_DIR}`;
  try {
    const exists: boolean = await fs.access(dirPath);
    if (!exists) {
      await fs.mkdir(dirPath, true);
    }
  } catch (error) {
    // access 失败说明目录不存在，直接创建
    await fs.mkdir(dirPath, true);
  }
}

/**
 * 按给定的 deckId 列表逐个查询已持久化的 tone。
 * 返回 deckId → DeckTone 的 Map；未持久化或读取失败的不出现在 Map 中，调用方继续走自动轮转默认值。
 * 之所以传入 deckIds 而非用 store.getAll()，是因为 ArkTS 严格模式下 getAll 的 Object 返回类型
 * 无法直接转 Record<string, ValueType>，逐键查询更安全。
 */
export async function loadDeckTones(deckIds: string[]): Promise<Map<string, DeckTone>> {
  const out: Map<string, DeckTone> = new Map<string, DeckTone>();
  if (deckIds.length === 0) {
    return out;
  }
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return out;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    for (let i: number = 0; i < deckIds.length; i++) {
      const deckId: string = deckIds[i];
      const has: boolean = await store.has(toneKey(deckId));
      if (!has) {
        continue;
      }
      const value: preferences.ValueType = await store.get(toneKey(deckId), '');
      if (typeof value !== 'string') {
        continue;
      }
      const tone: DeckTone | null = parseDeckTone(value);
      if (tone !== null) {
        out.set(deckId, tone);
      }
    }
    return out;
  } catch (error) {
    return out;
  }
}

/** 持久化单张牌组的 tone 选择；tone===None 也持久化（表示用户主动取消色条）。 */
export async function saveDeckTone(deckId: string, tone: DeckTone): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    await store.put(toneKey(deckId), deckToneKey(tone));
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}

/**
 * 按给定的 deckId 列表逐个查询已持久化的 displayName（用户自定义别名）。
 * 返回 deckId → displayName 的 Map；未持久化或读取失败的不出现在 Map 中，调用方继续走后端真实 name。
 * 空串视为未设置（saveDeckDisplayName 落盘空串时会删除键）。
 */
export async function loadDeckDisplayNames(deckIds: string[]): Promise<Map<string, string>> {
  const out: Map<string, string> = new Map<string, string>();
  if (deckIds.length === 0) {
    return out;
  }
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return out;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    for (let i: number = 0; i < deckIds.length; i++) {
      const deckId: string = deckIds[i];
      const has: boolean = await store.has(displayNameKey(deckId));
      if (!has) {
        continue;
      }
      const value: preferences.ValueType = await store.get(displayNameKey(deckId), '');
      if (typeof value !== 'string' || value === '') {
        continue;
      }
      out.set(deckId, value);
    }
    return out;
  } catch (error) {
    return out;
  }
}

/**
 * 持久化单张牌组的 displayName（用户自定义别名）。
 * name 为空串时删除键（表示用户改回原名，不再覆盖）。
 * 注意：本函数只写本地 preferences，不调后端 rename_deck，因此后端真实 deck name 保持不变，
 * 导出 apkg/同步到其他设备时仍显示后端原名。
 */
export async function saveDeckDisplayName(deckId: string, name: string): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const trimmed: string = name.trim();
    if (trimmed === '') {
      await store.delete(displayNameKey(deckId));
    } else {
      await store.put(displayNameKey(deckId), trimmed);
    }
    await store.flush();
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}

/**
 * 按给定的 deckId 列表逐个查询已持久化的背景图路径。
 * 返回 deckId → 文件绝对路径 的 Map；未持久化或文件不存在的不出现在 Map 中。
 * 校验文件确实存在（防止用户清缓存后 preferences 残留指向已删文件）。
 */
export async function loadDeckBackgroundImages(deckIds: string[]): Promise<Map<string, string>> {
  const out: Map<string, string> = new Map<string, string>();
  if (deckIds.length === 0) {
    return out;
  }
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return out;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    for (let i: number = 0; i < deckIds.length; i++) {
      const deckId: string = deckIds[i];
      const has: boolean = await store.has(backgroundKey(deckId));
      if (!has) {
        continue;
      }
      const value: preferences.ValueType = await store.get(backgroundKey(deckId), '');
      if (typeof value !== 'string' || value === '') {
        continue;
      }
      // 校验文件确实存在；不存在则清理 preferences 残留
      let fileExists: boolean = false;
      try {
        fileExists = await fs.access(value);
      } catch (e) {
        fileExists = false;
      }
      if (fileExists) {
        out.set(deckId, value);
      } else {
        await store.delete(backgroundKey(deckId));
        await store.flush();
      }
    }
    return out;
  } catch (error) {
    return out;
  }
}

/**
 * 把裁剪后的 PixelMap 编码为 JPEG 写入沙盒 filesDir/deck_backgrounds/<deckId>_<timestamp>.jpg，
 * 并把绝对路径写入 preferences。
 * 文件名带时间戳：让每次保存的路径不同，LazyForEach keyItem（含 backgroundImage）随之变化，
 * 触发 ListItem 重建与 PixelMap 重载，避免"保存新图后列表仍显示旧图"。
 * 同时删除该 deckId 的旧文件，避免沙盒堆积。
 * 失败时抛出错误（调用方 UI 显示），不静默吞掉——因为图片保存失败是用户能感知的明显问题。
 */
export async function saveDeckBackgroundImage(deckId: string, pixelMap: PixelMap): Promise<string> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    throw new Error('abilityContext is null');
  }
  await ensureBackgroundDir(context);
  // 先查 preferences 拿旧文件路径，保存成功后删除（避免堆积）
  const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
  let oldPath: string = '';
  try {
    const has: boolean = await store.has(backgroundKey(deckId));
    if (has) {
      const value: preferences.ValueType = await store.get(backgroundKey(deckId), '');
      if (typeof value === 'string') {
        oldPath = value;
      }
    }
  } catch (e) {
    // 读旧路径失败不阻塞保存
  }

  // 新文件路径带时间戳，确保与旧路径不同 → LazyForEach keyItem 变化 → ListItem 重建
  const filePath: string = backgroundFilePath(context, deckId);
  // 先写临时文件再 rename，避免覆盖旧文件时编码失败导致数据损坏
  const tempPath: string = `${filePath}.tmp`;
  const file: fs.File = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    const imagePacker: image.ImagePacker = image.createImagePacker();
    try {
      const packed: ArrayBuffer = await imagePacker.packing(pixelMap, {
        format: 'image/jpeg',
        quality: 85
      });
      await fs.write(file.fd, packed);
    } finally {
      imagePacker.release();
    }
  } finally {
    await fs.close(file);
  }
  await fs.rename(tempPath, filePath);
  // 路径写入 preferences
  await store.put(backgroundKey(deckId), filePath);
  await store.flush();
  // 删除旧文件（路径与新文件不同时才删，避免误删刚保存的文件）
  if (oldPath !== '' && oldPath !== filePath) {
    try {
      await fs.unlink(oldPath);
    } catch (e) {
      // 旧文件不存在忽略
    }
  }
  return filePath;
}

/**
 * 删除单张牌组的背景图：删除沙盒文件 + 删除 preferences 键。
 * 失败时静默——背景图丢失不会阻塞 UI，DeckListItem 会回退到 surface_card。
 */
export async function clearDeckBackgroundImage(deckId: string): Promise<void> {
  const context: common.UIAbilityContext | null = abilityContext();
  if (context === null) {
    return;
  }
  try {
    const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
    const has: boolean = await store.has(backgroundKey(deckId));
    if (has) {
      const value: preferences.ValueType = await store.get(backgroundKey(deckId), '');
      if (typeof value === 'string' && value !== '') {
        try {
          await fs.unlink(value);
        } catch (e) {
          // 文件不存在忽略
        }
      }
      await store.delete(backgroundKey(deckId));
      await store.flush();
    }
  } catch (error) {
    // 偏好不可用时仅丢失持久化，不阻塞 UI。
  }
}

