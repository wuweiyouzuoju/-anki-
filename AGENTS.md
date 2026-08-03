# AGENTS.md — jidecards01

> 通用代码风格约束（命名 / 注释 / 工作流分级 / 测试）。项目业务地图见 [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)。
> 本文件管"怎么写代码"，PROJECT_CONTEXT.md 管"项目是什么、改哪里"。

## 规则索引

详细规则在 `.agents/`：

- [`.agents/rules/context.md`](.agents/rules/context.md) — PROJECT_CONTEXT.md 规范
- [`.agents/rules/naming.md`](.agents/rules/naming.md) — 命名规则（默认英文 + 中文 docstring）
- [`.agents/rules/comments.md`](.agents/rules/comments.md) — 注释规则（意图 + Invariants + Extension Points）
- [`.agents/rules/workflow.md`](.agents/rules/workflow.md) — 分级工作流（Trivial / Standard / Structural）
- [`.agents/rules/testing.md`](.agents/rules/testing.md) — 测试要求
- [`.agents/adapters/arkts.md`](.agents/adapters/arkts.md) — ArkTS / HarmonyOS 适配

## 核心红线

- 禁止完整重写已有模块（单次删除 > 50% 原文件行数）
- 禁换框架/引擎
- 保留既有功能（改 A 不能让 B 坏；坏了必须修或回退）
- 不过度工程化：不加未要求的功能 / 抽象 / 配置项 / 错误处理 / 文档注释
- 不加 backwards-compat shim：删了就删干净
- 不在未改动的代码上加注释 / 类型 / docstring

## 快速验证命令

- Node 契约测试（316 个）：`npm test`
- 工具链诊断：`npm run doctor`
- Rust FFI 主机测试：`tools\build-native.ps1 -Target host-test`
- 完整构建（Rust + ArkTS + HAP）：`npm run build:app`

真机装机/签名命令见 `.trae/DEVELOPMENT_WORKFLOW.md`。

## AI 协作流程

### 进入项目时
1. 读 [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)（项目业务地图）
2. 读本文件（代码风格约束）
3. 读 [`.agents/adapters/arkts.md`](.agents/adapters/arkts.md)（ArkTS 适配）
4. 若 PROJECT_CONTEXT.md 不存在，按 [`.agents/rules/context.md`](.agents/rules/context.md) 创建

### 修改代码时
1. 判断改动级别（Trivial / Standard / Structural），按 [`.agents/rules/workflow.md`](.agents/rules/workflow.md) 走步骤
2. 遵守 [`.agents/rules/naming.md`](.agents/rules/naming.md) 和 [`.agents/rules/comments.md`](.agents/rules/comments.md)
3. 验证（见 [`.agents/rules/testing.md`](.agents/rules/testing.md)）

### 新增功能时
1. 读 PROJECT_CONTEXT.md 的"扩展点" section
2. 找到对应扩展入口和参考实现
3. 按参考实现的模式扩展
4. 更新 PROJECT_CONTEXT.md（如涉及新模块 / 扩展点）

## 迁移状态（2026-07-30）

本项目从旧版规则（中文命名强制 / 块 ID / 8 字段注释 / `.ai-index/`）渐进迁移到本规则体系：
- `.ai-index/` 已废弃，用语义检索（SearchCodebase）替代（待清理）
- 既有 @块ID 与 8 字段注释保留，不再新增
- 新增函数用"意图 + Invariants + Extension Points"注释格式
- 命名：旧代码不必改回；新增代码默认英文标识符 + 中文 docstring
