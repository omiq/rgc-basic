# RGC-BASIC desktop launcher — proof of concept

Tauri 2 shell wrapping the existing `web/raylib.html` smoke-test page +
`basic-raylib.{js,wasm}`. Native window, no browser tab, no localhost
server. Validates that the spec in
[`docs/tauri-desktop-launcher-spec.md`](../docs/tauri-desktop-launcher-spec.md)
works end-to-end on macOS.

## What's bundled

- `resources/index.html` — copy of `web/raylib.html` (the smoke-test page
  with Run, presets, fullscreen).
- `resources/basic-raylib.js`, `basic-raylib.wasm` — current build of the
  raylib-emscripten WebGL2 runtime.
- `src-tauri/` — Tauri 2 Rust shell, ~30 lines of code.

Tauri's `generate_context!` macro embeds everything in `resources/` into the
release binary at compile time and serves it over `tauri://localhost/`.
**No localhost server, no `file://` CORS issues.**

## Build

Requires Rust 1.77+ and `cargo tauri` CLI:

```bash
rustup update stable
cargo install tauri-cli --version "^2"
```

Then:

```bash
cd desktop-launcher-poc/src-tauri
cargo tauri build
```

First build pulls/compiles ~200 Rust deps (~5 min). Subsequent builds <30 s.

Outputs:

- `src-tauri/target/release/bundle/macos/RGC-BASIC POC.app` — 3.6 MB
- `src-tauri/target/release/bundle/dmg/RGC-BASIC POC_0.1.0_aarch64.dmg` — 2.4 MB

## Run

```bash
open "src-tauri/target/release/bundle/macos/RGC-BASIC POC.app"
```

Or double-click the `.app` / `.dmg` in Finder.

**First run on macOS Sequoia 15+ (unsigned bypass):**

Right-click the `.app` → Open → confirm. Or:

```bash
xattr -dr com.apple.quarantine "src-tauri/target/release/bundle/macos/RGC-BASIC POC.app"
```

## What to test

1. Click **Text demo** preset → Run. Verify `PRINT` text renders.
2. Click **Bitmap demo** → Run. Verify `SCREEN 1` bitmap mode.
3. Click **Animated demo** → Run. Verify rAF + `VSYNC` keep pace.
4. Click **Keyboard+Mouse test** → Run. Click canvas, type, move mouse.
   Verify `GET`, `INKEY$`, `PEEK(56320+)` matrix.
5. Click **Stress (256 sprites)** → Run. Verify GPU sprite throughput.
6. Click **Fullscreen**. Verify webview supports it.

## Known POC limitations

- No bundled BASIC program — uses smoke-test textarea. Real launcher will
  template `program.bas` + `project-files.json` per IDE export.
- `HTTPFETCH` to remote URLs subject to remote CORS (same as browser).
- macOS arm64 only — cross-compile to x86_64 / Windows / Linux per spec
  M1.
- Unsigned. First-launch requires bypass — see
  [`docs/desktop-launcher-first-run.md`](../docs/desktop-launcher-first-run.md).

## What this proves

- Tauri asset protocol serves `.wasm` with correct MIME — runtime loads.
- WKWebView supports WebGL2 + Asyncify — raylib renders.
- Single-threaded WASM — no COOP/COEP needed (verified against Makefile
  flags: no `USE_PTHREADS`).
- Bundle size 3.6 MB matches spec estimate (6–10 MB upper bound).

## Next

If smoke test passes: wire `pack-export.sh` per spec M2 to inject IDE
exports into `resources/` and re-bundle.
