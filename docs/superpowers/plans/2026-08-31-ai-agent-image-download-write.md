# AI Agent 图片下载写入实施计划

## 目标

为 AI 制卡/改卡增加 Wikimedia Commons 图片候选、用户确认后的下载、Anki 媒体写入和失败补偿，并修复裸 `propose_` 工具名误调用。

## 实施顺序

1. 添加失败契约测试：工具目录、Schema、候选作用域、Wikimedia 响应解析、图片附件写入和失败补偿。
2. 扩展 `AgentTypes.ts`、`AgentToolSchemas.ts`、`AgentToolCatalog.ts` 和 `AgentPolicy.ts`。
3. 扩展 `AgentScope.ets` 保存当前 Agent 回合的图片候选。
4. 新增 `WikimediaImageService.ets`：Commons 搜索、候选校验、下载到临时文件、图片魔数校验、清理临时文件。
5. 在 `CardAgentTools.ets` 注册 `search_images`，并让创建/更新草稿携带图片附件。
6. 扩展 `AgentDraftExecutor.ets`：确认后下载图片，调用现有 `媒体服务.添加媒体文件()`，使用返回文件名写入 HTML，再创建/更新 Note；失败调用媒体回收站补偿。
7. 修复 `AI制卡页.ets` 的工具提示、草稿展示和执行结果文案；保证普通 UI 保存仍兼容无图片草稿。
8. 运行新增测试、既有 Agent 测试、`npm test` 和项目构建；只报告有证据的结果。

## 关键实现约束

- 不新增 Rust/Anki proto；复用 `AddMediaFile`、`AddNote`、`UpdateNotes`、`TrashMediaFiles`。
- 模型只能引用当前作用域中 `search_images` 返回的 `candidateId`，不能传任意 URL。
- 不在用户确认前下载或修改 Anki。
- 不把 Anki 的媒体写入与 Note 写入描述成原子事务；失败使用补偿语义。
- 目标字段按真实 `fieldOrd` 写入，媒体 HTML 使用 Anki 返回的最终文件名。
