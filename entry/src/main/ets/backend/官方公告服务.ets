// SPDX-License-Identifier: AGPL-3.0-or-later

import { http } from '@kit.NetworkKit';
import { 官方公告地址 } from '../model/官方公告配置';
import {
  构建官方公告请求地址,
  解析可展示官方公告
} from '../model/官方公告模型';
import type { 官方公告语言, 官方公告展示项 } from '../model/官方公告模型';

function HTTPS地址有效(url: string): boolean {
  return /^https:\/\/[^\s]+$/i.test(url);
}

export class 官方公告服务 {
  private readonly manifestUrl: string;

  constructor(manifestUrl: string = 官方公告地址) {
    this.manifestUrl = manifestUrl.trim();
  }

  async 加载公告(
    currentVersion: string,
    language: 官方公告语言,
    nowMs: number = Date.now()
  ): Promise<官方公告展示项 | null> {
    if (!HTTPS地址有效(this.manifestUrl)) return null;
    const client: http.HttpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      connectTimeout: 2000,
      readTimeout: 2000
    };
    try {
      const url: string = 构建官方公告请求地址(this.manifestUrl, nowMs);
      const response: http.HttpResponse = await client.request(url, options);
      if (response.responseCode < 200 || response.responseCode >= 300 || typeof response.result !== 'string') {
        return null;
      }
      return 解析可展示官方公告(response.result, currentVersion, nowMs, language);
    } catch (error) {
      return null;
    } finally {
      client.destroy();
    }
  }
}
