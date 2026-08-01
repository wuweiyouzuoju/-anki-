// SPDX-License-Identifier: AGPL-3.0-or-later

import type { ImportSummary } from '../proto/messages/ImportExportMessages';

export interface 牌组导出选项 {
  withScheduling: boolean;
  withDeckConfigs: boolean;
  withMedia: boolean;
  legacy: boolean;
}

export interface 整库导出选项 {
  includeMedia: boolean;
  legacy: boolean;
}

export type { ImportSummary as 导入汇总 };
