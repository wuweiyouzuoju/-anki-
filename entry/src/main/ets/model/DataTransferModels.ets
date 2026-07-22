import type { ImportSummary } from '../proto/messages/ImportExportMessages';

export interface DeckExportOptions {
  withScheduling: boolean;
  withDeckConfigs: boolean;
  withMedia: boolean;
  legacy: boolean;
}

export interface CollectionExportOptions {
  includeMedia: boolean;
  legacy: boolean;
}

export type { ImportSummary };
