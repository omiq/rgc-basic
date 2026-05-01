# RGC-BASIC Distributables

Plan for packaging end-user RGC-BASIC programs into shippable binaries
with code + asset protection. Status: **proposal / scoping doc**.

## Three protection tiers

### Tier 1 — Casual (deters peeping)
- Minify + gzip the `.bas` source
- Embed as binary blob in tauri/PyInstaller wrapper
- Decompress in memory on launch
- **Effort:** ~1 day
- **Effectiveness:** stops `cat`, defeated by `strings`

### Tier 2 — Medium (recommended starting point)
- Compile `.bas` → bytecode (AST → opcode stream)
- Native interpreter ships VM, loads bytecode blob
- Source never leaves dev machine
- **Effort:** ~1–2 weeks (extend existing parser with emit + load)
- **Effectiveness:** no instant `cat foo.bas`. Reverse-engineerable but
  takes real work. Side benefit: faster cold start (no re-parse).

### Tier 3 — Strong (paid/commercial)
- Tier 2 + XOR/AES over bytecode + assets
- Key bundled (still better than plaintext) or machine-bound
- Periodic checksums detect tampering at runtime
- **Effort:** ~3–4 weeks
- **Effectiveness:** raises the bar significantly. Determined
  attacker still wins eventually, but mass piracy gets harder.

## Bundle format: `.rgcpkg`

Single file containing bytecode + every asset (sprites, music, data).

```
[8B magic 'RGCPKG\0\0']
[2B version]
[4B TOC offset]
[bytecode segment]      <- compressed (zstd-19 or lz4)
[asset segment]         <- compressed
[TOC: name → offset+len+type+compress_alg]  <- XOR-scrambled
```

### Wins
- One file ships the whole program (code + `.png` + `.mod` + `.wav`)
- zstd-19 ≈ 30–50 % smaller than raw + zip
- Scrambled TOC blocks `unzip -l foo.rgcpkg` style ripping
- Magic bytes ≠ ZIP/RAR/7z → `file foo.rgcpkg` reports "data"

### VFS integration
rgc-basic mounts bundle as VFS root. `LOADIMAGE "logo.png"` →
bundle lookup → in-memory decode. **Zero changes** to `.bas` source.

### Cracking effort
Still doable for determined attacker, but the easy attacks are blocked:
- "drag `.png` out of zip" → blocked (custom format)
- "open in hex editor and read text" → blocked (compressed + scrambled)
- Music/sprite ripping by asset extractors (Game Extractor, etc.) → blocked

## Build chain

```
foo.bas + assets/          rgc-pack         foo.rgcpkg
       ────────────►   (CLI + IDE button)   ──────────►   ship to user
                                                            │
                                                            ▼
                                              rgc-basic --run foo.rgcpkg
```

IDE adds **Build Distributable** action → generates either:
- Bare `.rgcpkg` (run with installed rgc-basic CLI), or
- Tauri-wrapped `.exe` / `.app` with `.rgcpkg` embedded as resource.

## Paid tier potential

Free tier could ship Tier 1 + bare `.rgcpkg`. Paid tier unlocks:
- Tier 3 protection (encrypted bundle)
- Tauri wrapper with custom icon/splash/about
- Code signing for mac/windows (covers signing fees)
- Steam-ready build pipeline (see below)
- Auto-update via tauri updater

## Steam distribution

`.rgcpkg` + tauri wrapper alone is **not enough** for Steam. Steam
expects native integration with Steamworks SDK and a specific build
pipeline.

### Required for Steam
| Item | What | Cost / Effort |
|------|------|---------------|
| Steam Direct fee | per-game | $100 USD per app ID |
| Steamworks SDK | Steam APIs, depots, build upload | Free (Valve) — needs C/C++ FFI binding |
| App ID | unique numeric ID for the game | obtained after Direct fee |
| Depot | platform-specific build (win/mac/linux) | per-platform build pipeline |
| `steamcmd` upload | CLI tool to push depots | free, scriptable |

### Recommended Steamworks features
- **Achievements** — flat key/value, easy via `ISteamUserStats`
- **Cloud saves** — Steam Auto-Cloud (no API needed) or Remote Storage
- **Steam Input** — controller remap UI handled by Valve
- **Rich Presence** — "Playing Level 3" status to friends
- **Workshop** — user-generated content (later)

### Optional (avoid early)
- Steam DRM wrapping — adds protection but complicates builds; usually
  not worth it for indie titles
- Anti-cheat — heavy, only relevant for multiplayer
- Multiplayer / lobbies / matchmaking

### Code signing fees (covered by paid tier?)
- Apple Developer Program: $99 USD/year (mac signing + notarization)
- Windows Authenticode: $200–$400 USD/year (varies by CA)
- Linux: no signing required

### Integration approach
Two options:

**A. FFI bindings** (purist, more work)
- Generate C bindings from steam_api.h
- Expose to rgc-basic via `STEAM.achievement_unlock(name)` calls
- Same binary works on/off Steam (graceful no-op if SDK absent)

**B. Tauri shim** (pragmatic, less code)
- Tauri host calls Steamworks SDK directly
- Sends events (achievements, cloud save) via IPC to rgc-basic
- rgc-basic stays Steam-agnostic; tauri layer handles platform

**Recommendation:** start with B. Cleaner separation. FFI later if
specific features need direct rgc-basic access.

### Build pipeline sketch

```
# CI per release
1. rgc-pack foo.bas + assets → foo.rgcpkg
2. tauri build --target x86_64-apple-darwin
3. tauri build --target aarch64-apple-darwin
4. tauri build --target x86_64-pc-windows-msvc
5. tauri build --target x86_64-unknown-linux-gnu
6. Sign mac (codesign + notarize)
7. Sign windows (signtool)
8. steamcmd run_app_build app_build_<APPID>.vdf
9. Push to Steam beta branch → smoke test → promote to default
```

## Compile farm as a service

Existing GitHub Actions already cross-builds rgc-basic native binaries.
Same pattern can run server-side to compile **user games + assets →
mac/win/linux/wasm `.zip`** on demand.

### Architecture

```
IDE upload (.bas + assets) → POST api/distribute/build.php
                                    │
                            queue + worker pool
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
       linux worker          win worker             mac worker
       (docker, musl)        (mingw or wine)        (real m1/m2 HW)
              │                     │                     │
              └────────► sign ──────┴──────► rgc-pack bundle
                                                      │
                                              s3/CDN + email link
```

### Per-platform reality

| Platform | Cross-compile | Notes |
|----------|---------------|-------|
| Linux x64/arm64 | gcc + musl in docker | static link, zero user deps |
| Windows x64 | mingw-w64 from linux | works. signtool needs windows or osslsigncode |
| macOS arm64/x64 | **NO** — Apple licensing | needs real mac. Mac mini M2 ~$500 one-time, or MacStadium ~$50/mo |
| WASM | emcc | already in CI |

### GitHub Actions vs self-hosted

| | GitHub Actions | Self-hosted (`makingpython`) |
|---|---|---|
| Setup | low (matrix yaml) | medium (worker mgmt) |
| Cost | free public / paid private | electric + hardware |
| Mac builds | real M1 runners ($0.16/min macOS) | local mac mini = unlimited |
| Queue time | minutes | seconds |
| Quotas | yes | no |

**Hybrid recommendation:** free tier hits GHA via API trigger; paid
tier hits local farm. Reuses idle server capacity.

### Existing infra leverage

- `scripts/update-ugbasic-docker.sh` model → same pattern for
  cross-toolchain images: `rgc-build-linux:latest`,
  `rgc-build-win:latest`, `rgc-pack:latest`.
- IDE already has compile-API pattern in `api/ugbasic/compile.php`.
  Add `api/distribute/build.php` mirroring it.
- Job ID = sessionID style. Poll endpoint for status. Final = signed
  URL to bundle.

### Scope estimate

- Linux + WASM only farm: **1-2 weeks** (extend existing infra)
- + Windows mingw + signing: **+1 week**
- + Mac (needs real hardware): **+2 weeks**

## Monetisation tiers

| Tier | Price model | Includes |
|------|-------------|----------|
| Free | $0 | Tier 1 protection, bare `.rgcpkg`, Linux + WASM build |
| Pro | one-off / Patreon $5/mo | Tier 2 bytecode, tauri wrapper, mac+win unsigned builds |
| Studio | Patreon $20/mo or one-off | Tier 3 encryption, signed mac+win builds, Steam pipeline assist |
| Verticals | per-kit licence | unlocks construction-kit packages (see below) |

Patreon-only releases of the desktop IDE itself are also a clean lever
— web IDE stays free forever, native binaries gated by tier.

## Construction-kit verticals

Modern reincarnations of classic 8-bit construction kits. Each is a
**curated rgc-basic project template** + asset library + bundled
runtime, sold/gated separately:

### Shoot-em-up Construction Kit (RGC-SEUCK)
- 80s SEUCK lineage. Vertical / horizontal scroller scaffold
- Sprite sheets, enemy patterns, boss waves, bullet patterns
- Drag-and-drop level editor in IDE
- Output: `.rgcpkg` per game, ships as standalone exe via compile farm

### Adventure Creator (RGC-ADV)
- GAC / Quill lineage. Text + parser-driven adventures
- Room graph editor, vocabulary list, conditional logic blocks
- Text + optional sprite illustration per room
- Optional retro target via ugBASIC for actual Spectrum/C64 adventures

### RPG Creator (RGC-RPG)
- RPG Construction Set / SCI lineage. Top-down 2D RPG
- Tilemap editor, party/inventory/quest systems
- Battle system templates (turn-based first, ATB later)
- Music + portrait packs

### Platformer Kit (RGC-PLATFORM)
- Mario/Sonic style sidescroller
- Tile collision, animation states, enemy AI patterns
- Power-ups, level transitions, save points

### Visual Novel Kit (RGC-VN)
- Ren'Py lineage. Scripted dialogue trees + character art
- Text-rendering w/ furigana / branching / autosave
- Easiest vertical to ship — most logic is data not code

### Why verticals win

- Lower bar to entry — buyer doesn't need to learn rgc-basic, just
  edit content
- Each kit is its own product/store page — discoverability
- Asset pack add-ons = recurring revenue (sprite packs, music packs,
  background packs)
- Power users can drop into raw rgc-basic to extend any kit
- Each vertical's `.rgcpkg` runs on the same runtime — one VM, many
  products

### Prior art reality
- GameMaker, RPG Maker, Construct 3 already do this on modern. Niche
  is **retro target output** + **portability across rgc-basic /
  ugBASIC retro hardware** in the same kit. SEUCK on a real C64 +
  modern desktop + WASM-in-browser from one project = unique angle.

## Open questions

- Bytecode format spec: stack VM vs register VM? Stack simpler, smaller.
- Asset compression: zstd-19 (slow encode, fast decode) or lz4 (fast both, weaker)?
- Bundle versioning: how do older `rgc-basic` runtimes handle newer bundles?
  Reject with version error vs forward-compat shim.
- Reseller channels beyond Steam: itch.io (no fees), GOG (curated),
  Epic Games Store (12 % cut).

## See also
- `working/compile.sh` — current ugBASIC retro compile path (different goal)
- `api/ugbasic/compile.php` — IDE-side cross-compile API
- Current native rgc-basic interpreter — already has parser + AST (foundation for bytecode emit)
