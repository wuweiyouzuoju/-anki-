// SPDX-License-Identifier: AGPL-3.0-or-later

// ========================================================
// @块ID UTIL-MEDIA-RESPONSE-001
// @名称 媒体响应助手边界
//
// @作用
// ArkWeb 媒体拦截的 MIME 推断与沙箱读文件（M7）。
// 与 学习页 的 onInterceptRequest 配合：自建域名 → collection.media/ 文件。
//
// @输入
// 文件名 / 媒体目录路径
//
// @输出
// MIME 字符串 / 解码后文件名 / ArrayBuffer 或 null
//
// @业务规则
// 拦截器根据返回的 ArrayBuffer 直接构造 200 响应；返回 null 则放行 404 语义。
//
// @副作用
// 同步读取沙箱文件系统（fileIo），打开/关闭文件描述符。
// ========================================================

import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 扩展名 → MIME 的查找表。
 * 覆盖 Anki 媒体目录中常见的图片/音频/视频/字体/前端资源类型。
 */
const 按扩展名的MIME表: Record<string, string> = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'm4a': 'audio/mp4',
  'mp4': 'video/mp4',
  'webm': 'video/webm',
  'css': 'text/css',
  'js': 'text/javascript',
  'html': 'text/html',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff': 'font/woff',
  'woff2': 'font/woff2'
};

/**
 * ========================================================
 * @块ID UTIL-MEDIA-RESPONSE-002
 * @名称 取MIME类型
 *
 * @作用
 * 按扩展名推断 MIME（小写、无点），未知返回 application/octet-stream。
 *
 * @输入
 * fileName: 文件名（可能含扩展名）
 *
 * @输出
 * MIME 字符串
 *
 * @副作用
 * 无
 * ========================================================
 */
export function 取MIME类型(文件名: string): string {
  const 点位置: number = 文件名.lastIndexOf('.');
  if (点位置 < 0 || 点位置 === 文件名.length - 1) {
    return 'application/octet-stream';
  }
  const 扩展名: string = 文件名.substring(点位置 + 1).toLowerCase();
  const mime: string | undefined = 按扩展名的MIME表[扩展名];
  return mime === undefined ? 'application/octet-stream' : mime;
}

/**
 * ========================================================
 * @块ID UTIL-MEDIA-RESPONSE-003
 * @名称 解码文件名
 *
 * @作用
 * 解码 URL 编码的文件名（如 %E4%B8%AD%E6%96%87.mp3 → 中文.mp3）。
 * Anki 卡片 HTML 中 [sound:xxx] 标签的文件名可能以 URL 编码形式存在，
 * 后端 extract_av_tags 提取的是字面字符串，需解码才能匹配磁盘上的实际文件名。
 * 解码失败（如含非编码 %）时回退原字面名，避免抛错中断播放。
 *
 * @输入
 * fileName: 可能 URL 编码的文件名
 *
 * @输出
 * 解码后文件名；失败时回退原文件名
 *
 * @副作用
 * 无
 * ========================================================
 */
export function 解码文件名(文件名: string): string {
  try {
    return decodeURIComponent(文件名);
  } catch (错误) {
    return 文件名;
  }
}

/**
 * ========================================================
 * @块ID UTIL-MEDIA-RESPONSE-004
 * @名称 读取媒体文件
 *
 * @作用
 * 读取媒体文件为 ArrayBuffer；不存在/读取失败返回 null（拦截器据此放行 404 语义）。
 * fileName 已按 URL 解码，直接拼接 mediaDir。
 *
 * @输入
 * mediaDir: 媒体目录绝对路径
 * fileName: 已解码的文件名
 *
 * @输出
 * ArrayBuffer（文件全部内容）或 null
 *
 * @副作用
 * 同步访问沙箱文件系统：accessSync / statSync / openSync / readSync / closeSync。
 *
 * @注意
 * 文件较大时会阻塞调用线程（同步 IO）。
 * ========================================================
 */
export function 读取媒体文件(媒体目录: string, 文件名: string): ArrayBuffer | null {
  const 路径: string = `${媒体目录}/${文件名}`;
  try {
    if (!fs.accessSync(路径)) {
      return null;
    }
    const 文件信息 = fs.statSync(路径);
    const 文件: fs.File = fs.openSync(路径, fs.OpenMode.READ_ONLY);
    try {
      const 缓冲区: ArrayBuffer = new ArrayBuffer(文件信息.size);
      fs.readSync(文件.fd, 缓冲区, { length: 文件信息.size });
      return 缓冲区;
    } finally {
      fs.closeSync(文件);
    }
  } catch (错误) {
    return null;
  }
}
