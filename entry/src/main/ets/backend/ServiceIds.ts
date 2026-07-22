// SPDX-License-Identifier: AGPL-3.0-or-later

// 服务/方法索引常量（唯一来源）。
// 提取自 Rust 构建产物 target/**​/build/anki-*​/out/backend.rs 的
// run_backend_*_service_method match 分支，与 AnkiDroid 同源规则，绑定 Anki 26.05。
// 升级 Anki 版本时必须按 docs/superpowers/plans 中的 SOP 重新提取本表。

export const SERVICE = {
  // 编号来自 backend.rs line 6668 的 Backend 分派表（奇数 1/3/5/.../45，跳过 31）
  BACKEND_SYNC: 1,
  BACKEND_COLLECTION: 3,
  BACKEND_CARDS: 5,
  BACKEND_DECKS: 7,
  BACKEND_CONFIG: 9,
  BACKEND_DECK_CONFIG: 11,
  BACKEND_SCHEDULER: 13,
  BACKEND_ANKIDROID: 15,
  BACKEND_ANKI_HUB: 17,
  BACKEND_ANKIWEB: 19,
  BACKEND_LINKS: 21,
  BACKEND_NOTETYPES: 23,
  BACKEND_NOTES: 25,
  BACKEND_CARD_RENDERING: 27,
  BACKEND_SEARCH: 29,
  BACKEND_GITHUB: 33,
  BACKEND_I18N: 35,
  BACKEND_IMAGE_OCCLUSION: 37,
  BACKEND_IMPORT_EXPORT: 39,
  BACKEND_MEDIA: 41,
  BACKEND_STATS: 43,
  BACKEND_TAGS: 45
} as const;

/** BackendCollectionService 方法索引 */
export const COLLECTION_METHOD = {
  OPEN: 0,
  CLOSE: 1,
  CREATE_BACKUP: 2,
  AWAIT_BACKUP_COMPLETION: 3,
  LATEST_PROGRESS: 4,
  SET_WANTS_ABORT: 5,
  CHECK_DATABASE: 6,
  GET_UNDO_STATUS: 7,
  UNDO: 8,
  REDO: 9
} as const;

/** BackendDecksService 方法索引 */
export const DECKS_METHOD = {
  NEW_DECK: 0,
  ADD_DECK: 1,
  DECK_TREE: 4,
  GET_DECK_NAMES: 13,
  REMOVE_DECKS: 16,
  RENAME_DECK: 18,
  SET_CURRENT_DECK: 22,
  GET_CURRENT_DECK: 23
} as const;

/** BackendDeckConfigService 方法索引 */
export const DECK_CONFIG_METHOD = {
  GET_DECK_CONFIG: 1,
  GET_DECK_CONFIGS_FOR_UPDATE: 6,
  UPDATE_DECK_CONFIGS: 7
} as const;

/** BackendSchedulerService 方法索引 */
export const SCHEDULER_METHOD = {
  GET_QUEUED_CARDS: 3,
  ANSWER_CARD: 4,
  SCHED_TIMING_TODAY: 5,
  COUNTS_FOR_DECK_TODAY: 10,
  CONGRATS_INFO: 11,
  RESTORE_BURIED_AND_SUSPENDED: 12,
  UNBURY_DECK: 13,
  BURY_OR_SUSPEND: 14,
  DESCRIBE_NEXT_STATES: 24
} as const;

/** BackendCardRenderingService 方法索引 */
export const CARD_RENDERING_METHOD = {
  EXTRACT_AV_TAGS: 3,
  RENDER_EXISTING_CARD: 6
} as const;

/** BackendNotetypesService method indexes from Anki 26.05 backend.rs. */
export const NOTETYPES_METHOD = {
  GET_NOTETYPE: 6,
  GET_NOTETYPE_NAMES: 8
} as const;

/** BackendNotesService method indexes from Anki 26.05 backend.rs. */
export const NOTES_METHOD = {
  NEW_NOTE: 0,
  ADD_NOTE: 1,
  DEFAULTS_FOR_ADDING: 3,
  NOTE_FIELDS_CHECK: 11
} as const;

/** BackendImportExportService 方法索引 */
export const IMPORT_EXPORT_METHOD = {
  IMPORT_COLLECTION_PACKAGE: 0,
  EXPORT_COLLECTION_PACKAGE: 1,
  IMPORT_ANKI_PACKAGE: 2,
  EXPORT_ANKI_PACKAGE: 4
} as const;

/** BackendStatsService 方法索引（backend.rs run_backend_stats_service_method 分支） */
export const STATS_METHOD = {
  CARD_STATS: 0,
  GET_REVIEW_LOGS: 1,
  GRAPHS: 2,
  GET_GRAPH_PREFERENCES: 3,
  SET_GRAPH_PREFERENCES: 4
} as const;

/** BackendSyncService 方法索引（backend.rs run_backend_sync_service_method 分支，line 2944） */
export const SYNC_METHOD = {
  SYNC_MEDIA: 0,
  ABORT_MEDIA_SYNC: 1,
  MEDIA_SYNC_STATUS: 2,
  SYNC_LOGIN: 3,
  SYNC_STATUS: 4,
  SYNC_COLLECTION: 5,
  FULL_UPLOAD_OR_DOWNLOAD: 6,
  ABORT_SYNC: 7,
  SET_CUSTOM_CERTIFICATE: 8
} as const;

/** BackendCardsService 方法索引（backend.rs run_backend_cards_service_method 分支，line 3231） */
export const CARDS_METHOD = {
  GET_CARD: 0,
  UPDATE_CARDS: 1,
  REMOVE_CARDS: 2,
  SET_DECK: 3,
  SET_FLAG: 4
} as const;

/** BackendConfigService 方法索引（backend.rs run_backend_config_service_method 分支，line 3720） */
export const CONFIG_METHOD = {
  GET_CONFIG_JSON: 0,
  SET_CONFIG_JSON: 1,
  SET_CONFIG_JSON_NO_UNDO: 2,
  REMOVE_CONFIG: 3,
  GET_ALL_CONFIG: 4,
  GET_CONFIG_BOOL: 5,
  SET_CONFIG_BOOL: 6,
  GET_CONFIG_STRING: 7,
  SET_CONFIG_STRING: 8,
  GET_PREFERENCES: 9,
  SET_PREFERENCES: 10
} as const;

/** BackendAnkidroidService 方法索引（backend.rs run_backend_ankidroid_service_method 分支，line 4698） */
export const ANKIDROID_METHOD = {
  SCHED_TIMING_TODAY_LEGACY: 0,
  LOCAL_MINUTES_WEST_LEGACY: 1,
  SET_PAGE_SIZE: 2,
  DEBUG_PRODUCE_ERROR: 3,
  RUN_DB_COMMAND: 4,
  RUN_DB_COMMAND_PROTO: 5,
  INSERT_FOR_ID: 6,
  RUN_DB_COMMAND_FOR_ROW_COUNT: 7,
  FLUSH_ALL_QUERIES: 8,
  FLUSH_QUERY: 9,
  GET_NEXT_RESULT_PAGE: 10,
  GET_COLUMN_NAMES_FROM_QUERY: 11,
  GET_ACTIVE_SEQUENCE_NUMBERS: 12
} as const;

/** BackendAnkiHubService 方法索引（backend.rs run_backend_anki_hub_service_method 分支，line 4833） */
export const ANKI_HUB_METHOD = {
  ANKIHUB_LOGIN: 0,
  ANKIHUB_LOGOUT: 1
} as const;

/** BackendAnkiwebService 方法索引（backend.rs run_backend_ankiweb_service_method 分支，line 4870） */
export const ANKIWEB_METHOD = {
  GET_ADDON_INFO: 0,
  CHECK_FOR_UPDATE: 1
} as const;

/** BackendLinksService 方法索引（backend.rs run_backend_links_service_method 分支，line 4909） */
export const LINKS_METHOD = {
  HELP_PAGE_LINK: 0
} as const;

/** BackendSearchService 方法索引（backend.rs run_backend_search_service_method 分支，line 5829） */
export const SEARCH_METHOD = {
  BUILD_SEARCH_STRING: 0,
  SEARCH_CARDS: 1,
  SEARCH_NOTES: 2,
  JOIN_SEARCH_NODES: 3,
  REPLACE_SEARCH_NODE: 4,
  FIND_AND_REPLACE: 5,
  ALL_BROWSER_COLUMNS: 6,
  BROWSER_ROW_FOR_ID: 7,
  SET_ACTIVE_BROWSER_COLUMNS: 8
} as const;

/** BackendGithubService 方法索引（backend.rs run_backend_github_service_method 分支，line 5928） */
export const GITHUB_METHOD = {
  GET_LATEST_RELEASE: 0,
  DOWNLOAD_RELEASE: 1
} as const;

/** BackendI18nService 方法索引（backend.rs run_backend_i18n_service_method 分支，line 5973） */
export const I18N_METHOD = {
  TRANSLATE_STRING: 0,
  FORMAT_TIMESPAN: 1,
  I18N_RESOURCES: 2
} as const;

/** BackendImageOcclusionService 方法索引（backend.rs run_backend_image_occlusion_service_method 分支，line 6054） */
export const IMAGE_OCCLUSION_METHOD = {
  GET_IMAGE_FOR_OCCLUSION: 0,
  GET_IMAGE_OCCLUSION_NOTE: 1,
  GET_IMAGE_OCCLUSION_FIELDS: 2,
  ADD_IMAGE_OCCLUSION_NOTETYPE: 3,
  ADD_IMAGE_OCCLUSION_NOTE: 4,
  UPDATE_IMAGE_OCCLUSION_NOTE: 5
} as const;

/** BackendMediaService 方法索引（backend.rs run_backend_media_service_method 分支，line 6359） */
export const MEDIA_METHOD = {
  CHECK_MEDIA: 0,
  ADD_MEDIA_FILE: 1,
  TRASH_MEDIA_FILES: 2,
  EMPTY_TRASH: 3,
  RESTORE_TRASH: 4,
  EXTRACT_STATIC_MEDIA_FILES: 5
} as const;

/** BackendTagsService 方法索引（backend.rs run_backend_tags_service_method 分支，line 6555） */
export const TAGS_METHOD = {
  CLEAR_UNUSED_TAGS: 0,
  ALL_TAGS: 1,
  REMOVE_TAGS: 2,
  SET_TAG_COLLAPSED: 3,
  TAG_TREE: 4,
  REPARENT_TAGS: 5,
  RENAME_TAGS: 6,
  ADD_NOTE_TAGS: 7,
  REMOVE_NOTE_TAGS: 8,
  FIND_AND_REPLACE_TAG: 9,
  COMPLETE_TAG: 10
} as const;

/** native/napi_bridge 的错误状态码，与 rsharmony.h ANKI_STATUS_* 一一对应 */
export const NATIVE_STATUS = {
  OK: 0,
  INVALID_ARGUMENT: 1,
  HANDLE_NOT_FOUND: 2,
  BACKEND_ERROR: 3,
  NATIVE_FATAL: 4
} as const;
