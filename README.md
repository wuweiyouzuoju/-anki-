# jidecards

jidecards 是一个基于 HarmonyOS 的 Anki 卡片学习客户端，复用 Anki 的 Rust 后端。

本项目与 Ankitects、AnkiWeb、AnkiDroid 无关，也未获得其认可。

## 功能特性

### jidecards 额外实现

在 Anki 核心功能之外，jidecards 额外实现了以下特性：

- **牌组背景自定义**：从图库选取图片裁剪后作为牌组背景，支持替换与清除
- **6 种颜色主题**：aurora / forest / midnight / lagoon / sunset / lemon，基于 HSV 自动派生完整色阶与语义色
- **热力图月历**：4 级热力色渲染学习日历，折叠/展开切换
- **浮动学习工具栏**：工具栏支持底部/浮动两种模式，浮动位置可拖动并吸附屏幕边缘
- **HarmonyOS 原生 TTS**：基于 CoreSpeechKit，队列播放、语种音色选择、引擎缓存
- **好评引导**：优先调用 AppGallery 应用内评价，失败回退 DeepLink 跳应用市场
- **中英双语界面**：内置中文 / English 切换
- **ArkUI 原生体验**：基于 ArkUI 声明式 UI 构建，非 WebView / 跨平台方案

### Anki 核心功能

复用 Anki rslib 后端，完整支持：

- FSRS 间隔重复调度算法
- AnkiWeb 同步（含媒体同步、自定义 TLS 证书）
- 图片遮罩笔记（Image Occlusion）
- 拼写填空（Cloze）类型卡片
- `.apkg` / `.anki2` 数据导入导出
- 卡片埋藏 / 暂停 / 撤销
- 学习统计

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
