# jidecards

jidecards 是一个基于 HarmonyOS 的 Anki 卡片学习客户端，复用 Anki 的 Rust 后端。

本项目与 Ankitects、AnkiWeb、AnkiDroid 无关，也未获得其认可。

## 功能特性

- **牌组背景自定义**：从图库选取图片裁剪后作为牌组背景，支持替换与清除
- **图片遮罩笔记（Image Occlusion）**：Canvas 拖拽创建矩形遮罩，支持编号选中与命中检测
- **拼写填空（Cloze）**：解析 `{{c1::内容::提示}}` 语法，比对答案并高亮正确/错误/遗漏
- **FSRS 调度算法**：首次启动自动开启 FSRS 并重调度，支持开关切换
- **学习统计与热力图日历**：4 级热力色渲染月历，折叠/展开切换
- **主题切换**：深色/浅色/跟随系统 + 6 种颜色主题（aurora/forest/midnight/lagoon/sunset/lemon），HSV 派生完整色阶
- **AnkiWeb 同步**：登录/集合同步/全量上传下载/媒体同步/自定义 TLS 证书
- **TTS 语音播放**：基于 CoreSpeechKit，队列播放、语种音色选择、引擎缓存
- **数据导入导出**：支持 `.apkg` / `.anki2`，可携带调度、配置与媒体
- **学习布局自定义**：工具栏支持底部/浮动两种模式，浮动位置可拖动并吸附边缘
- **卡片埋藏/暂停/撤销**：完整支持单卡与牌组级别的埋藏、暂停、恢复、撤销
- **好评引导**：优先调用 AppGallery 应用内评价，失败回退 DeepLink 跳应用市场
- **中英双语界面**：内置中文/English 切换

## 技术栈

- 前端：ArkTS / ArkUI（HarmonyOS）
- 后端：Anki rslib（Rust，通过 C ABI + Node-API 桥接）
- 许可证：AGPL-3.0-or-later

## 构建要求

- DevEco Studio + HarmonyOS SDK
- Rust 1.92.0（见 rust-toolchain.toml）
- protoc、cargo-zigbuild、zig

## 获取 Anki 源码

本项目的 Rust 后端依赖 Anki rslib。构建前需将 Anki 源码放置到 `third_party/anki/`：

```bash
git clone https://github.com/ankitects/anki.git third_party/anki
```

Anki rslib 版权归 Ankitects Pty Ltd 所有，采用 AGPL-3.0-or-later 许可。

## 构建

```bash
ohpm install
npm run doctor
npm run build:app
```

测试：`npm test`
