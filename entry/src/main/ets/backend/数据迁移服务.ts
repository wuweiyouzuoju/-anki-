// SPDX-License-Identifier: AGPL-3.0-or-later

import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { 后端会话 } from './后端会话';
import { 导入导出方法, 服务号 } from './服务索引';
import type { ImportSummary } from '../proto/messages/ImportExportMessages';
import {
  decodeImportResponse,
  encodeExportAnkiPackageRequest,
  encodeExportCollectionPackageRequest,
  encodeImportAnkiPackageRequest,
  encodeImportCollectionPackageRequest
} from '../proto/messages/ImportExportMessages';

export interface 牌组导出选项 {
  withScheduling: boolean;
  withDeckConfigs: boolean;
  withMedia: boolean;
  legacy: boolean;
}

export interface 集合导出选项 {
  includeMedia: boolean;
  legacy: boolean;
}

const 集合文件名: string = 'collection.anki2';
const 媒体库文件名: string = 'collection.mdb';
const 媒体目录名: string = 'collection.media';
const 复制缓冲大小: number = 64 * 1024;
let 迁移输出ID: number = 0;

interface 安全副本结构 {
  根目录: string;
  集合文件路径: string;
  媒体库路径: string;
  媒体目录路径: string;
}

export type 数据迁移校验键 = 'transfer_confirmation_required';

export class 数据迁移校验错误 extends Error {
  readonly messageKey: 数据迁移校验键;

  constructor(messageKey: 数据迁移校验键) {
    super(messageKey);
    this.messageKey = messageKey;
  }
}

export async function 导出牌组(
  文件目录: string,
  牌组ID: number,
  选项: 牌组导出选项
): Promise<string> {
  const 输出路径 = 生成输出路径(文件目录, 'deck', 'apkg');
  try {
    await 后端会话.获取实例().调用(
      服务号.后端导入导出,
      导入导出方法.导出Anki包,
      encodeExportAnkiPackageRequest(输出路径, 牌组ID, 选项)
    );
    return 输出路径;
  } catch (error) {
    静默删除(输出路径);
    throw error;
  }
}

export async function 导出集合(
  文件目录: string,
  选项: 集合导出选项
): Promise<string> {
  const 输出路径 = 生成输出路径(文件目录, 'collection', 'colpkg');
  const 会话 = 后端会话.获取实例();
  try {
    await 会话.调用(
      服务号.后端导入导出,
      导入导出方法.导出集合包,
      encodeExportCollectionPackageRequest(输出路径, 选项)
    );
    return 输出路径;
  } catch (error) {
    静默删除(输出路径);
    throw error;
  } finally {
    await 会话.标记集合已消费();
    try {
      await 会话.确保已打开(文件目录);
    } catch (reopenError) {
    }
  }
}

export async function 完成导出(
  上下文: common.UIAbilityContext,
  沙箱路径: string,
  文件名: string,
  扩展名: string
): Promise<string | null> {
  return 保存沙箱导出(上下文, 沙箱路径, 文件名, 扩展名);
}

async function 保存沙箱导出(
  上下文: common.UIAbilityContext,
  沙箱路径: string,
  文件名: string,
  扩展名: string
): Promise<string | null> {
  try {
    const 选项: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    选项.newFileNames = [文件名];
    选项.fileSuffixChoices = [扩展名];
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(上下文);
    const URI列表: Array<string> = await documentPicker.save(选项);
    if (URI列表.length === 0) return null;
    按描述符复制文件(沙箱路径, URI列表[0]);
    return URI列表[0];
  } finally {
    静默删除(沙箱路径);
  }
}

function 生成输出路径(文件目录: string, 词干: string, 扩展名: string): string {
  const 导出目录 = `${文件目录}/exports`;
  确保目录存在(导出目录);
  return `${导出目录}/${词干}-${Date.now()}-${下一迁移输出ID()}.${扩展名}`;
}

function 下一迁移输出ID(): number {
  迁移输出ID += 1;
  return 迁移输出ID;
}

export function 暂存导入文件(文件目录: string, 源URI: string): string {
  return 复制URI到沙箱(文件目录, 源URI, 'apkg');
}

export async function 执行牌组导入(暂存路径: string): Promise<ImportSummary> {
  try {
    const 响应 = await 后端会话.获取实例().调用(
      服务号.后端导入导出,
      导入导出方法.导入Anki包,
      encodeImportAnkiPackageRequest(暂存路径)
    );
    return decodeImportResponse(响应);
  } finally {
    静默删除(暂存路径);
  }
}

export async function 替换集合(
  文件目录: string,
  源URI: string,
  是否已确认: boolean,
  阶段回调?: (阶段: number) => void
): Promise<void> {
  if (!是否已确认) {
    throw new 数据迁移校验错误('transfer_confirmation_required');
  }

  阶段回调?.(0);
  const 暂存路径 = 复制URI到沙箱(文件目录, 源URI, 'colpkg');
  const 会话 = 后端会话.获取实例();
  let 安全副本: 安全副本结构 | null = null;
  try {
    阶段回调?.(1);
    await 会话.关闭集合();
    安全副本 = 创建安全副本(文件目录);
    阶段回调?.(2);
    await 会话.在集合关闭下调用(
      服务号.后端导入导出,
      导入导出方法.导入集合包,
      encodeImportCollectionPackageRequest({
        colPath: `${文件目录}/${集合文件名}`,
        backupPath: 暂存路径,
        mediaFolder: `${文件目录}/${媒体目录名}`,
        mediaDb: `${文件目录}/${媒体库文件名}`
      })
    );
    阶段回调?.(3);
    await 会话.确保已打开(文件目录);
  } catch (error) {
    if (安全副本 !== null) {
      恢复安全副本(文件目录, 安全副本);
    }
    await 会话.确保已打开(文件目录);
    throw error;
  } finally {
    静默删除(暂存路径);
  }
  if (安全副本 !== null) {
    删除安全副本(安全副本);
  }
}

function 创建安全副本(文件目录: string): 安全副本结构 {
  const 根目录 = `${文件目录}/transfer-safety-${Date.now()}-${下一迁移输出ID()}`;
  const 集合文件路径 = `${根目录}/${集合文件名}`;
  const 媒体库路径 = `${根目录}/${媒体库文件名}`;
  const 媒体目录路径 = `${根目录}/${媒体目录名}`;
  确保目录存在(根目录);
  复制文件(`${文件目录}/${集合文件名}`, 集合文件路径);
  复制文件(`${文件目录}/${媒体库文件名}`, 媒体库路径);
  复制目录(`${文件目录}/${媒体目录名}`, 媒体目录路径);
  return { 根目录, 集合文件路径, 媒体库路径, 媒体目录路径 };
}

function 恢复安全副本(文件目录: string, 安全副本: 安全副本结构): void {
  复制文件(安全副本.集合文件路径, `${文件目录}/${集合文件名}`);
  复制文件(安全副本.媒体库路径, `${文件目录}/${媒体库文件名}`);
  const 媒体路径 = `${文件目录}/${媒体目录名}`;
  删除目录(媒体路径);
  复制目录(安全副本.媒体目录路径, 媒体路径);
}

function 删除安全副本(安全副本: 安全副本结构): void {
  静默删除目录(安全副本.根目录);
}

function 静默删除目录(路径: string): void {
  try {
    删除目录(路径);
  } catch (error) {
  }
}

function 复制目录(源路径: string, 目标路径: string): void {
  if (!路径存在(源路径)) {
    return;
  }
  确保目录存在(目标路径);
  for (const 条目 of fs.listFileSync(源路径)) {
    const 源子项 = `${源路径}/${条目}`;
    const 目标子项 = `${目标路径}/${条目}`;
    if (fs.statSync(源子项).isDirectory()) {
      复制目录(源子项, 目标子项);
    } else {
      复制文件(源子项, 目标子项);
    }
  }
}

function 删除目录(路径: string): void {
  if (!路径存在(路径)) {
    return;
  }
  for (const 条目 of fs.listFileSync(路径)) {
    const 子项 = `${路径}/${条目}`;
    if (fs.statSync(子项).isDirectory()) {
      删除目录(子项);
    } else {
      静默删除(子项);
    }
  }
  fs.rmdirSync(路径);
}

function 确保目录存在(路径: string): void {
  if (!路径存在(路径)) {
    fs.mkdirSync(路径);
  }
}

function 路径存在(路径: string): boolean {
  try {
    return fs.accessSync(路径);
  } catch (error) {
    return false;
  }
}

function 复制文件(源路径: string, 目标路径: string): void {
  fs.copyFileSync(源路径, 目标路径);
}

function 复制URI到沙箱(文件目录: string, URI: string, 扩展名: string): string {
  const 导入目录: string = `${文件目录}/imports`;
  if (!路径存在(导入目录)) fs.mkdirSync(导入目录);
  const 路径: string = `${导入目录}/import-${Date.now()}-${下一迁移输出ID()}.${扩展名}`;
  try {
    按描述符复制文件(URI, 路径);
    return 路径;
  } catch (error) {
    静默删除(路径);
    throw error;
  }
}

function 按描述符复制文件(源URI或路径: string, 目标URI或路径: string): void {
  const 源文件: fs.File = fs.openSync(源URI或路径, fs.OpenMode.READ_ONLY);
  try {
    const 目标文件: fs.File = fs.openSync(
      目标URI或路径, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      const 缓冲区: ArrayBuffer = new ArrayBuffer(复制缓冲大小);
      let 读取大小: number = fs.readSync(源文件.fd, 缓冲区, { length: 缓冲区.byteLength });
      while (读取大小 > 0) {
        let 已写入总数: number = 0;
        while (已写入总数 < 读取大小) {
          const 剩余缓冲: ArrayBuffer = 缓冲区.slice(已写入总数, 读取大小);
          const 写入大小: number = fs.writeSync(
            目标文件.fd, 剩余缓冲, { length: 剩余缓冲.byteLength });
          if (写入大小 <= 0) {
            throw new Error('Unable to write transferred data.');
          }
          已写入总数 += 写入大小;
        }
        读取大小 = fs.readSync(源文件.fd, 缓冲区, { length: 缓冲区.byteLength });
      }
    } finally {
      fs.closeSync(目标文件);
    }
  } finally {
    fs.closeSync(源文件);
  }
}

function 静默删除(路径: string): void {
  try {
    fs.unlinkSync(路径);
  } catch (error) {
  }
}
