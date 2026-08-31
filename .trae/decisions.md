# Decisions

## 2026-08-31 — Agent 对话式配置、澄清与统一折叠

- 目标牌组、笔记类型和就绪状态属于本地助手设置卡，不伪装成 Provider 消息，也不进入 Provider 历史。
- 用户发送时冻结 `AgentTaskSnapshot`；可见文本隐藏稳定 ID，Provider 文本携带执行所需结构化上下文。
- `request_clarification` 是无写入工具。仅当它单独成功调用时，Runner 才以 `awaiting_clarification` 合法无草稿结束当前轮。
- 澄清气泡独立于运行消息；回答成功后保留并自动折叠，问题和回答进入同一逻辑会话的后续 Provider 回放。
- 设置、澄清和工具过程统一使用 `AgentDisclosureCard`：箭头 `▼`、0/-90 度旋转、150ms `Curve.EaseOut`，只动画箭头。
- 不改变 Anki Rust、protobuf、NAPI ABI、数据库、调度或现有草稿确认/高风险写入边界。
