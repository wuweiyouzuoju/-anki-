# Decisions

## 2026-08-31 — Agent 对话式配置、澄清与统一折叠

- 目标牌组、笔记类型和就绪状态属于本地助手设置卡，不伪装成 Provider 消息，也不进入 Provider 历史。
- 用户发送时冻结 `AgentTaskSnapshot`；可见文本隐藏稳定 ID，Provider 文本携带执行所需结构化上下文。
- `request_clarification` 是无写入工具。仅当它单独成功调用时，Runner 才以 `awaiting_clarification` 合法无草稿结束当前轮。
- 澄清气泡独立于运行消息；回答成功后保留并自动折叠，问题和回答进入同一逻辑会话的后续 Provider 回放。
- 设置、澄清和工具过程统一使用 `AgentDisclosureCard`：箭头 `▼`、0/-90 度旋转、150ms `Curve.EaseOut`，只动画箭头。
- 不改变 Anki Rust、protobuf、NAPI ABI、数据库、调度或现有草稿确认/高风险写入边界。

## 2026-08-31 — 保留 Agent 自动补救轮次的可见回复

- 目标：制卡 Agent 在模型未立即生成草稿而进入 `draft_correction` 自动补救轮次时，不再吞掉前一轮已经显示的回复。
- 做法：`AI制卡页` 处理 `draft_correction` 时保留已有 `正文`，仅追加换行并清除错误态；不改变 Runner 的有界循环、Provider 输入回放或 `propose_create_notes` 草稿边界。
- 备选：为每个 Provider 轮次创建独立 AI 气泡，因会扩大消息索引、历史恢复和草稿归属改动，本次不采用。
- 假设：同一个 AI 气泡承载一次用户请求的所有自动补救输出是现有交互约定；换行足以区分连续轮次。

### 验证

- 2026-08-31：新增 `draft correction keeps earlier visible model text instead of clearing the bubble` 回归测试；先在旧实现上确认失败，再以 `message.正文 += '\\n\\n'` 修复。
- 聚焦 Agent 契约测试通过；完整 `npm test` 通过，699/699。
