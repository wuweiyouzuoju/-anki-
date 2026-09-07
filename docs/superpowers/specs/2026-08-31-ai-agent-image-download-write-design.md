# AI 制卡图片下载与 Anki 媒体写入设计

> 归档状态：这是一次性历史设计/执行记录，不是当前路线图、待办列表或操作手册。未勾选项不表示仍未实现；当前事实请查阅 [文档导航](../../README.md)、[开发状态](../../DEVELOPMENT_PLAN.md)、[当前架构](../../architecture.md) 和实际源码/测试。


日期：2026-08-31  
状态：已获用户批准，待实施计划  
范围：AI 制卡、AI 改卡中的 Wikimedia Commons 图片搜索、下载、写入 Anki 媒体库与字段

## 1. 目标与非目标

### 目标

1. AI 制卡可以搜索 Wikimedia Commons 图片，并返回可审计的候选图片。
2. AI 生成的制卡草稿可以携带图片候选与目标字段。
3. 用户确认草稿后，应用下载图片并写入 Anki `collection.media`。
4. 使用 Anki `AddMediaFile` 返回的最终文件名写入字段 HTML，不能假定期望文件名一定可用。
5. AI 改卡可以向已有字段追加图片。
6. 下载失败、媒体写入失败、笔记写入失败都能报告明确状态；笔记写入失败时对本次媒体写入做补偿清理。
7. 修复模型把提示语中的泛化 `propose_` 当作工具名调用的问题。

### 非目标

1. 第一版不支持音频、视频、SVG 转换或图片生成。
2. 第一版不改 Anki Rust 后端协议，不新增跨媒体与笔记的原子 RPC。
3. 第一版不允许模型直接调用任意 HTTP、文件系统、NAPI 或 Anki RPC。
4. 第一版图片放置只支持追加，不实现复杂 HTML 图片替换与编辑器级富文本解析。
5. 第一版默认每张生成卡片最多一张图片；本次示例为 5 张卡对应 5 张图片。

## 2. 已核实的 Anki 后端约束

### 2.1 媒体写入协议

Anki 的 `AddMediaFileRequest` 只有：

- `desired_name: string`
- `data: bytes`

它不接收 URL。后端 `MediaService::add_media_file()` 调用 `MediaManager::add_file()`，媒体管理器会：

1. 计算内容 SHA-1。
2. 规范化文件名：NFC、去除非法字符、处理 Windows 保留名、限制长度。
3. 同名且内容相同时复用原文件名。
4. 同名但内容不同时追加内容哈希后缀。
5. 更新媒体数据库中的 SHA-1、mtime 和同步标记。
6. 返回实际使用的文件名。

因此，调用方必须使用返回值，而不能把 `desired_name` 直接写进卡片字段。

### 2.2 笔记写入协议

`AddNote` 和 `UpdateNotes` 接收完整 Note；图片是字段字符串中的 HTML，例如：

```html
<img src="ai-draft-1-0.jpg" alt="中国传统文化">
```

这意味着图片下载与 Note 写入是两个后端操作。Anki 当前没有“远程 URL + Note + 媒体”一体化的通用 RPC。媒体文件写入成功而 Note 写入失败时，只能通过 `TrashMediaFiles` 做补偿。

### 2.3 回滚边界

`TrashMediaFiles` 会把文件从 `collection.media` 移到 `media.trash`，并把媒体数据库条目标记为删除；不能把它描述成跨媒体与 Note 的数据库事务。

第一版采用以下真实语义：

- 下载失败：不修改 Anki。
- 媒体写入失败：不修改 Note。
- Note 写入失败：把本次新增媒体移入 Anki 媒体回收站；若补偿失败，报告“媒体已写入但 Note 失败”，不能伪造完全回滚。
- 用户确认前：不下载、不写媒体、不写 Note。

## 3. 目标架构

```text
AgentRunner
  ├─ read: get_note_type_capabilities / get_note_context / list_decks / search_images
  └─ draft: propose_create_notes / propose_update_notes
          │
          ▼
    ChangeDraft（字段变更 + 图片候选引用）
          │ 用户确认
          ▼
    AgentDraftExecutor
      ├─ WikimediaImageService：下载、临时文件、响应校验
      ├─ 媒体服务.添加媒体文件：写 collection.media，取得最终文件名
      ├─ 笔记服务.添加笔记 / 更新笔记：写入带最终文件名的字段 HTML
      └─ 媒体服务.媒体文件进回收站：失败补偿
```

网络下载放在 ArkTS 的专用图片服务中，不放进 Anki Rust 媒体服务。Anki Rust 只负责已下载字节的媒体库登记与写入，保持现有后端边界不变。

## 4. Agent 工具契约

### 4.1 `search_images`（只读）

工具参数：

```json
{
  "query": "中国传统文化",
  "limit": 5
}
```

约束：

- `query` 非空，长度受限。
- `limit` 为 1 至 10；用户要求 5 张时传 5。
- 只访问 Wikimedia Commons API。
- 不向模型暴露任意站点的下载能力。

候选返回结构：

```json
{
  "candidates": [
    {
      "candidateId": "commons-<scope>-0",
      "title": "文件标题",
      "thumbnailUrl": "https://upload.wikimedia.org/...",
      "downloadUrl": "https://upload.wikimedia.org/...",
      "sourceUrl": "https://commons.wikimedia.org/wiki/File:...",
      "mime": "image/jpeg",
      "license": "CC BY-SA ...",
      "credit": "来源署名"
    }
  ]
}
```

`candidateId` 由当前 `AgentScope` 管理，草稿只能引用当前会话已经搜索到的候选。模型不能通过图片草稿直接注入任意 URL。

Wikimedia 查询使用文件命名空间搜索，并请求 `imageinfo` 的原图/缩略图地址、MIME、尺寸和许可证元数据。下载地址只接受 HTTPS 的 `upload.wikimedia.org`，来源页只接受 Wikimedia Commons。

### 4.2 `propose_create_notes` 扩展

保留现有 `fields` 字段顺序，新增可选 `images`：

```json
{
  "targetDeckId": 1,
  "targetNotetypeId": 1,
  "notes": [
    {
      "fields": ["正面内容", "背面内容"],
      "images": [
        {
          "candidateId": "commons-scope-0",
          "fieldOrd": 1,
          "placement": "append",
          "altText": "中国传统文化"
        }
      ]
    }
  ],
  "draftId": "draft-1",
  "reason": "..."
}
```

第一版校验：

- `fieldOrd` 必须存在于目标笔记类型字段范围。
- `candidateId` 必须在当前 AgentScope 中存在。
- 每张卡最多一张图片。
- `placement` 只能为 `append`。
- `altText` 可为空但必须是字符串。

### 4.3 `propose_update_notes` 扩展

保留当前 `fieldUpdatesJson` 和标签更新能力，新增可选 `imagesJson`，格式为：

```json
[
  {
    "noteId": 123,
    "candidateId": "commons-scope-0",
    "fieldOrd": 1,
    "placement": "append",
    "altText": "中国传统文化"
  }
]
```

更新草稿必须读取并保存目标字段的 `before` 值。执行时重新读取 Note 并校验基线，避免用户在确认前修改同一字段造成覆盖。

### 4.4 工具名路由

提示词、工具目录、工具 Schema、注册表必须使用完整工具名：

- `propose_create_notes`
- `propose_update_notes`
- `search_images`

不得在模型提示中使用会被模型误认为工具名的裸 `propose_`。工具目录与注册表必须保持一一对应；未知工具仍然安全拒绝，但错误诊断必须明确显示可用工具名。

## 5. Wikimedia 图片服务

新增 `WikimediaImageService.ets`，职责分为两层：

### 5.1 搜索

- 使用 `@kit.NetworkKit` 的 `http.createHttp()`。
- `GET` Wikimedia Commons API。
- `expectDataType` 使用 `STRING`。
- 禁用缓存，设置连接和读取超时。
- 校验 HTTP 2xx 与 JSON 响应结构。
- 过滤无图片 URL、无来源页、非 HTTPS 或非 Wikimedia 域名结果。
- 从许可证元数据中提取短许可证与署名；缺失许可证信息的候选可以展示但不得宣称有特定授权。
- 每次查询返回最多 10 个候选，并由 AgentScope 保存候选元数据。

### 5.2 下载

- 只允许当前候选的 `downloadUrl`，不接受工具参数中的自由 URL。
- 使用应用缓存目录下的草稿专属 `.part` 文件。
- 下载完成后检查文件存在、非空、大小上限和图片魔数。
- 第一版支持 JPEG、PNG、GIF、WebP、AVIF；拒绝 HTML、JSON、SVG 和未知内容，避免把错误页写进媒体库。
- 下载临时文件使用草稿 ID、图片序号和扩展名生成，尽量避免与用户媒体重名。
- 完成或失败都在 `finally` 中清理 `.part` 文件。
- 网络客户端必须销毁，避免连接泄漏。

建议默认限制：单图不超过 8 MiB，单次草稿图片总量不超过 40 MiB；超过限制返回稳定的图片下载错误码。

## 6. 草稿与执行器

### 6.1 数据结构

在纯数据 Agent 模型中增加图片引用类型，不把 `Uint8Array`、文件路径或 HTTP 客户端放入 `ChangeDraft`：

```ts
export interface AgentImageAttachment {
  noteId: number;
  fieldOrd: number;
  candidateId: string;
  placement: 'append';
  altText: string;
}
```

`ChangeDraft` 增加 `imageAttachments: AgentImageAttachment[]`。图片仍然是草稿数据，不是模型直接执行的副作用。

### 6.2 创建笔记执行顺序

每个临时 Note 分组按以下顺序执行：

1. 重新校验笔记类型和目标牌组。
2. 调用 `笔记服务.新建笔记()` 获取默认 Note；此操作不落库。
3. 写入文本字段和标签草稿值。
4. 下载该 Note 的图片。
5. 调用 `媒体服务.添加媒体文件()`，取得最终文件名。
6. 将 `<img src="最终文件名" alt="...">` 追加到目标字段。
7. 调用 `笔记服务.添加笔记()`；该服务仍执行 Anki 的字段、重复和 Cloze 校验。
8. 成功后记录 Note ID、媒体文件名和卡片影响数量。

如果步骤 7 失败，步骤 5 成功写入的媒体文件进入回收站；如果补偿失败，结果中必须单独列出孤立媒体文件名。

### 6.3 更新笔记执行顺序

1. 重新读取 Note 并验证字段/标签基线。
2. 应用文本字段更新。
3. 下载并写入新媒体。
4. 使用媒体服务返回的最终文件名生成字段 HTML。
5. 调用 `笔记服务.更新笔记([note], false)`，保留 Anki 撤销栈。
6. 更新失败时仅补偿本次新增且由当前草稿生成的媒体文件。

对于同一图片内容重复添加，Anki 可能复用已有文件名，因此补偿逻辑不能无条件删除任意返回文件名。实现应使用草稿专属期望名，并记录本次调用的新增/复用状态；如果无法可靠判定文件归属，则宁可保留并报告待 `检查媒体()` 清理，也不能误删用户已有媒体。

## 7. 用户界面与状态

草稿预览需要展示：

- 图片缩略图。
- 目标卡片和字段。
- Wikimedia 来源页。
- 许可证/署名信息。
- 下载与写入将发生在用户确认之后。

执行结果需要区分：

- 全部完成。
- 部分完成：部分 Note 或图片失败。
- 全部失败。
- 媒体已写入但 Note 失败且补偿失败。

“草稿已生成”不能显示为“已创建卡片”。

## 8. 测试策略

先写失败测试，再实现生产代码。

### 8.1 纯数据/工具契约

- `search_images` 出现在 create/edit 正确的工具目录中。
- `propose_create_notes` 图片参数可通过 Schema，未知属性被拒绝。
- `propose_update_notes` 图片参数可通过 Schema，字段范围和 Note ID 被校验。
- `candidateId` 不在当前作用域时生成稳定诊断。
- 裸 `propose_` 不会被注册为可调用工具。
- 图片工具不出现在不支持图片能力的 Provider 请求中时，Agent 给出明确能力错误。

### 8.2 Wikimedia 服务

- 成功 JSON 返回候选及许可证字段。
- HTTP 非 2xx、JSON 错误、无候选、非法域名和缺少下载地址均失败。
- 下载 HTML/JSON 错误页时被魔数校验拒绝。
- 超过单图/批次大小限制时不调用媒体写入。
- `.part` 文件在成功、失败、超时路径均清理。
- HTTP 客户端在所有路径销毁。

### 8.3 Anki 媒体/执行器

- `媒体服务.添加媒体文件()` 返回的重命名文件名被写入字段，而不是期望文件名。
- Note 写入前图片失败时不会调用 `添加笔记`。
- Note 写入失败时调用 `媒体文件进回收站`。
- 补偿失败在结果中保留孤立文件名。
- 更新 Note 保留 `skipUndoEntry=false`。
- 草稿冲突发生在下载前时不产生网络或媒体副作用。
- 创建 5 张卡时每张最多一张图片，结果数量与成功/失败明细一致。

### 8.4 回归

运行既有 Agent 工具目录、Schema、Runner、DraftExecutor、Media proto 测试，并执行项目规定的 `npm test` 与构建验证。

## 9. 方案取舍

第一版不新增 Rust 自定义 RPC。原因是：

1. 现有 Anki `AddMediaFile`、`AddNote`、`UpdateNotes` 已满足功能闭环。
2. Anki 媒体写入本身已经处理文件名规范化、哈希去重和媒体数据库登记。
3. 新增跨媒体与 Note 的 Rust RPC 需要扩展 proto、生成代码、服务分派与 Harmony 桥接，范围明显扩大。
4. 即便新增 RPC，远程图片下载仍然需要在 ArkTS 或 Rust 之外处理，不能消除所有失败边界。
5. 当前方案明确使用补偿语义，不假称跨服务原子事务；未来若确实需要原子性，再单独设计后端事务 RPC。

