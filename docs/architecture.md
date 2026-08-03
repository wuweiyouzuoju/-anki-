# jidecards 架构总览

> 本文件是「记得卡片」（jidecards）项目的结构可视化入口，描述调用链路、目录
> 组织、模块职责和等价性边界。更新代码时请同步更新本文件。源码以
> [docs/DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) 为准。

## 1. 项目定位

- **是什么**：鸿蒙手机/平板的本地卡片学习软件，独立品牌，AGPL-3.0-or-later
- **复用什么**：Anki 26.05 的 Rust backend（`rslib`），通过 Node-API + 窄 C ABI 调用
- **不复用什么**：不引入 Qt、Python、桌面 Add-on、mpv、桌面 LaTeX；不使用 Anki 商标
- **当前阶段**：M8 本地学习闭环 Alpha（2026-07-18）；同步/浏览/统计/图像遮挡为 post-release

## 2. 端到端调用链

```
┌─────────────────────────────────────────────────────────────────┐
│  ArkUI 页面层（entry/src/main/ets/pages/）                       │
│    Index.ets            首页：牌组树 / 今日统计 / 学习入口        │
│    StudyPage.ets        复习页：队列 → 渲染 → 答题 → 重排        │
└──────────────────────────┬──────────────────────────────────────┘
                           │ 直接持有 Service 实例
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Service 层（entry/src/main/ets/backend/）                       │
│    DeckService / NoteService / SchedulerService /                │
│    CardRenderingService / CollectionService /                   │
│    DeckConfigService / NotetypeService /                        │
│    StatsService / DataTransferService                           │
│  职责：proto 编解码 + 经 BackendSession 调用；不持有 UI 状态     │
└──────────────────────────┬──────────────────────────────────────┘
                           │ BackendSession.run(service, method, input)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  BackendSession（单例）                                          │
│  职责：幂等打开 backend + collection、统一错误类型化             │
│  状态：closed / collectionClosed / ready                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │ BackendClient.run(...)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  BackendClient（entry/src/main/ets/backend/BackendClient.ts）    │
│  仅 3 方法：open / run / close                                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ import { runMethodRaw } from 'libjidecards.so'
                           │   Node-API 异步桥
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  napi_bridge（native/napi_bridge/，C++）                         │
│  index.d.ts 仅 3 个导出函数：                                    │
│    openBackend(init: Uint8Array): number                         │
│    runMethodRaw(handle, service, method, input): Promise<bytes>  │
│    closeBackend(handle: number): void                            │
│  纯转发，零业务逻辑                                              │
└──────────────────────────┬──────────────────────────────────────┘
                           │ C ABI
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  rsharmony（native/rsharmony/，Rust）                            │
│  BackendRegistry：按 (service, method) 路由到注册的 RawBackend   │
│  AnkiBuffer：堆所有权转移（Rust 分配 / FFI 释放函数回收）        │
│  panic 在 FFI 内 catch_unwind，绝不跨语言边界                    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Anki 26.05 Rust Core（third_party/anki/rslib/）                │
│  真正实现：SM-2 / FSRS / 队列 / 调度 / 模板渲染 / SQLite / 同步  │
└─────────────────────────────────────────────────────────────────┘
```

## 3. 目录结构

```
jidecards/
├── AppScope/                      应用级配置（app.json5）
├── entry/                         ArkTS 入口模块
│   └── src/main/
│       ├── cpp/CMakeLists.txt     C++ 侧 CMake
│       ├── ets/                   ArkTS 源码（详见下表）
│       └── module.json5           模块清单
├── native/                        原生层
│   ├── napi_bridge/               Node-API C++ 桥
│   │   ├── index.d.ts             TS 声明（3 个函数）
│   │   └── src/native_module.cpp  实现
│   ├── rsharmony/                 Rust C ABI
│   │   ├── src/lib.rs             BackendRegistry / AnkiBuffer
│   │   └── include/rsharmony.h    C 头
│   └── ohos_compat/qsort_r.c      OHOS 兼容垫片
├── third_party/anki/              Anki 上游 submodule（26.05）
│   ├── rslib/                     Rust 核心（调度/模板/存储/同步）
│   ├── pylib/                     Python 绑定（本项目不使用）
│   ├── qt/                        Qt 桌面客户端（本项目不使用）
│   ├── proto/anki/*.proto         protobuf 协议定义
│   └── ftl/                       Fluent 本地化模板
├── tools/                         构建与测试
│   ├── build-app.ps1              完整构建（Rust + OHOS + Hvigor）
│   ├── build-native.ps1           仅 Rust 原生库
│   ├── doctor.mjs                 工具链诊断
│   └── tests/*.test.mjs           16 个 Node 契约测试
├── docs/                          文档
│   ├── DEVELOPMENT_PLAN.md        6 阶段开发计划（实施依据）
│   ├── IMPLEMENTATION_STATUS.md   阶段门状态
│   ├── DEBUGGING_GUIDE.md         调试指南
│   ├── SERVICE_EXTENSION_GUIDE.md ServiceExtension 指南
│   └── architecture.md            本文件
├── Cargo.toml / Cargo.lock        Rust 工作区
├── build-profile.json5            Hvigor 构建配置
├── rust-toolchain.toml            Rust 1.92.0 锁定
└── README.md                      项目入口
```

## 4. ArkTS 应用层模块职责

| 子目录 | 文件数 | 职责 |
| --- | --- | --- |
| `ets/backend/` | 12 | Service 层：每个 Service 封装一个 Anki 域的 proto 编解码 + session 调用；BackendSession 单例管理句柄；errors 类型化 NAPI 错误；ServiceIds 集中所有服务/方法编号 |
| `ets/components/` | 17 | ArkUI 组件：DeckListItem / CreateDeckPanel / AddNotePanel / DeckDetailPane / StudyFloatingToolbar / TodaySummaryCard / MemorySummaryCard / MonthCalendarCard / SettingsPanel / LicensesPanel 等 |
| `ets/entryability/` | 1 | EntryAbility：应用入口，初始化 BackendSession 与 AppStorage |
| `ets/model/` | 14 | 状态与映射：HomeModels / HomeSnapshotMapper / DeckHierarchy / DeckMetaStore / ThemeStore / ThemeSettings / LanguageStore / FsrsController / StudyCardHtmlBuilder / StudyLayoutStore / DeckConfigForm / DeckOptionsEdit / CalendarModels / DataTransferModels |
| `ets/pages/` | 2 | 页面：Index（首页）+ StudyPage（复习页） |
| `ets/proto/core/` | 3 | protobuf 编解码：ProtoReader / ProtoWriter / utf8 |
| `ets/proto/messages/` | 10 | 按服务拆分的消息编解码：BackendMessages / CollectionMessages / DeckMessages / DeckConfigMessages / NoteMessages / NotetypeMessages / SchedulerMessages / CardRenderingMessages / StatsMessages / ImportExportMessages |
| `ets/utils/` | 7 | 工具：AppDimens（尺寸 token）/ SoundPlayer / TtsPlayer / TtsVoiceHelper / MediaResponseHelper / FileImportHelper / ThemeController |

## 5. Backend 服务与方法编号（绑定 Anki 26.05）

> 来源：`target/**/build/anki-*/out/backend.rs` 的 `run_backend_*_service_method`
> match 分支。与 AnkiDroid 同源规则。升级 Anki 版本时必须重新提取本表。

| Service | ID | 已使用方法 |
| --- | --- | --- |
| `BACKEND_COLLECTION` | 3 | OPEN(0) / CLOSE(1) / CREATE_BACKUP(2) / AWAIT_BACKUP_COMPLETION(3) / LATEST_PROGRESS(4) / SET_WANTS_ABORT(5) / CHECK_DATABASE(6) / GET_UNDO_STATUS(7) / UNDO(8) / REDO(9) |
| `BACKEND_DECKS` | 7 | NEW_DECK(0) / ADD_DECK(1) / DECK_TREE(4) / GET_DECK_NAMES(13) / RENAME_DECK(18) / SET_CURRENT_DECK(22) / GET_CURRENT_DECK(23) |
| `BACKEND_DECK_CONFIG` | 11 | GET_DECK_CONFIG(1) / GET_DECK_CONFIGS_FOR_UPDATE(6) / UPDATE_DECK_CONFIGS(7) |
| `BACKEND_SCHEDULER` | 13 | GET_QUEUED_CARDS(3) / ANSWER_CARD(4) / SCHED_TIMING_TODAY(5) / COUNTS_FOR_DECK_TODAY(10) / CONGRATS_INFO(11) / RESTORE_BURIED_AND_SUSPENDED(12) / UNBURY_DECK(13) / BURY_OR_SUSPEND(14) / DESCRIBE_NEXT_STATES(24) |
| `BACKEND_NOTETYPES` | 23 | GET_NOTETYPE(6) / GET_NOTETYPE_NAMES(8) |
| `BACKEND_NOTES` | 25 | NEW_NOTE(0) / ADD_NOTE(1) / DEFAULTS_FOR_ADDING(3) / NOTE_FIELDS_CHECK(11) |
| `BACKEND_CARD_RENDERING` | 27 | EXTRACT_AV_TAGS(3) / RENDER_EXISTING_CARD(6) |
| `BACKEND_IMPORT_EXPORT` | 39 | IMPORT_COLLECTION_PACKAGE(0) / EXPORT_COLLECTION_PACKAGE(1) / IMPORT_ANKI_PACKAGE(2) / EXPORT_ANKI_PACKAGE(4) |
| `BACKEND_STATS` | 43 | CARD_STATS(0) / GET_REVIEW_LOGS(1) / GRAPHS(2) / GET_GRAPH_PREFERENCES(3) / SET_GRAPH_PREFERENCES(4) |

## 6. 学习链路时序

```
用户点击牌组「开始学习」
  ↓
Index.ets: pathStack.pushPath({ name: 'StudyPage', param: { deckId, deckName } })
  ↓
StudyPage.aboutToAppear():
  1. BackendSession.ensureOpen(context.filesDir)        // 幂等打开 backend + collection
  2. SchedulerService.getQueuedCards(deckId):
     a. DECKS.SET_CURRENT_DECK(deckId)                  // Anki 队列按当前牌组构建
     b. SCHEDULER.GET_QUEUED_CARDS(fetchLimit=1)        // 取队首 1 张
     c. 返回 QueuedCardsView { cards: [StudyCard], newCount, learningCount, reviewCount }
  3. 若 cards 为空 → phase = 'done'，调用 congratsInfo() 取完成页数据
  4. 否则取第一张：
     a. CardRenderingService.renderExistingCard(cardId) // 后端渲染 HTML 节点流
     b. SchedulerService.describeNextStates(states)     // 后端生成 4 档按钮本地化文案
     c. buildCardHtml(rendered, 'question')             // ArkTS 拼装正面 HTML
     d. Web 组件 loadData(questionHtml, ..., MEDIA_BASE_URL)
     e. phase = 'question'
  ↓
用户点击「显示答案」
  ↓
  1. buildCardHtml(rendered, 'answer') → loadData(...)
  2. phase = 'answer'
  3. 若卡片带音频：SoundPlayer.playQueue(...) 串行播放
  ↓
用户点击评分按钮（Again/Hard/Good/Easy）
  ↓
  1. answering = true  // 重入保护
  2. SchedulerService.answerCard({
       cardId, rating,
       currentState: states.current,    // raw passthrough（关键！）
       newState: states.{again|hard|good|easy}  // raw passthrough
     })
  3. 后端落库 + 重排队列
  4. 回到第 2 步取下一张
  ↓
队列空 → phase = 'done' → 显示完成页
  ↓
用户返回 → pathStack.pop() → Index.onPop → loadHomeData() 刷新首页
```

## 7. 与 Anki 26.05 的等价性边界

### 7.1 等价性保证（架构层面）

- **服务/方法编号硬编码自 Anki 26.05 backend.rs**（[ServiceIds.ts](../entry/src/main/ets/backend/ServiceIds.ts)）
- **rsharmony 与 napi_bridge 是纯转发层**，零业务逻辑
- **状态字节 raw passthrough**：[SchedulerMessages.ts](../entry/src/main/ets/proto/messages/SchedulerMessages.ts) 头注释：
  > SchedulingState 是深层 oneof 结构（New/Learning/Review/Relearning/Filtered…），
  > 前端不需要理解其内容——按钮文案由后端 DescribeNextStates 给出。因此解码时
  > 把每个状态的原始字节原样保留（raw passthrough），作答时原样回写。

**结论**：SM-2 / FSRS / 队列选择 / 埋藏暂停恢复 / 完成页判定 / 按钮文案本地化，全部由 Anki Rust core 计算，ArkTS 层一行调度算法都没写。

### 7.2 已知非等价边界

| # | 边界 | 实际差异 | 影响 |
| --- | --- | --- | --- |
| 1 | **队列预取** | jidecards 每次 `fetchLimit=1`；桌面 Anki 预取多张做缓冲 | 调度结果等价，仅性能/交互细节差异（本地库影响可忽略） |
| 2 | **FSRS 自动启用策略** | [FsrsController.ets](../entry/src/main/ets/model/FsrsController.ets) 在 App 首次启动时若 `fsrs=false` 自动开启一次，并写 `fsrs_initialized` 标记 | 单卡算法等价；初始默认值策略与桌面略有差异（用户可手动关掉） |
| 3 | **金标准差分测试未做** | DEVELOPMENT_PLAN.md §8 规划了"同 collection 在官方 Anki 26.05 与本项目执行固定时区/随机种子/操作序列后比较"，但设备门未通过 | **理论等价，但尚未用对照实验证明过** |
| 4 | **功能集是 Anki 的子集** | filtered deck / cram / 图像遮挡 / 统计图表 / 浏览器均为 post-release | **标准学习模式下等价**，非标准模式尚未实现 |

## 8. 测试矩阵

| 测试类型 | 命令 | 覆盖范围 |
| --- | --- | --- |
| Node 契约测试 | `npm test` | 94 个测试：proto 编解码字节级 vector、Service 调用契约、StudyPage 完整链路、媒体 URL 重写、SoundPlayer 串行队列等 |
| 工具链诊断 | `npm run doctor` | Rust 版本、SDK、ABI 目标、签名配置 |
| Rust FFI 主机测试 | `tools\build-native.ps1 -Target host-test` | rsharmony 注册表 + Anki 26.05 真实 core 联调 |
| 完整构建 | `npm run build:app` | Rust + OHOS + Hvigor 全链路 |
| Release HAP | `tools\build-app.ps1 -Architecture arm64 -BuildMode release` | thin LTO + strip + arm64-v8a only，约 43.6 MB |

### 未通过的设备门（release-blocking）

- [ ] 应用在 HarmonyOS 5.0.0（API 12）上安装并启动
- [ ] collection 可在设备上打开、修改、关闭、重开
- [ ] smoke test 后 SQLite integrity check 通过
- [ ] 两个目标架构各 1,000 次 open/call/close 循环通过
- [ ] API 12 手机/平板通过学习、导入导出、备份恢复测试

## 9. 关键设计决策摘要

| 决策 | 原因 | 来源 |
| --- | --- | --- |
| 字节级 raw passthrough 调度状态 | 避免在前端维护一份易过期的 oneof 重编码 | [SchedulerMessages.ts](../entry/src/main/ets/proto/messages/SchedulerMessages.ts) |
| 自建 `https://jidecards-media.local/` 媒体域名 | 绕过 ArkWeb `file://` 协议跨域拦截，由 `onInterceptRequest` 映射到沙箱 `collection.media/` | [StudyPage.ets](../entry/src/main/ets/pages/StudyPage.ets) |
| BackendSession 单例 + 幂等打开 | 多 Service 共享一个 collection 句柄；并发调用共享同一次打开过程 | [BackendSession.ts](../entry/src/main/ets/backend/BackendSession.ts) |
| Navigation + NavPathStack（非 router） | API 12 推荐写法，router 已废弃 | [Index.ets](../entry/src/main/ets/pages/Index.ets) |
| FSRS 首次启动自动开启 | Anki 24.04 起官方推荐默认开启 FSRS | [FsrsController.ets](../entry/src/main/ets/model/FsrsController.ets) |
| Service 不持有 UI 状态 | UI 通过 `isReady()` 感知就绪；Service 失败抛 `BackendError` 由 UI 决定回滚 | [errors.ts](../entry/src/main/ets/backend/errors.ts) |
| panic 在 FFI 内 catch_unwind | 绝不跨语言边界 panic；返回 `STATUS_NATIVE_FATAL` 由 ArkTS 类型化 | [rsharmony/src/lib.rs](../native/rsharmony/src/lib.rs) |

## 10. 进一步阅读

- [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) — 6 阶段实施计划与验收门
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — 当前阶段门状态
- [DEBUGGING_GUIDE.md](DEBUGGING_GUIDE.md) — 调试与故障定位
- [SERVICE_EXTENSION_GUIDE.md](SERVICE_EXTENSION_GUIDE.md) — ServiceExtension 配置
- Anki 上游：[third_party/anki/rslib/src/](../third_party/anki/rslib/src/)
- Proto 定义：[third_party/anki/proto/anki/](../third_party/anki/proto/anki/)
