// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { 牌组色调, 牌组色调键, 解析牌组色调 } from './主页模型';

const 存储名: string = 'jidecards_deck_meta';
const 色调键前缀: string = 'deck_tone_';
const 别名键前缀: string = 'deck_display_name_';
const 背景图键前缀: string = 'deck_background_';
const 背景图目录名: string = 'deck_backgrounds';
const 上下文存储键: string = 'abilityContext';

function 获取能力上下文(): common.UIAbilityContext | null {
  const 上下文: common.UIAbilityContext | undefined =
    AppStorage.get<common.UIAbilityContext>(上下文存储键);
  return 上下文 === undefined ? null : 上下文;
}

function 色调键(牌组ID: string): string {
  return `${色调键前缀}${牌组ID}`;
}

function 别名键(牌组ID: string): string {
  return `${别名键前缀}${牌组ID}`;
}

function 背景图键(牌组ID: string): string {
  return `${背景图键前缀}${牌组ID}`;
}

function 背景图文件路径(上下文: common.UIAbilityContext, 牌组ID: string): string {
  return `${上下文.filesDir}/${背景图目录名}/${牌组ID}_${Date.now()}.jpg`;
}

async function 确保背景图目录存在(上下文: common.UIAbilityContext): Promise<void> {
  const 目录路径: string = `${上下文.filesDir}/${背景图目录名}`;
  try {
    const 已存在: boolean = await fs.access(目录路径);
    if (!已存在) {
      await fs.mkdir(目录路径, true);
    }
  } catch (错误) {
    await fs.mkdir(目录路径, true);
  }
}

export async function 加载牌组色调映射(牌组ID列表: string[]): Promise<Map<string, 牌组色调>> {
  const 输出: Map<string, 牌组色调> = new Map<string, 牌组色调>();
  if (牌组ID列表.length === 0) {
    return 输出;
  }
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return 输出;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    for (let i: number = 0; i < 牌组ID列表.length; i++) {
      const 牌组ID: string = 牌组ID列表[i];
      const 是否存在: boolean = await 存储.has(色调键(牌组ID));
      if (!是否存在) {
        continue;
      }
      const 值: preferences.ValueType = await 存储.get(色调键(牌组ID), '');
      if (typeof 值 !== 'string') {
        continue;
      }
      const 色调: 牌组色调 | null = 解析牌组色调(值);
      if (色调 !== null) {
        输出.set(牌组ID, 色调);
      }
    }
    return 输出;
  } catch (错误) {
    return 输出;
  }
}

export async function 保存牌组色调(牌组ID: string, 色调: 牌组色调): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    await 存储.put(色调键(牌组ID), 牌组色调键(色调));
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 加载牌组别名映射(牌组ID列表: string[]): Promise<Map<string, string>> {
  const 输出: Map<string, string> = new Map<string, string>();
  if (牌组ID列表.length === 0) {
    return 输出;
  }
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return 输出;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    for (let i: number = 0; i < 牌组ID列表.length; i++) {
      const 牌组ID: string = 牌组ID列表[i];
      const 是否存在: boolean = await 存储.has(别名键(牌组ID));
      if (!是否存在) {
        continue;
      }
      const 值: preferences.ValueType = await 存储.get(别名键(牌组ID), '');
      if (typeof 值 !== 'string' || 值 === '') {
        continue;
      }
      输出.set(牌组ID, 值);
    }
    return 输出;
  } catch (错误) {
    return 输出;
  }
}

export async function 保存牌组别名(牌组ID: string, 名称: string): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 去除首尾空格: string = 名称.trim();
    if (去除首尾空格 === '') {
      await 存储.delete(别名键(牌组ID));
    } else {
      await 存储.put(别名键(牌组ID), 去除首尾空格);
    }
    await 存储.flush();
  } catch (错误) {
  }
}

export async function 加载牌组背景图映射(牌组ID列表: string[]): Promise<Map<string, string>> {
  const 输出: Map<string, string> = new Map<string, string>();
  if (牌组ID列表.length === 0) {
    return 输出;
  }
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return 输出;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    for (let i: number = 0; i < 牌组ID列表.length; i++) {
      const 牌组ID: string = 牌组ID列表[i];
      const 是否存在: boolean = await 存储.has(背景图键(牌组ID));
      if (!是否存在) {
        continue;
      }
      const 值: preferences.ValueType = await 存储.get(背景图键(牌组ID), '');
      if (typeof 值 !== 'string' || 值 === '') {
        continue;
      }
      let 文件存在: boolean = false;
      try {
        文件存在 = await fs.access(值);
      } catch (e) {
        文件存在 = false;
      }
      if (文件存在) {
        输出.set(牌组ID, 值);
      } else {
        await 存储.delete(背景图键(牌组ID));
        await 存储.flush();
      }
    }
    return 输出;
  } catch (错误) {
    return 输出;
  }
}

export async function 保存牌组背景图(牌组ID: string, 像素图: PixelMap): Promise<string> {
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    throw new Error('abilityContext is null');
  }
  await 确保背景图目录存在(上下文);
  const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
  let 旧路径: string = '';
  try {
    const 是否存在: boolean = await 存储.has(背景图键(牌组ID));
    if (是否存在) {
      const 值: preferences.ValueType = await 存储.get(背景图键(牌组ID), '');
      if (typeof 值 === 'string') {
        旧路径 = 值;
      }
    }
  } catch (e) {
  }

  const 文件路径: string = 背景图文件路径(上下文, 牌组ID);
  const 临时路径: string = `${文件路径}.tmp`;
  const 文件: fs.File = fs.openSync(临时路径, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    const 图像打包器: image.ImagePacker = image.createImagePacker();
    try {
      const 打包数据: ArrayBuffer = await 图像打包器.packToData(像素图, {
        format: 'image/jpeg',
        quality: 85
      });
      await fs.write(文件.fd, 打包数据);
    } finally {
      图像打包器.release();
    }
  } finally {
    await fs.close(文件);
  }
  await fs.rename(临时路径, 文件路径);
  await 存储.put(背景图键(牌组ID), 文件路径);
  await 存储.flush();
  if (旧路径 !== '' && 旧路径 !== 文件路径) {
    try {
      await fs.unlink(旧路径);
    } catch (e) {
    }
  }
  return 文件路径;
}

export async function 清除牌组背景图(牌组ID: string): Promise<void> {
  const 上下文: common.UIAbilityContext | null = 获取能力上下文();
  if (上下文 === null) {
    return;
  }
  try {
    const 存储: preferences.Preferences = await preferences.getPreferences(上下文, 存储名);
    const 是否存在: boolean = await 存储.has(背景图键(牌组ID));
    if (是否存在) {
      const 值: preferences.ValueType = await 存储.get(背景图键(牌组ID), '');
      if (typeof 值 === 'string' && 值 !== '') {
        try {
          await fs.unlink(值);
        } catch (e) {
        }
      }
      await 存储.delete(背景图键(牌组ID));
      await 存储.flush();
    }
  } catch (错误) {
  }
}
