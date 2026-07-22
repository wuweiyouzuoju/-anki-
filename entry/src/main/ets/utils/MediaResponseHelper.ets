// MediaResponseHelper：ArkWeb 媒体拦截的 MIME 推断与沙箱读文件（M7）。
// 与 StudyPage 的 onInterceptRequest 配合：自建域名 → collection.media/ 文件。

import { fileIo as fs } from '@kit.CoreFileKit';

const MIME_BY_EXT: Record<string, string> = {
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

/** 按扩展名推断 MIME（小写、无点），未知返回 application/octet-stream */
export function mimeTypeOf(fileName: string): string {
  const dotIndex: number = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex === fileName.length - 1) {
    return 'application/octet-stream';
  }
  const ext: string = fileName.substring(dotIndex + 1).toLowerCase();
  const mime: string | undefined = MIME_BY_EXT[ext];
  return mime === undefined ? 'application/octet-stream' : mime;
}

/**
 * 解码 URL 编码的文件名（如 %E4%B8%AD%E6%96%87.mp3 → 中文.mp3）。
 * Anki 卡片 HTML 中 [sound:xxx] 标签的文件名可能以 URL 编码形式存在，
 * 后端 extract_av_tags 提取的是字面字符串，需解码才能匹配磁盘上的实际文件名。
 * 解码失败（如含非编码 %）时回退原字面名，避免抛错中断播放。
 */
export function decodeFileName(fileName: string): string {
  try {
    return decodeURIComponent(fileName);
  } catch (error) {
    return fileName;
  }
}

/**
 * 读取媒体文件为 ArrayBuffer；不存在/读取失败返回 null（拦截器据此放行 404 语义）。
 * fileName 已按 URL 解码，直接拼接 mediaDir。
 */
export function readMediaFile(mediaDir: string, fileName: string): ArrayBuffer | null {
  const path: string = `${mediaDir}/${fileName}`;
  try {
    if (!fs.accessSync(path)) {
      return null;
    }
    const stat = fs.statSync(path);
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer, { length: stat.size });
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  } catch (error) {
    return null;
  }
}
