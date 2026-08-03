# jidecards 鸿蒙手机/平板开发计划

## 1. 已锁定的兼容基线

本文件是实施和阶段验收的正式依据。版本基线如下：

| 项目 | 锁定值 | 含义 |
| --- | --- | --- |
| 最低系统版本 | HarmonyOS 5.0.0（API 12） | 安装、运行和发布兼容底线 |
| compileSdkVersion | API 23 | 编译所用 SDK |
| targetAPIVersion | API 23 | 目标平台行为基线 |
| Anki Core | 26.05，`e64c6b1aee3e8d668fb8bbe084beada8e070d985` | 数据和学习行为基准 |
| Rust | 1.92.0 | 可重复构建基线 |
| DevEco Studio | 6.1.0.860 | IDE 基线 |
| HarmonyOS SDK | 6.1.0.105 | SDK 基线 |
| 原生目标 | `aarch64-unknown-linux-ohos`、`x86_64-unknown-linux-ohos` | 真机与模拟器 |

API 23 是编译和目标 SDK，不是最低安装版本。所有 API 13～23
能力必须经过运行时版本或能力检查；缺少能力时使用 API 12 实现、降级
实现，或隐藏不影响核心学习的增强功能。牌组打开、学习、编辑、搜索、
导入导出、备份恢复和数据库检查不得依赖 API 13 以上能力。

## 2. 产品目标与边界

jidecards 是独立品牌、AGPL-3.0-or-later 授权的鸿蒙本地卡片学习
软件。它复用 Anki 26.05 Rust backend，以 ArkTS/ArkUI 实现手机和平板
界面，通过 Node-API 和窄 C ABI 连接 Rust。项目不引入 Qt、Python、
桌面 Add-on、mpv 或桌面 LaTeX 环境，也不使用 Anki 商标使用户误认为
它是官方客户端。

“低风险”是可验证的工程约束，不是绝对承诺。任何可能破坏用户数据的
操作都必须先备份、在 staging 或临时 profile 验证、失败即停止，并具有
经过测试的恢复路径。同步在完整本地兼容通过前保持关闭。

## 3. 兼容范围

核心目标包括：

- `collection.anki2`、`collection.anki21`、`collection.anki21b`，以及
  collection schema 11～18 的读取和升级。
- `.apkg` 导入导出，`.colpkg` 备份、恢复和迁移。
- 旧 JSON media map，以及 Protobuf/Zstandard 新格式。
- Deck、Note、Card、Tag、Flag、Filtered Deck、Anki 搜索语法。
- SM-2 兼容状态、FSRS、完整学习队列、撤销、埋藏、暂停和重排。
- HTML/CSS/JavaScript 模板、图片、音频、视频、`[sound:...]`、TTS、
  本地 MathJax、输入答案和图像遮挡。
- 浏览、编辑、统计、媒体检查、数据库检查和多 profile。
- 最终阶段的 AnkiWeb 普通同步、单向同步和媒体同步。

## 4. 架构和安全边界

调用链固定为：

```text
ArkUI 页面 -> ViewModel/UseCase -> 生成的 ArkTS BackendClient
           -> Node-API 异步桥 -> rsharmony C ABI -> Anki Rust Core
```

ArkTS 不读取或写入 collection SQLite。每个 profile 独占 collection、
media database、媒体、备份、safety snapshot 和 staging 目录。普通 backend
调用按 collection 串行执行；ArkTS 只持有 32 位不透明 handle，不接触 Rust
指针。panic 必须在 Rust FFI 内捕获，返回缓冲区只由 Rust 提供的释放函数
回收。

卡片使用 ArkWeb 渲染，但页面不注册原生对象。媒体只通过受控的
`https://anki.local/media/` 地址访问；禁止路径穿越、符号链接逃逸和模板
主动联网。外部链接只能在用户确认后交给系统浏览器。MathJax 随应用本地
打包，音频和 TTS 由 ArkTS 系统能力执行。

## 5. API 12～23 兼容策略

### 5.1 编码规则

- 工程配置必须写明 `minAPIVersion = 12`、`targetAPIVersion = 23`，并以
  API 23 SDK 编译。
- 每次使用 API 13～23 新增接口时，代码审查必须记录引入版本、能力探测、
  API 12 fallback 和测试用例。
- 模块加载阶段不得静态触发高版本设备上不存在的符号；高版本适配代码需
  延迟到能力检查之后执行。
- 无 fallback 的增强功能必须在 API 12 隐藏，并且不能阻断本地学习闭环。
- Node-API、ArkWeb、文件选择器、音频、TTS、密钥存储、网络和后台任务都
  建立独立的兼容性适配层，业务层不得直接散落版本判断。

### 5.2 发布阻断设备矩阵

| 系统/API | 设备形态 | 必测范围 |
| --- | --- | --- |
| HarmonyOS 5.0.0 / API 12 | 手机真机 | 安装、冷启动、学习、编辑、导入导出、备份恢复、ArkWeb、音频 |
| HarmonyOS 5.0.0 / API 12 | 平板真机 | 双栏/三栏退化、键鼠、同一数据安全测试 |
| API 23 | 手机真机 | 全功能、性能、权限、前后台切换 |
| API 23 | 平板真机 | 三栏、触控笔、键鼠、全功能 |
| API 23 | x86_64 模拟器 | CI 冒烟、故障注入和自动回归 |

API 12 设备上的启动、collection 打开、回答并持久化、导入、导出、备份、
恢复或数据库检查任一失败，都阻止发布。只在 API 23 通过不视为兼容完成。

## 6. 数据操作协议

导入先由文件选择器复制到 staging，同时计算 SHA-256、检查大小和空间；
随后停止写入、强制备份，再调用 Rust importer。成功后执行数据库与媒体
检查、重开 collection，最后清理 staging。失败时恢复备份并保留经过脱敏
的错误报告。

`.colpkg` 必须导入独立临时 profile，检查通过后原子切换，不能覆盖正在
使用的 collection。导出先写沙箱临时文件，fsync、重开验证并计算 SHA-256，
再复制到用户 URI；目标写入失败时保留临时副本以便重试。

collection 有变更时每 12 小时最多自动备份一次，保留 14 个日备份、8 个
周备份和 6 个月备份。schema 升级、恢复和数据库修复前强制 safety
snapshot。空间不足以完成备份时，危险操作必须停止。

## 7. 分阶段实施与退出门

### 阶段 0：法律、仓库和可重复构建（1～2 周）

完成独立品牌、AGPL/第三方 notice、Anki submodule、依赖锁定、环境检查和
产物版本元数据。全新 Windows 开发机必须能按文档确定性构建。

### 阶段 1：OHOS 可行性验证（2～3 周）

交叉编译真实 Anki backend 到 ARM64 和 x86_64 OHOS，完成 C ABI 与
Node-API 冒烟，在 API 12 与 API 23 设备上创建/导入 collection、渲染并回答
卡片、重启验证 revlog。两个架构各运行 1,000 次 open/call/close，无崩溃、
泄漏或 integrity check 错误才可进入正式 UI。

### 阶段 2：平台基础与数据安全（3～4 周）

生成 Proto/ArkTS 类型和 BackendClient，实现队列、取消、进度、profile、
staging、备份恢复、URI 适配、隐私错误和冷启动事务恢复。强杀、磁盘满、
损坏 ZIP、非法路径和权限丢失不得改变原 collection。

### 阶段 3：本地学习闭环 Alpha（6～8 周）

实现牌组树、队列、评分、FSRS、撤销、HTML/CSS/JS、媒体、TTS、MathJax、
输入答案、基础/反向/填空、编辑、包导入恢复，以及手机/平板自适应。
不启用同步，只允许测试 collection。10,000 次状态差分、50 套模板金标准、
schema 11～18 和 100 次包往返全部通过后退出。

### 阶段 4：完整本地兼容 Beta（8～10 周）

加入浏览器、搜索、批处理、笔记类型/模板、Filtered Deck、完整 FSRS 选项、
图像遮挡、重复/空卡检查、统计、多 profile 和平板三栏。压力集合目标为
100 万 revlog、10 万 notes 和 1 万媒体；72 小时随机操作与强杀测试不得出现
数据损坏。

### 阶段 5：AnkiWeb 同步（6～8 周）

先验证 Rust TLS；如 OHOS 上不稳定，只抽象 HTTP transport 给 Harmony
Network Kit，同步协议和状态机仍留在 Rust。依次开放测试服务器、测试账号、
临时 profile 下载、小范围双向、手动 Beta，最终才默认启用。单向同步前
必须备份并明确展示被覆盖端。

### 阶段 6：发布与维护（4～6 周）

完成真机矩阵、耗电温升、无障碍、隐私、恢复演练和应用市场材料，以
1%、5%、20%、50%、100% 灰度发布。任何数据完整性异常立即停止灰度。

## 8. 测试与长期维护

金标准集合覆盖 schema 11～18、新旧包格式、多语言和 Unicode、复杂模板、
媒体异常、SM-2/FSRS、过滤牌组和同步冲突。同一 collection 在官方 Anki
26.05 与本项目执行固定时区、随机种子和操作序列，规范化 volatile 字段后
比较 notes、cards、revlog、graves、配置、搜索、调度和媒体 SHA-1。

故障注入覆盖写卡、schema 升级、解压、profile 切换和媒体复制中的强杀或
空间耗尽，以及 Promise 页面销毁、重复提交、恶意模板、ZIP 路径穿越、
压缩炸弹、数据库/WAL 损坏和 media DB 丢失。

生产构建只跟随 Anki stable tag。每季度在独立分支评估新 stable，先运行
上游 Rust 测试，再检查 Proto、schema、同步、调度、模板和包格式差异，最后
执行全部金标准和差分测试。任一数据差异未解释前继续使用旧核心。

## 9. 最终验收

只有在 schema/包格式、FSRS/调度/搜索、模板/媒体、API 12～23 手机和平板、
导入升级恢复与故障注入、AnkiWeb 三类同步、AGPL 源码与许可证全部通过时，
项目才可声明“完整核心兼容”。任何未通过阶段门的功能必须保持关闭。

## 10. 当前实施记录

截至 2026-07-17，阶段 0/1 已完成可在当前开发机验证的部分：Anki 26.05
submodule 和 Rust 1.92.0 已锁定；真实 Anki Core 的 FFI 主机测试通过；
`librsharmony.a` 与 Node-API `libjidecards.so` 均已构建 ARM64/x86_64 两个
OHOS ABI；ArkUI 工程以最低 API 12、target API 23 通过 ArkTS 编译和 HAP
打包，并在 HAP 内包含两个 ABI。

尚未通过的阶段门保持明确关闭：API 12 手机/平板安装与运行、Node-API
open/call/close 真机冒烟、collection 导入/回答/重启持久化、SQLite 完整性
检查和每架构 1,000 次循环。未完成这些验证前，不开放正式数据导入和同步。
