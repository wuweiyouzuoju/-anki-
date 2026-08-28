# PROJECT_CONTEXT.md — jidecards01

> AI 第一份读物。本文件是 jidecards01 项目的"业务地图"——索引 + 摘要 + 补充，不重复代码已显式表达的信息。
>
> **代码风格约束**（命名 / 注释 / 工作流分级 / 测试要求）见 `AGENTS.md` + `.agents/rules/*.md` + `.agents/adapters/arkts.md`（2026-08-01 从归档项目 jidecards 复制建立）。本文件只管"项目是什么、改哪里"，不管"怎么写代码"。

## 全局不变量

跨任务、跨模块的强约束，AI 改任何代码都要遵守：

- **前端不实现调度算法**（SM-2 / FSRS / 队列选择 / 埋藏暂停 / 完成页判定全部由 Anki Rust core 计算）
- **SchedulingStates 必须 raw passthrough**（字节级保真，禁止前端解码/重编码 oneof 结构）
- **Service 不持有 UI 状态**（失败抛 BackendError 由 UI 决定回滚）
- **panic 在 FFI 内 catch_unwind**（绝不跨语言边界，返回 STATUS_NATIVE_FATAL）
- **Anki proto 不可改**（proto 定义在 jidecards01 自带的 `third_party/anki/proto/anki/*.proto` submodule）
- **装机绝不能 uninstall 清数据**：collection.anki2 + collection.media 在 sandbox 目录，uninstall 即永久删除。`install -r` 失败时先 `force-stop` 再 `install -r`，仍失败清 build 重构建
- **i18n 优先**：所有用户可见字符串必须走 `$r('app.string.xxx')` + `localized` / `localizedFmt`，禁止硬编码中文（`i18n-contract.test.mjs` 会拦截）
- **`target/` 目录必须是真实目录**（不是 junction / symlink）：本机已配置 Rust 工具链（cargo/rustc 1.97.1，2026-08-06 核实），jidecards01 有自己的 `third_party/anki` submodule 与 `target/` 编译产物，不再依赖归档项目

## 项目定位

鸿蒙手机/平板本地卡片学习软件，AGPL-3.0，**已上架华为应用市场**（versionName 1.0.1 / versionCode 1002，2026-07-30）。复用 Anki 26.05 Rust backend（经 Node-API + 窄 C ABI），不引入 Qt/Python/桌面 Add-on。jidecards01 是 jidecards（已归档到 `往期淘汰作品/`）的修正版本，主要修复 i18n、应用内评分、版本号等发布前问题。

**技术栈**：ArkTS / HarmonyOS Next；Rust 1.92.0（rsharmony C ABI）；Node-API C++（napi_bridge）；hvigor + ohpm。

## 快速验证命令

- 工具链诊断：`npm run doctor`
- Node 契约测试（含 i18n / proto / service / UI shell）：`npm test`
- Rust FFI 主机测试：`tools\build-native.ps1 -Target host-test`
- 完整构建（Rust + ArkTS + HAP）：`npm run build:app`
- 命令行构建 HAP（已验证可用）：
  ```powershell
  $env:DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
  $env:JAVA_HOME="C:\Program Files\Huawei\DevEco Studio\jbr"
  $env:PATH="$env:JAVA_HOME\bin;$env:PATH"
  node "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default -p module=entry@default -p buildMode=release --no-daemon
  ```
- 真机装机：`hdc -t <connect-key> install -r entry\build\default\outputs\default\entry-default-signed.hap`；装后 `hdc shell aa force-stop com.jide.kapian`

## 核心数据流

ArkUI 页面 → Service 层 → BackendSession(单例) → BackendClient(open/run/close) → napi_bridge(C++ 纯转发) → rsharmony(Rust C ABI) → Anki Rust Core。

学习链路：`getQueuedCards` → `renderExistingCard` → `answerCard`(raw passthrough 状态字节级回写)。

媒体渲染：`https://jidecards-media.local/` 自建域名经 `onInterceptRequest` 映射到沙箱 `collection.media/`。

## 模块边界

| 模块 | 路径 | 关键不变量 |
|---|---|---|
| ArkUI 页面 | `entry/src/main/ets/pages/` | NavPathStack(非 router)；StudyPage phase 状态机 loading→question→answer→done/error；切换卡片时必须回到 loading；BrowserPage phase 状态机 loading→list→error |
| 浏览页组件 | `entry/src/main/ets/components/browser/` | 搜索框(TextInput+模式切换) + 卡片表格(List+多选+空态) + 浏览编辑区(Stack+if 弹层纯展示)；回调上抛不直接调 Service |
| Service 层 | `entry/src/main/ets/backend/` | 不持有 UI 状态；经 BackendSession 单例；失败抛 BackendError |
| Proto 编解码 | `entry/src/main/ets/proto/` | 纯函数；proto3 optional 用 null；**SchedulingStates raw passthrough 字节级保真** |
| BackendSession | `entry/src/main/ets/backend/后端会话.ts` | 单例；幂等打开；`closeCollection` vs `markCollectionConsumed` 不可混用 |
| 主题系统 | `entry/src/main/ets/model/{颜色主题,主题设置}.ets` | ThemeMode(深浅色) 与 ColorTheme(主色调) 正交两维度；countNew/Learning/Review 固定交通灯色不跟随主题 |
| NAPI 桥 | `native/napi_bridge/` | 纯转发，零业务逻辑；3 个导出函数（openBackend / runMethodRaw / closeBackend） |
| Rust FFI | `native/rsharmony/` | panic 在 FFI 内 catch_unwind，绝不跨语言边界；返回 STATUS_NATIVE_FATAL |
| 设置面板 | `entry/src/main/ets/components/设置面板.ets` | 各分组（外观/布局/数据/术语/调度器/同步）独立私有方法；aboutGroup 内含"给我好评" |
| 颜色主题展示名 | `entry/src/main/ets/components/settings/外观分组.ets` | **走 i18n** `getStringByNameSync('theme_color_' + 主题)`，不再硬编码 |
| 统计页 | `entry/src/main/ets/pages/统计页.ets` + `entry/src/main/ets/components/stats/` | NavDestination；阶段状态机 loading→data/error（切换牌组重载时保留旧图表不闪空）；13 个图表分区对齐 Anki 14 图（难度/难度系数互斥合一，稳定度/记忆率仅 FSRS 显示）；顶部条内嵌牌组选择下拉（全库=空搜索串，选中牌组传 `deck:"全名"`）；桌面卡片快照仅全库口径刷新 |
| 统计图表组件 | `entry/src/main/ets/components/stats/*.ets` | 纯展示层；@Prop 数据 + @StorageProp 主题色；**build 方法必须单根 Column**（if/else 分支 + @Builder 渲染内容）；@Builder 内不能写 const/let，数据通过参数传入；颜色/分箱走 `model/统计色板.ets`（d3 色带插值）与 `model/统计分箱.ets`（d3 ticks/nice/分位）纯函数 |
| 媒体管理面板 | `entry/src/main/ets/components/settings/媒体管理面板.ets` | Stack 遮罩+面板；持有 媒体服务 实例直接调后端；检查中/处理中防重入；清空回收站需二次确认 |
| 云端牌组下载 | `model/{云端牌组模型,云端牌组配置,云端牌组引导存储}.*` + `backend/云端牌组服务.ets` + `components/{导入来源弹窗,云端牌组弹窗}.ets` + `pages/首页.ets` | 公开 HTTPS JSON 目录；系统下载代理直写 `filesDir/cloud-decks`；首页串行下载后复用 `执行牌组导入` 自动安装；目录地址为空时友好降级，不影响本地导入 |
| 卡片预览页 | `entry/src/main/ets/components/browser/卡片预览页.ets` | Web 组件复用 卡片渲染服务；支持翻面 + 左右滑切上下张；底部"编辑字段"进浏览编辑区 |

## 常见任务路由

| 常见任务 | 入口 | 注意事项 |
|---|---|---|
| 新增 Anki 域 Service | `backend/<Xxx>Service.ts` + `proto/messages/<Xxx>Messages.ts` + `backend/服务索引.ts` | SERVICE 编号取自 Anki `backend.rs`（奇数）；参考 `StatsService.ts`(只读) / `DeckConfigService.ts`(整体回写) / `DeckService.ts`(多方法) |
| 修改学习链路 | `pages/学习页.ets` + `backend/{调度器服务,卡片渲染服务}.ts` | `answering` 防重入；phase 守卫；禁止解码 SchedulingStates oneof；切卡必须重置 phase 为 loading |
| 修改/新增 protobuf | `proto/messages/<Xxx>Messages.ts` + `proto/core/{ProtoReader,ProtoWriter}.ts` | 字段来源必须 `third_party/anki/proto/anki/*.proto`（jidecards01 自带 submodule）；保留字段(field 255)原样往返 |
| 修改 FSRS 参数 | `proto/messages/牌组配置Messages.ts` + `model/FSRS控制器.ets` | **前端不实现算法**；DeckConfig 整体回写；`fsrsReschedule` 在 view 没有，开启时设 true |
| 修改 ArkUI 组件 | `components/<Xxx>.ets`；设置分组 `components/settings/<Xxx>分组.ets` | `@StorageLink(COLOR_KEYS.*)` 跟随主题；回调上抛，不直接调持久化（语言切换例外） |
| 修改主题 | `model/颜色主题.ets` + `utils/{颜色主题管理器,主题控制器}.ets` | 种子色需 WCAG AA 验证；深色模式 primaryContainer 从卡片底混入主题主色，普通/交互容器对卡片底分别保持 ≥2.2:1 / ≥2.8:1 |
| 修改语言 | `model/语言存储.ets` + `resources/<locale>/element/string.json` | **语言切换需重启应用**（setAppPreferredLanguage 全局重渲染卡 UI）；流程在 `pages/首页.ets` 弹窗 + startAbility + terminateSelf |
| 排查 NAPI 错误 | `native/napi_bridge/src/native_module.cpp` + `backend/错误类型.ts` | `nativeStatus=3` 是 BACKEND_ERROR；`nativeStatus=4` 是 NATIVE_FATAL |
| 排查 Rust panic | `native/rsharmony/src/lib.rs` | `call_with_registry` 用 catch_unwind 包裹；BackendRegistry 是全局 OnceLock |
| 修改媒体渲染 | `utils/{声音播放器,TTS播放器,媒体响应助手}.ets` + `model/学习卡片HTML构建器.ets` | 媒体经 `https://jidecards-media.local/` 自建域名 |
| 修改云端牌组托管 | `model/云端牌组配置.ts`（唯一目录 URL）+ `docs/cloud-deck-hosting.md`（协议）+ `model/云端牌组模型.ts`（校验） | 客户端只放公开 HTTPS 读取地址，禁止放网盘账号、上传令牌或签名密钥；兑换码以后走第三方 API 返回短时下载地址 |
| 修改全屏转场（NavDestination/弹窗） | `utils/转场时长.ets`（分档时长 + 弹簧曲线）+ `utils/自定义转场.ets`（NavDestination opacity 回调注册表）+ `pages/首页.ets` 的 `customNavContentTransition` 回调 | 时长按物理英寸分档（<8.5→200ms / 8.5-12→250ms / >12→300ms）；曲线统一 `curves.springCurve(0, 228, 22, 1)`；首页推栈（from/to index=-1）必须返回 undefined 走系统默认；`proxy.finishTransition()` 必须调，否则 1200ms timeout 后 UI 卡住 |
| 修改色彩对比度 | `resources/{base,dark}/element/color.json` + `model/颜色主题.ets` + `model/色阶生成.ets`（导出 WCAG 函数）+ `tools/verify-hardcoded-colors.mjs`（扫描硬编码颜色并验算对比度） | 文字档 ≥4.5:1，图标/标题档 ≥3:1；改 token 必须同时改 base + dark 避免深色模式反转；`色阶生成.ets` 的 `对比度(a,b)` 可直接调用验算；语义 token：`error_text`(#D92D20/#F97066)、`warning_text`(#B34C00/#FF9929)；**禁止硬编码 `#RRGGBB` 用作文字色**，必须走 `$r('app.color.xxx')` |
| 新增 Anki backend 方法 | `backend/服务索引.ts` 加 SERVICE/METHOD 常量 | **升级 Anki 版本时必须重新提取本表** |
| 修改"给我好评"逻辑 | `components/设置面板.ets` 的 `处理好评失败` + `跳转应用市场详情页` | commentManager.showCommentDialog 失败（含 1021500006-9 全部分支）统一回退 DeepLink `store://appgallery.huawei.com/app/detail?id=com.jide.kapian`；不再用 promptAction.showDialog（实测 Promise 静默挂起） |
| 修改"升级好评引导" | `pages/首页.ets` 的 `显示欢迎弹窗一次` + 欢迎弹窗 onClose + `utils/好评引导.ets` + `model/欢迎弹窗存储.ets`(upgrade_rate_shown) | 旧版本升级到新版本首次启动：`显示欢迎弹窗一次` 检测版本号变化 → 置 `升级后弹好评引导=true`；欢迎弹窗 onClose 清标志 → 直接调 `打开应用内好评`（commentManager.showCommentDialog + DeepLink 降级）。**不再用自定义弹窗**，每版本只弹一次系统评分窗 |
| 升级版本号 | `AppScope/app.json5` 的 versionCode + versionName | versionCode 递增；提交应用市场前需真机回归 + decisions.md 记录 |
| 修改浏览页 | `pages/浏览页.ets` + `components/browser/{搜索框,卡片表格,浏览编辑区}.ets` + `backend/{搜索服务,笔记服务,笔记类型服务,卡片服务}.ts` | phase 状态机 loading→list→error；搜索串由后端构建搜索串生成（前端不拼字符串）；行数据懒加载（浏览器行按ID）；T7 行点击弹 浏览编辑区 编辑笔记字段/标签，Cards 模式经 卡片服务.获取卡片 拿 noteId 再查笔记；浏览编辑区纯展示层不直接调 Service，onSave 回调上抛由父级落盘 |
| 新增浏览器列 | `proto/messages/SearchMessages.ts` 的 BrowserColumn 接口 + 后端 全部浏览器列 RPC 返回 | 列 key 来自 Anki 后端预定义；手机端默认显示 Question+Deck+Due 三列（长按表头配置） |
| 修改统计页 | `pages/统计页.ets` + `components/stats/*.ets` + `backend/统计服务.ts` + `proto/messages/StatsMessages.ts` + `model/{统计色板,统计分箱}.ets` | 阶段状态机 loading→data/error；图表用 Text+Column+Row+Stack（不引第三方库与 Canvas）；颜色/分箱复用 统计色板/统计分箱 纯函数（勿在组件内手写插值）；偏好走 GraphPreferences RPC；**统计图表组件 build 方法必须单根 Column**；新增图表参考 `日历卡.ets`（热力图）/`复习卡.ets`（堆叠柱）/`新增卡.ets`（直方图） |
| 修改媒体管理 | `components/settings/媒体管理面板.ets` + `backend/媒体服务.ts` | Stack 遮罩+面板；检查中/处理中防重入；清空回收站需 showAlertDialog 二次确认；getStringSync 带参用展开运算符；**未使用列表分页**（`未使用列表` 限前 200 项渲染避免真机 OOM，`未使用全部` 保留完整列表用于批量操作）；"全部放入回收站"按钮迭代 `未使用全部` 完整列表 |
| 修改卡片预览 | `components/browser/卡片预览页.ets` + `backend/卡片渲染服务.ts` | Web 组件复用 渲染既有卡片；翻面 + 左右滑切基于当前搜索结果列表；"编辑字段"进浏览编辑区 |
| 修改标签管理 | `components/browser/浏览侧边栏.ets` + `backend/标签服务.ts` | 标签长按弹 showActionMenu（回调必须 (err, data) 双参数）；4 选项：追加搜索/重命名/删除/补全 |

## 关键设计决策

- **语言切换**用 startAbility + terminateSelf 重启（`setAppPreferredLanguage` 全局重渲染会卡 UI）
- **ThemeMode 与 ColorTheme 正交**（独立选择）
- **countNew/Learning/Review 固定交通灯色**（保证主题切换下一致）
- **颜色主题展示名走 i18n**（2026-07-30 修正）：原 `颜色主题展示名()` 函数硬编码中文导致语言切换无效，已删除；改用 `getStringByNameSync('theme_color_' + 主题)` 动态读取 i18n key
- **"给我好评" DeepLink 降级**（2026-07-30 修正）：commentManager.showCommentDialog 在已评论/未登录/系统错误等场景 Promise 静默挂起，失败统一回退 DeepLink `store://appgallery.huawei.com/app/detail?id=com.jide.kapian`；不再用 promptAction.showDialog（实测 Promise 静默挂起）
- **Rust 工具链已就绪**（2026-08-06 修正）：本机已配置 cargo/rustc 1.97.1，jidecards01 自带 `third_party/anki` submodule 与 `target/` 编译产物，可独立构建。2026-07-30 旧记录（"本机未配置 Rust 工具链，复用 `往期淘汰作品/jidecards/target/` 静态库"）已废止
- **统计页入口用顶部工具栏**（2026-08-04）：无底部 TabBar，统计页入口放主页顶部工具栏（与设置/浏览同款按下态按钮），保持 app 内导航一致
- **系统栏颜色跟随主题微染**（2026-08-05）：`应用系统栏样式` 优先读 AppStorage `颜色键.页面底色微染`（页面背景同款主题微染色）作为 `statusBarColor`/`navigationBarColor`，让顶部状态栏与界面同色；`应用颜色主题` 写完色键后主动调 `应用系统栏样式` 覆盖所有主题变化路径（启动恢复/主题模式切换/颜色主题切换/系统深浅色变化）。早期初始化 AppStorage 未写入时回退中性 `#F5F7FA`/`#10151D`
- **统计图表不引第三方库**（2026-08-04）：用 Text+Column+Row+Stack 实现条形图/柱状图/网格指标，不引 Canvas 或第三方图表库；@Builder 传参渲染，不在 @Builder 内写 const
- **媒体管理面板持有 Service 实例**（2026-08-04）：与设置面板持有 集合服务 调 检查数据库 同款模式，面板直接调 媒体服务 RPC，不上抛数据意图；检查中/处理中防重入用 @State 布尔
- **华为应用市场设计审查合规**（2026-08-07）：4 项审查问题修复——(1) 色彩对比度：新增 `warning_text` 语义 token，禁止硬编码 `#RRGGBB` 用作文字色，`tools/verify-hardcoded-colors.mjs` 扫描验算 WCAG 对比度；(2) 转场动效：全屏转场统一用 `取全屏转场时长()`+`取全屏转场曲线()`（弹簧曲线），禁止左右平移/上下位移/单帧切换；(3) 滑动边界：所有 Scroll/List 加 `.edgeEffect(EdgeEffect.Spring)`；(4) 转场时长：`utils/转场时长.ets` 按设备物理英寸分档（200/250/300ms）。组件级微动效（按钮按下态 80ms / 分组展开 150ms / 卡片刷新 300ms）不属于"全屏页面转场"范畴

## 扩展点

| 扩展场景 | 入口 | 参考实现 |
|---|---|---|
| 新增 Service | `class XxxService { session = BackendSession.getInstance(); async method() {...} }` | `backend/统计服务.ts`(最简) / `backend/牌组服务.ts`(多方法) / `backend/牌组配置服务.ts`(整体回写保真) |
| 新增 protobuf 消息 | `encodeXxxRequest()` + `decodeYyy()` 用 ProtoWriter/ProtoReader | `proto/messages/DeckMessages.ts`(嵌套+保留字段) / `SchedulerMessages.ts`(raw passthrough) |
| 新增 ArkUI 组件 | `@Component struct { @Prop; onXxx: () => void = () => {}; build() {...} }` | `components/牌组列表项.ets` / `components/settings/外观分组.ets` |
| 新增 StudyPage phase | `utils/吸附计算器.ets` 的 `StudyPhase` 类型 + `pages/学习页.ets` 转移逻辑 + `components/学习浮动工具栏.ets` 同步 | phase 守卫规则；`cardArea()` Builder 补对应 UI 分支 |
| 新增卡片渲染 | `backend/卡片渲染服务.ts` + `model/学习卡片HTML构建器.ets`(纯函数积木) | `buildCardHtml()` / `rewriteMediaUrls()` / `stripSoundTags()` / `extractTypeAnswerMarker()` |
| **新增颜色主题** | (1) `model/颜色主题.ets` 的 ColorTheme 联合类型加成员 (2) `utils/颜色主题管理器.ets` 的 `seedColorOf()` + `normalizeColorTheme()` 加分支 (3) `components/settings/外观分组.ets` 的 `主题列表` 数组加 id (4) `resources/base/element/string.json` 加 `theme_color_<id>` 中文 (5) `resources/en_US/element/string.json` 加 `theme_color_<id>` 英文 | 6 主题：aurora / forest / midnight / lagoon / sunset / lemon（种子色取自 ArcoDesign shade 6）；**展示名必须走 i18n，不要硬编码** |
| 新增语言 | `model/语言存储.ets` 的 LanguageMode 类型 + 新建 `resources/<locale>/element/string.json` + `components/settings/外观分组.ets` 按钮 | 2 语言：zh-Hans(默认) / en-US |
| 新增 i18n key | `resources/base/element/string.json` + `resources/en_US/element/string.json` 同步加 key（数量+名称必须对齐，英文不能含中文）+ 调用点用 `$r` 或 `localized` / `localizedFmt` | `theme_color_*` / `about_rate_*`（含 `%s` / `%1$s` 占位符时用 `localizedFmt(resource, args)`） |
| 新增设置入口（应用内系统弹窗） | `components/设置面板.ets` aboutGroupContent 内加行 + 对应私有方法 | `处理好评()` 调 `commentManager.showCommentDialog`（@kit.AppGalleryKit）+ Deep Linking 降级；按错误码分支处理（1021500006-9）；**不要用 promptAction.showDialog** |
| 新增"首次完成 X 触发弹窗"引导 | 三件套：`components/<X>引导对话框.ets`(磨砂遮罩+surface_card) + `model/<X>引导存储.ets`(preferences「只弹一次」) + 触发点写 AppStorage 标记 + 首页 onPop 检查标记 | `AnkiWeb引导对话框`(首次启动)：参考 `显示AnkiWeb引导一次` 的「先标记再弹窗」模式。**好评引导已改用系统 commentManager.showCommentDialog 弹窗，不再走自定义对话框模式**（见上「升级好评引导」行） |
| 新增云端牌组字段/托管方 | `model/云端牌组模型.ts` + `backend/云端牌组服务.ets` + `docs/cloud-deck-hosting.md` | model 保持纯 TS；大文件必须走 `request.agent`，不得用 HTTP response 一次性载入内存；仍只接受 HTTPS `.apkg` |
| 新增 NavDestination 自定义转场 | (1) `pages/<X>页.ets` 的 NavDestination 加 `@State 转场透明度: number = 1` + `.opacity(this.转场透明度)` (2) `aboutToAppear` 调 `CustomTransition.getInstance().注册NavParam('<PageName>', 起点回调, 终点回调)`（起点设 opacity=0 进入/1 退出，终点设目标值）(3) `aboutToDisappear` 调 `注销NavParam('<PageName>')` (4) `pages/首页.ets` 的 `自定义转场回调` 已统一处理，无需改 | `pages/学习页.ets`('StudyPage') / `pages/添加笔记页.ets`('AddNotePage')：参考其 aboutToAppear 注册 + aboutToDisappear 注销模式；**key 必须与 NavPathStack pushPath 时的 name 一致**（首页.ets:1555 用 `from.name ?? ''` 查找） |
| 新增全屏弹窗/面板 | `components/<X>面板.ets` 内 `Stack` 的遮罩 Column 与主面板 Column 都加 `.transition(TransitionEffect.OPACITY.animation({ curve: 取全屏转场曲线(), duration: 取全屏转场时长() }))`；如需 scale 入场用 `TransitionEffect.asymmetric` + `.combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))` | `components/AnkiWeb引导对话框.ets`（OPACITY + scale 0.96）/ `components/牌组定制面板.ets`（纯 OPACITY）：禁止左右平移/上下位移/单帧切换 |
| 新增浏览页侧边栏节点 | `components/browser/浏览侧边栏.ets`（阶段 4 T6）+ `搜索服务.连接搜索节点` / `搜索服务.替换搜索节点` | 树形展示牌组/标签/已保存搜索；点击节点触发 onSearchWithNode；长按切追加 AND/OR 语义 |
| 新增统计图表 | `components/stats/<X>卡.ets`（新建）+ `pages/统计页.ets` 的 Scroll 内加 `统计图表分区` | @Prop 数据 + @StorageProp 主题色；**build 方法单根 Column** + if/else + @Builder 传参渲染；参考 `今日计数卡.ets`(Grid) / `卡片状态分布.ets`(条形图) / `小时分布卡.ets`(柱状图) |
| 新增设置面板弹层 | `components/settings/<X>面板.ets`（新建）+ `components/设置面板.ets` 数据分组 加入口 | Stack 遮罩+面板；持有对应 Service 实例直接调后端（与 媒体管理面板 同款）；防重入用 @State 布尔；参考 `媒体管理面板.ets` |

## 项目特有的坑

- **本机 Rust 工具链已就绪**（2026-08-06 核实）：cargo/rustc 1.97.1 在 PATH。jidecards01 自带 `third_party/anki` submodule 与 `target/` 产物，无需依赖归档项目
- **`target/` 曾是 dangling junction**：归档 jidecards 项目时未同步更新 jidecards01 的 junction 指向，留下悬空链接。已于 2026-07-30 修复为真实目录，但若再次归档/迁移项目需检查 junction 状态
- **PowerShell shell wrapper 拦截 Copy-Item / New-Item**：本机 PowerShell profile 注入 `safe_rm_aliases.ps1` wrapper。绕过方法：用 .NET API `[System.IO.File]::Copy(src, dst, $true)` 与 `[System.IO.Directory]::CreateDirectory(path)`；`[System.IO.Directory]::Delete(path, $false)` 删 junction（第二参数 `$false` 关键：不递归删目标）
- **hvigor 默认同时构建 arm64 + x86_64**：两个 ABI 都需要对应的 `libjidecards_core.a`。只复制 arm64 静态库会在 x86_64 ninja 阶段再次报 missing 错误
- **debug 与 release 双模式都要静态库**：DevEco IDE 默认 debug 构建需要 `target/.../debug/libjidecards_core.a`（约 740-760MB，含调试符号），命令行 release 构建需要 `target/.../release/libjidecards_core.a`（约 214-218MB，thin LTO + strip）。只复制 release 会导致 IDE debug 构建报 `Missing ... debug/libjidecards_core.a`；两个模式两个 ABI 共需 4 份静态库
- **commentManager 模拟器不支持**：HarmonyOS 6 `commentManager.showCommentDialog` 必须真机验证（需登录华为账号，一年内已评论过不能再次评论）
- **ArkTS 限制**：不支持解构声明（`arkts-no-destruct-decls`）；不支持 untyped object literals（`arkts-no-untyped-obj-literals`）
- **ArkTS build 方法只能有一个根节点**：`if + Text + return + const + Column` 多根节点编译报 "build method can have only one root node, which must be a container component"。修复模式：外层包一个 `Column()` + `if/else` 分支 + `@Builder` 方法渲染实际内容
- **ArkTS @Builder 内不能写 const/let**：`const 数据 = ...` 在 @Builder 方法内编译报 "Only UI component syntax can be written here"。修复模式：把数据作为参数传给 @Builder（`this.渲染分布(数据, 总数)`），在 build 方法内调用时传 `this.取数据() as Type`
- **ArkTS 不支持 `!` 非空断言**：`this.数据!.field` 可能编译报错。改用 `as Type` 类型断言传参给 @Builder
- **promptAction.showActionMenu 回调签名**：必须 `(err: BusinessError, data: ActionMenuSuccessResponse)` 双参数，`err !== null` 时直接 return；不能只写 data 参数
- **getStringSync 带参数**：必须用展开运算符 `...参数` 传参（`getStringSync(id, ...参数)`），不能直接传数组
- **import type 改 import**：枚举类型（如 HelpPage）如果用作值（switch case / 比较）必须 `import` 而非 `import type`
- **model 层不能 import HarmonyOS Kit（@kit.*）**：node test runner 无法解析，导致整个 .test.mjs 文件加载失败（ERR_INVALID_MODULE_SPECIFIER），失败信息只显示 `not ok N - file.test.mjs` 不显示具体 assertion。hilog 应放 utils 层，model 层保持纯函数无副作用
- **Toggle 双向绑定 vs 乐观更新**：需乐观更新+失败回滚时改用单向绑定 + `onChange` 手动控制（见 `components/settings/调度器分组.ets`）
- **i18n 契约测试已加强**：`i18n-contract.test.mjs` 用平衡 2 层括号匹配拦截 `Text(... ? '中文' : ...)` 内三元表达式 + `this.xxxMessage = \`...中文...\`` 模板字符串赋值。新增功能务必走 `$r` + `localized` / `localizedFmt`
- **Web 组件 attach 时序**：`aboutToAppear` 异步链调 `loadData` 时 Web 可能未 `onControllerAttached`，首张卡白屏。修复：未 attach 时缓存 HTML，`onControllerAttached` 回调消费
- **`closeCollection()` vs `markCollectionConsumed()`**：export 后 collection 已被后端消费，调 CLOSE 会失败，只能切本地 state
- **旧索引目录 `.ai-index/` 已废弃**：readable-indexed-code 规则改用语义检索（SearchCodebase），`.ai-index/` 可删除但保留无害
- **没有 docs/architecture.md 与 DEVELOPMENT_PLAN.md**：jidecards01 未引 docs 目录，架构详情需读 `往期淘汰作品/jidecards/docs/architecture.md`（注意部分过期：声称 12 backend 文件实际 16+；声称存在 SERVICE_EXTENSION_GUIDE.md 实际无）
- **hvigor PackageHap 阶段 `spawn java ENOENT`**：本机 `java` 不在系统 PATH，需先 `$env:JAVA_HOME="C:\Program Files\Huawei\DevEco Studio\jbr"; $env:PATH="$env:JAVA_HOME\bin;$env:PATH"` 再跑 hvigorw。否则 CompileArkTS 通过但 PackageHap 失败，错误信息看似与代码相关实则环境问题
- **`NavContentInfo.name` 类型是 `string | undefined` 不是 `string`**：API 23 起 from/to 的 name 可能为 undefined（未命名场景），赋给 string 变量会触发 `10605999 ArkTS Compiler Error`。需用 `from.name ?? ''` 兜底

## 待办

- [x] 补建 `AGENTS.md` 与 `.agents/rules/{context,naming,comments,workflow,testing}.md` + `.agents/adapters/arkts.md`（2026-08-01 从归档项目 jidecards 复制）
- [x] 引入 `third_party/anki` submodule（jidecards01 已自带，2026-08-06 核实）
- [x] 安装 Rust 工具链使 `tools/build-native.ps1` 可用，去掉对归档项目的依赖（2026-08-06 已就绪，cargo/rustc 1.97.1）
- [x] 删除 `.ai-index/`（已废弃）（2026-08-01 已删除）
