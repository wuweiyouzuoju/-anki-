# jidecards

jidecards 是一个基于 HarmonyOS 的 Anki 卡片学习客户端，复用 Anki 的 Rust 后端。

本项目与 Ankitects、AnkiWeb、AnkiDroid 无关，也未获得其认可。

## 技术栈

- 前端：ArkTS / ArkUI（HarmonyOS）
- 后端：Anki rslib（Rust，通过 C ABI + Node-API 桥接）
- 许可证：AGPL-3.0-or-later

## 构建要求

- DevEco Studio + HarmonyOS SDK
- Rust 1.92.0（见 rust-toolchain.toml）
- protoc、cargo-zigbuild、zig

## 构建

```bash
ohpm install
npm run doctor
npm run build:app
```

测试：`npm test`

Anki 的 Rust 后端版权归 Ankitects Pty Ltd 所有，采用 AGPL-3.0-or-later 许可。
