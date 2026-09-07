# 3.0.0 应用内制卡/改卡 Agent 完成交接修订

> 归档状态：这是一次性历史设计/执行记录，不是当前路线图、待办列表或操作手册。未勾选项不表示仍未实现；当前事实请查阅 [文档导航](../../README.md)、[开发状态](../../DEVELOPMENT_PLAN.md)、[当前架构](../../architecture.md) 和实际源码/测试。


日期：2026-08-31

## 最终结论

3.0.0 的 AI 制卡和 AI 改卡共用一个 ArkTS 轻量 Agent 内核。模型不能直接调用 Anki Rust、裸 protobuf、NAPI、数据库或任意 RPC；它只能调用应用声明的语义工具。所有写操作先生成 `ChangeDraft`，由界面展示真实字段、影响范围和风险，用户确认后才通过 `AgentDraftExecutor` 调用既有 ArkTS service。

本次没有修改 Anki Rust 源码、protobuf 定义、NAPI ABI 或数据库 schema。HAP 内仍包含既有 Rust 编译产物，但新增 Agent 本身是 ArkTS 代码，不是新增的 Rust 机器码后端。

## 最终架构与安全边界

1. `ProviderProtocol` 为 DeepSeek、OpenAI 和 Custom 生成 Responses 请求；Custom 只接受 HTTPS，且必须兼容 Responses 协议，不做静默协议降级。
2. `ResponsesEventNormalizer` 只把真实 SSE 文字、推理、搜索来源、工具调用和终止事件交给 UI/Runner。
3. `AgentRunner` 是 8 次 Provider 调用、16 次工具调用的有界循环，支持取消、瞬时网络重试、工具失败自纠、DeepSeek 无状态 reasoning/web-search 续传和输出截断续跑。
4. `AgentScope` 每条用户消息前重建；模型只能引用入口上下文或本轮读工具登记过的稳定 ID。
5. `CardAgentTools` 和 `HighRiskAgentTools` 只产生草稿。普通写一次确认；删除、迁移笔记类型、模板/CSS 等高风险操作需要两次独立确认。
6. `AgentDraftExecutor` 是唯一写边界；执行前重读 baseline，发现冲突即停止。确认令牌与草稿、风险级别绑定，短时、一次性。
7. 部分执行失败时只重建失败目标的重试草稿，不重复已成功写入的项目，并再次要求确认。
8. 图片和音频二进制目前不发送给文本模型；上下文仅保留清洗后的文字与占位提示，模型不得声称看见或听见媒体。

## 制卡完成条件

制卡模式只有在工具真正返回至少一个合法 `ChangeDraft` 后才能结束，模型正文中声称“已生成草稿”不算完成。

- 用户明确说出张数时，最终草稿必须恰好等于该数量；支持“5 张”“5 道”“5 cards”和紧凑拼音“5dao”，年份等知识数字不会被误当成张数。
- 普通类型：字段数量必须与笔记类型一致，第一字段非空，禁止误写 cloze 标记。
- 填空类型：以后端 `Notetype.config.kind` 和 `GetClozeFieldOrds` 为准，不按笔记类型名称猜测；允许字段内必须存在合法 `{{cN::答案}}`。
- 导入的自定义笔记类型：使用后端返回的真实字段顺序和能力；模型第一次参数错误会作为受控 `tool_error` 返回，允许其在同一轮自行修正。
- Image Occlusion 仍不走通用字段创建工具，因为它依赖专用遮罩 RPC；需要单独的结构化图片工具后再开放。

## 改卡完成条件

- 从学习页单卡进入：页面只在本地读取该卡、笔记、同笔记兄弟卡和字段，并显示当前卡上下文；用户发送要求之前不请求 Provider。
- 从浏览器进入：携带当前选择的稳定 card/note ID，返回后刷新当前搜索。
- 从首页“新建牌组”面板进入：没有预选卡，发送要求后 Agent 可用读工具搜索牌库，再生成修改草稿。
- 同一笔记生成多张卡时，改字段会影响所有兄弟卡；影响范围由应用读取后端计算并在确认前显示，不由模型猜测。
- 纯查询或目标不存在可以无草稿结束；明确修改只有找到合法目标后才能产生可执行草稿，不会为了满足请求而虚构卡片。

## 失败根因时间线

1. **只显示 `http`**：网络层把非 2xx 压成一个占位字符串，丢失 HTTP 状态和响应详情。修复为保留状态码、净化后的 Provider 详情，并脱敏 key/bearer 和长请求回显。
2. **DeepSeek 第二轮 HTTP 400**：无状态 Responses 续传把 reasoning 错写成 `{content: "plain string"}`。DeepSeek 要求重放完整 reasoning output item，或用 `reasoning_text` 内容块。现在优先白名单重放 Provider 原始 completed reasoning/web-search item。
3. **平行工具续传顺序错误**：Function call output 曾可能出现在尚未重放完的 function call 前。现在先追加本轮全部 function calls，再依次追加 outputs。
4. **填空草稿表面成功但字段无 cloze**：旧路径只校验字段数。现在在草稿登记前按后端能力校验 cloze 所在字段与标记。
5. **模型用正文伪称已生成草稿**：Runner 曾允许无工具调用的正文结束。现在制卡模式强制真实草稿完成契约，并清除纠错前的误导正文。
6. **要求 5 张却得到 10 张**：模型把五个年份各拆成问/答两张。现在解析用户明确数量，按唯一临时 note ID 计数；数量不符的整批草稿丢弃并要求重提。
7. **`provider_response_incomplete`**：DeepSeek 的 `max_output_tokens` 同时包含推理和可见输出，原 8192 在搜索/推理后被耗尽。现在页面使用 `low` 推理和 32768 输出上限；`max_output_tokens` 截断会白名单续传并有界继续，`content_filter` 截断仍立即失败。
8. **首页 AI 改卡欢迎语误称已有当前卡**：首页入口实际没有预选卡。现在根据本地入口上下文分别显示“当前卡已载入”或“可搜索牌库并生成草稿”。

## 已裁定的方向

- 不在部分输出后自动切换 Chat Completions/其他供应商：可能重复工具写提案，且语义不一致。
- DeepSeek 优先，内置地址和模型固定下拉；用户选择与各 Provider 模型记忆；Custom 才允许手输 HTTPS 地址与模型。
- 真实搜索由 Provider `web_search` 执行；没有搜索事件和 HTTPS 来源时不得宣称联网成功。Custom 默认不宣称支持联网。
- 思考区只展示 Provider 实际返回的增量，不伪造“思考过程”。Harmony 端可以晚于 Provider 到达速度逐段渲染，但不能生成不存在的过程。
- 不发送媒体二进制给不支持的模型；当前统一使用安全占位，而不是冒险让请求 400。
- 历史保存可见对话、工具审计、来源和执行结果，不保存 API key、原始隐藏 reasoning 或媒体字节；旧草稿和确认令牌不会随历史恢复。

## 2026-08-31 验证证据

- 自动化：最终完整 `npm test` 为 648/648；包含截断恢复、精确数量、字段/cloze、自定义类型、入口、安全令牌、部分失败重试和协议续传契约。
- 构建：最终完整 `npm run build:app` 已重新编译 Rust 双架构并完成 ArkTS 类型检查、签名 HAP，`BUILD SUCCESSFUL`。
- 在线 DeepSeek/模拟器：
  - `zhongguoxiandaishi5daonianfendetiankongti`：真实生成 5 张可编辑填空草稿，按钮显示“保存选中卡片（5 张）”，工具过程包含成功的 `propose_create_notes`。
  - `suibianlaiyidian`：不再“内容无法解析”，真实生成 10 张合法填空草稿。
  - 导入笔记类型“AI机器学习卡”：第一次提案被字段校验拒绝后，模型自行修正，真实生成 2 张草稿。
  - 首页 AI 改卡：进入页面不请求 API；发送后可调用 `list_decks`/`search_cards`。目标“中国”牌组为空时明确停止，没有生成虚假草稿或写入。
- 在线设备只有 `127.0.0.1:5555` 与 `127.0.0.1:5557` 两台模拟器；没有实体手机在线，因此不得把这些结果描述成物理真机验证。
- 最终签名 HAP 已用 `hdc install -r` 覆盖安装两台模拟器并启动；两台 `bm dump` 均确认 `versionCode=3000`、`versionName=3.0.0`。
- 用户明确选择跳过 OpenAI 凭据/实时调用，所以 OpenAI 仅通过静态协议和自动化测试验证，没有在线请求。

## 明确保留的限制

- 图片遮盖创建需要独立的结构化媒体/遮罩工具，通用 Agent 创建暂不开放。
- 图片、音频二进制尚未传给 Provider；vision 模型下拉存在不等于当前上下文已发送媒体。
- 搜索来源目前显示为文本，不是可点击链接。
- 历史可分页恢复和删除，但没有单独的重命名 UI；标题由首条用户消息自动生成。
- Custom 仅保证 Responses 兼容端点；不自动探测或降级到厂商私有/Chat Completions 协议。
- 没有实体手机与 OpenAI 在线验证证据；需要外部条件满足后补测，不属于代码内可彻底消除的阻碍。
