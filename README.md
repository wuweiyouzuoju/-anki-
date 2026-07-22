# jidecards

jidecards is an independent, AGPL-licensed HarmonyOS phone and tablet client
that reuses Anki's Rust backend. It is not affiliated with or endorsed by
Ankitects, AnkiWeb, or AnkiDroid.

jidecards reuses Anki's Rust backend via a narrow C ABI and Node-API bridge,
with ArkUI for phone and tablet interfaces. See
[docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) for the full design and
[docs/architecture.md](docs/architecture.md) for the call chain and module
layout.

## Baseline

- Anki: `26.05` (`e64c6b1` release commit)
- Rust: `1.92.0`
- DevEco Studio: `6.1.0.860`
- Minimum system: HarmonyOS `5.0.0`, API 12
- Compile/target SDK: HarmonyOS SDK `6.1.0.105`, API 23
- Native targets: `aarch64-unknown-linux-ohos`, `x86_64-unknown-linux-ohos`

Features introduced after API 12 must have runtime capability checks and an
API 12 implementation or graceful fallback. Local study, import/export,
backup/restore, and collection integrity checks must remain available on API
12 devices.

## Build

### Prerequisites

- **DevEco Studio** with HarmonyOS SDK (provides `ohpm`, `hvigor`, and the
  OHOS native LLVM/clang toolchain)
- **Rust** `1.92.0` (see `rust-toolchain.toml`), with targets
  `aarch64-unknown-linux-ohos` and `x86_64-unknown-linux-ohos` installed
- **protoc** (Protocol Buffers compiler) on PATH
- **cargo-zigbuild** and **zig** (for host-test cross-compilation)
- **MSVC sysroot** for `x86_64-pc-windows-msvc` target: either install Visual
  Studio Build Tools, or generate an xwin sysroot (see below)

### Toolchain resolution

`tools/build-native.ps1` resolves the Rust/protoc/zig toolchain in three modes,
checked in order:

1. **`JIDECARDS_TOOLCHAINS` env var** — point it at a directory containing
   `cargo/`, `rustup/`, `protoc-31.1/`, `python/site/bin/cargo-zigbuild.exe`,
   and (for bundled mode) `zig-tar/` + `xwin-clang-cache/`.
2. **Bundled `work\toolchains\`** — the offline toolchain shipped in some
   internal builds. Not present in this release.
3. **External (PATH)** — if neither of the above is found, the script assumes
   `cargo`, `rustc`, `protoc`, `cargo-zigbuild`, and `zig` are already on
   `PATH`. In this mode, set `JIDECARDS_MSVC_SYSROOT` to your xwin sysroot
   path, or leave it unset if Visual Studio Build Tools are installed.

### Build steps

1. Restore HarmonyOS dependencies: `ohpm install`
2. Run toolchain diagnostics: `npm run doctor`
3. Full build (Rust + ArkTS + HAP): `npm run build:app`
4. Fast rebuild after Rust archives exist:
   `powershell -File tools/build-app.ps1 -SkipRust`

Run `npm test` for repository tests.

The debug build produces an unsigned HAP until a developer supplies a local
HarmonyOS signing configuration; signing credentials are never committed.

The implementation source of truth is
[docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).
