// SPDX-License-Identifier: AGPL-3.0-or-later

import { fileIo as fs } from '@kit.CoreFileKit';

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

export function 取MIME类型(文件名: string): string {
  const 点位置: number = 文件名.lastIndexOf('.');
  if (点位置 < 0 || 点位置 === 文件名.length - 1) {
    return 'application/octet-stream';
  }
  const 扩展名: string = 文件名.substring(点位置 + 1).toLowerCase();
  const mime: string | undefined = 按扩展名的MIME表[扩展名];
  return mime === undefined ? 'application/octet-stream' : mime;
}

export function 解码文件名(文件名: string): string {
  try {
    return decodeURIComponent(文件名);
  } catch (错误) {
    return 文件名;
  }
}

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
