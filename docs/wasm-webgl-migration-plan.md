# WASM Renderer Migration: Canvas → raylib-emscripten (WebGL2)

**Status:** Proposal / planning. Not yet implemented.
**Owner:** Chris Garrett
**Target platform:** basic-gfx WASM build, primarily consumed by the RetroGameCoders IDE (8bitworkshop fork) via iframe.
**Goal:** Make the WASM build perform well enough for arcade-style games (shoot-em-ups with many sprites, parallax scroll, alpha blend) by moving from CPU software rasterisation to GPU-accelerated rendering in the browser.

---

## 1. Context

### 1.1 Today

The WASM build (`web/basic-canvas.wasm` + `web/basic-canvas.js`) uses `gfx/gfx_canvas.c` — a pure CPU software rasteriser that writes RGBA into a buffer and pushes it to a `<canvas>` via JS `putImageData`. No GPU involvement.

For a shoot-em-up load (many sprites × alpha blend × 60 fps), per-sprite CPU compositing is the bottleneck. Final blit is negligible. Therefore moving to WebGPU purely for the final blit (keeping `gfx_canvas.c`) would not help.

### 1.2 Target

Switch the WASM renderer to `gfx/gfx_raylib.c` compiled with Emscripten, using raylib's emscripten backend which runs on GLFW + WebGL2. Same source file as the desktop build — one renderer for desktop and web.

Sprite path becomes GPU-accelerated (`DrawTexturePro` batches into a handful of GL draw calls per frame regardless of sprite count). Alpha blend, rotation, tint all done in the GPU. Parallax scroll via UV offset rather than full framebuffer redraw.

### 1.3 Non-goals

- WebGPU. Emscripten's WebGPU path via `--use-port=emdawnwebgpu` works but raylib has no WebGPU backend as of raylib 6.0 (23 Apr 2026), and maintainers have stated they will not pursue one (discussion #4505). Revisit only if a stable third-party backend (e.g. `raygpu`) matures.
- Rewriting the interpreter. Only the rendering path moves.
- Removing the canvas renderer immediately — see §4 (Parallel maintenance).

---

## 2. IDE integration surface

The IDE (8bitworkshop fork at `/Users/chrisg/github/8bitworkshop`) embeds rgc-basic in a **same-origin iframe**. Two integration points exist:

### 2.1 postMessage protocol (well-defined, unaffected)

From `src/platform/rgcbasic.ts`:

- `rgc-basic-run` (parent → iframe): start program
- `rgc-basic-pause` (parent → iframe): pause execution
- `rgc-basic-resume` (parent → iframe): resume execution
- `rgc-basic-status` (iframe → parent): state change
- `rgc-basic-runtime-error` (iframe → parent): error reporting

This contract must be preserved by the new runtime. No changes required in the IDE if the new iframe page implements the same handlers.

### 2.2 Keyboard input (historically problematic — must be re-verified)

Keyboard forwarding from browser → BASIC has been a recurring source of bugs (ghost keys, unresponsive keys, stuck-down state, focus traps). The current flow (`web/canvas.html:677-687`):

1. Parent IDE creates iframe with `tabindex="-1"` and stops `focus`/`blur` propagation from the iframe (`src/platform/rgcbasic.ts:77-82`) to keep the editor focused while the program runs.
2. Inside the iframe, the `<canvas>` element has `tabindex="0"` and is focused manually after `Run` (`canvas.focus()` at `canvas.html:608`).
3. `keydown` / `keyup` listeners on the canvas map `ev.key` → C64-style index (`wasmGfxKeyIndex`), then write **directly into the WASM heap** (`Module.HEAPU8[key_state_ptr + idx] = down ? 1 : 0`) rather than calling into the interpreter. This is deliberate: `ccall` during Asyncify SLEEP re-enters the interpreter and corrupts state.
4. A separate `wasm_push_key(ccall)` pushes ASCII into an INKEY$ queue on keydown only.
5. On `keyup`, `key_state[idx]` is cleared. INPUT mode bypasses the whole thing and uses a regular `<input>` field.

**Historical failure modes that MUST be re-validated on the raylib path:**

| Failure | Cause | Mitigation (current / needed) |
|---|---|---|
| Canvas has no focus → no keys | IDE swallows iframe focus; user must click canvas | Auto-focus on program start; visual focus indicator |
| Stuck keys (held-down state never clears) | `keyup` missed if window/tab blurred mid-press | `blur` / `visibilitychange` listener clears all `key_state` |
| Ghost repeats | OS key-repeat fires repeated `keydown` events → `wasm_push_key` queue overflows INKEY$ | Suppress repeat via `ev.repeat` filter |
| Browser default swallows key | e.g. arrows scroll page, Space submits form | `ev.preventDefault()` on known game keys only; don't grab Ctrl+key |
| Ccall during SLEEP crashes | Asyncify re-entry | Write directly to HEAPU8; never ccall from key listeners |
| IDE shortcut vs game input collision | Ctrl+S / Ctrl+R fires in IDE before iframe sees key | Document that iframe doesn't receive modified keys; no workaround |
| `ev.key` values differ per browser | `"Spacebar"` (old IE/FF) vs `" "`; `"Esc"` vs `"Escape"` | Already handled in `wasmGfxKeyIndex`; audit for raylib path |
| Shift / Ctrl / Alt not modelled in `key_state` | BASIC can't read modifiers | Explicit TODO — not a regression, but a gap |

**For the raylib-emscripten path:**

raylib reads input via GLFW's own key callbacks registered on the canvas. This *replaces* the current hand-rolled listeners. Implications:

- GLFW uses `KeyboardEvent.code` (physical key) rather than `ev.key` (logical char). Layout-independent, better for games (WASD is always WASD), worse for typing languages (no layout awareness).
- GLFW's callback writes into raylib's own key-state arrays, not our `key_state[]`. Need a shim that either: (a) bridges raylib's `IsKeyDown(KEY_W)` into the existing `PEEK(56320+87)` API by mirroring at each frame, or (b) rewrites `gfx_video.c`'s key-state model to read from raylib directly under `__EMSCRIPTEN__`/native.
- `ccall`-during-SLEEP problem: raylib's callbacks fire from GLFW → JS → main loop, not from a user listener; re-entry shape is different. Must verify Asyncify behaviour end-to-end with a SLEEP-heavy program.
- Focus: GLFW canvas focus is managed by GLFW, not by `canvas.focus()`. Need to hook the same "click to gain focus" flow and avoid IDE focus conflicts.
- INKEY$ queue: current queue is fed from keydown. Port to raylib's `GetCharPressed()` / `GetKeyPressed()` which are polled per frame — natural fit for the per-frame main loop.
- `ev.repeat` behaviour under GLFW: verify repeats are suppressed or configurable.

**Action item:** before flipping the default to raylib, run a regression test covering:

- Press-and-hold (diagonal movement in a shmup: Left+Up simultaneously)
- Rapid tap bursts (fire button at max rate)
- Release-during-blur (Alt+Tab away mid-press, return → no stuck keys)
- Modal INPUT mid-game (sim: `INPUT name$` during game loop; verify `key_state` clears, field receives keys, game resumes cleanly)
- IDE editor keypresses don't leak into the running program and vice versa

Add these as automated browser tests in `tests/wasm_browser_*.py` (or equivalent Playwright/Puppeteer) before default switch.

### 2.3 Direct DOM canvas access (for screenshot / recording)

From `src/ide/shareexport.ts:656-725` (`findPrimaryEmulatorCanvas`):
- IDE reaches into `iframe.contentDocument.querySelector('canvas')` to grab the framebuffer canvas element.
- Calls `canvas.toBlob(...)` for PNG export.
- Falls back to `canvas.captureStream(30)` + `ImageCapture.grabFrame()` for WebGL canvases that return blank from `toBlob` when `preserveDrawingBuffer` is false (Chrome/Edge only; other browsers fall back to `toBlob` after `requestAnimationFrame`).

**Implication for migration:** raylib-emscripten creates a WebGL2 canvas via GLFW. By default, WebGL contexts have `preserveDrawingBuffer: false`, which breaks `canvas.toBlob()` (returns blank PNG). Two options:

- **Option A (preferred, simplest):** set `preserveDrawingBuffer: true` when raylib/GLFW creates the context. In Emscripten, this is configurable via `Module.webglContextAttributes = { preserveDrawingBuffer: true }` before GLFW init. Minor GPU-side cost (driver keeps backbuffer), but screenshot works from any browser without the captureStream fallback path.
- **Option B (no C changes):** rely on IDE's existing `captureStream` fallback. Works in Chrome/Edge today. May fail in Firefox/Safari depending on ImageCapture availability. Risky.

**Decision:** go with Option A. Enable `preserveDrawingBuffer: true` in the new iframe page's Module config. Document the minor perf cost in the page header. No IDE changes needed.

### 2.4 Bonus: features tier 1 unlocks for free

Moving to raylib-emscripten also brings raylib's wider platform support into WASM for free:

- **Audio.** raylib-web links miniaudio via Emscripten. `LoadSound`, `PlaySound`, streaming music, mixing — all available without writing Web Audio glue. Lets us design proper `SOUND` / `PLAY` BASIC primitives once and have them work on desktop + web with identical semantics.
- **Gamepad / joystick.** raylib exposes GLFW's gamepad API (`IsGamepadAvailable`, `GetGamepadAxisMovement`, `GetGamepadButtonPressed`) which wraps the browser Gamepad API on web. This is the *right* foundation for a bartop arcade — physical sticks on Pi, virtual touch-joystick on mobile, Xbox/PS controllers on desktop, all one code path.
- **Touch input.** raylib reports touches on mobile via the same gamepad/mouse abstractions.

None of these are free on the current canvas path — they'd each need bespoke JS plumbing, and then parallel plumbing for desktop. Tier 1 consolidates them.

Implied work once tier 1 lands: add BASIC-level verbs (`SOUND`, `PLAY`, `LOADSOUND`, `GAMEPAD()`, `GAMEPADBTN()`, etc.) that wrap raylib's audio + gamepad APIs. Track as a follow-up plan (`docs/audio-gamepad-plan.md`, not part of this migration).

---

## 3. Migration plan

### 3.1 Build system

New Makefile target `basic-wasm-raylib`:

```
basic-wasm-raylib: $(GFX_BIN_SRCS)
	$(EMCC) -w -O2 -DGFX_VIDEO -Igfx \
	    -sUSE_GLFW=3 -sFULL_ES3=1 -sASYNCIFY \
	    -sALLOW_MEMORY_GROWTH=1 \
	    --preload-file examples \
	    -I<raylib-emscripten>/include \
	    -L<raylib-emscripten>/lib -lraylib \
	    -o web/basic-raylib.js $(GFX_BIN_SRCS)
```

Raylib must be pre-built for emscripten (`cd raylib/src && make PLATFORM=PLATFORM_WEB`) and the resulting `libraylib.a` linked here. CI needs an emscripten toolchain + raylib-web build step.

### 3.2 Main loop on web

`gfx/gfx_raylib.c` currently runs the interpreter in a `pthread`. Emscripten pthread requires SharedArrayBuffer + COOP/COEP headers — painful for GitHub Pages and third-party embeds. Avoid.

Instead, under `__EMSCRIPTEN__`:

- Skip `pthread_create`. Run the interpreter on the main thread.
- Replace the `while (!WindowShouldClose())` loop with `emscripten_set_main_loop_arg(tick, &ctx, 60, 1)` where `tick` executes interpreter steps + one render frame.
- Keep the existing Asyncify-based sleep mechanism (`wasm_sleep_deadline_ms`, `emscripten_sleep`) as-is — it already yields to the browser event loop between statements so timers pump correctly.

This mirrors how the current `basic-canvas.wasm` handles sleep and timers. No new threading model.

### 3.3 Iframe shell

Current: `web/canvas.html` (wrapper around `basic-canvas.js`).

Add: `web/raylib.html` (wrapper around `basic-raylib.js`). Both:

- Accept the same query parameters (`?program=...`, etc.) so `rgc-basic-iframe.html` can route to either.
- Implement the same postMessage contract (§2.1).
- Preload the same assets.

### 3.4 Runtime switch

`web/rgc-basic-iframe.html` (the entry URL the IDE iframes):

```html
<script>
  const params = new URLSearchParams(location.search);
  const renderer = params.get("renderer") || "canvas";
  const src = renderer === "raylib" ? "raylib.html" : "canvas.html";
  location.replace(src + location.search);
</script>
```

IDE change (one line): `rgcbasic.ts` constructs the iframe URL. Add `?renderer=raylib` when an opt-in flag is set (user preference, per-program `#OPTION renderer`, or build-time default). No contract changes.

Default stays `canvas` during parallel period. Flip to `raylib` once parity is verified.

### 3.5 Asset cache-busting

`src/platform/rgc-basic-asset-cb.gen.ts` currently bumps on `basic-canvas.js/.wasm` changes. Extend to cover `basic-raylib.js/.wasm` too. `scripts/sync-rgc-basic.sh` already copies the published web artefacts — update to include both pairs.

---

## 4. Parallel maintenance policy

Both renderers live in the tree during migration. To keep the cost bounded:

### 4.1 Feature freeze on `gfx/gfx_canvas.c` (ACCEPTED 2026-04-17)

Policy now in effect:

- **No new BASIC graphics features land in `gfx_canvas.c`.** Any new sprite, bitmap, tile, font, shader, or input feature goes into `gfx_raylib.c` only. Users who want new features must select `?renderer=raylib`.
- **Bug fixes only** for `gfx_canvas.c`: crashes, incorrect rendering of existing features, security issues, build breakage. Anything that makes already-shipped programs wrong.
- **No refactors** in `gfx_canvas.c`. Churn there costs test time we'd rather spend on raylib path.

A policy header is committed at the top of `gfx/gfx_canvas.c` itself so contributors hit the rule before editing.

### 4.2 Parity checklist (tracked in a new `docs/wasm-raylib-parity.md`)

The raylib-emscripten path must match `gfx_canvas.c` feature-by-feature before default switch:

- [ ] 40×25 text mode, both charsets, cursor, reverse video, PETSCII
- [ ] 320×200 bitmap mode, PSET/PRESET/LINE, BITMAPCLEAR
- [ ] 80-column text mode (if canvas supports it currently)
- [ ] Border padding + border colour
- [ ] Sprite load (PNG, tile sheets)
- [ ] Sprite composite, z-order, per-sprite tint / rotation / scale
- [ ] Keyboard polling (`PEEK(56320+code)`, `INKEY$`)
- [ ] Mouse (position, buttons)
- [ ] Gamepad (if canvas supports it)
- [ ] Audio (if canvas supports it) — raylib web uses miniaudio
- [ ] `.seq` art viewer
- [ ] Font loading (when `bitmap-text-plan.md` lands)
- [ ] Viewport scroll (`#OPTION scroll`)
- [ ] Screenshot via `canvas.toBlob` (requires `preserveDrawingBuffer: true` — §2.2)
- [ ] Fullscreen via `-fullscreen` flag (browser Fullscreen API, letterbox)
- [ ] HTTP VFS asset loading (`docs/http-vfs-assets.md`)

### 4.3 WordPress plugin + web embed surface (must not regress)

Beyond the IDE (`8bitworkshop` fork) there are several *independent* embed paths that also depend on the current canvas runtime. These must be either continuously tested against both renderers or explicitly scoped out of raylib support with a user-visible limitation.

Known embed surfaces in this repo:

| Surface | Files | Contract |
|---|---|---|
| WordPress tutorial block | `wordpress/rgc-basic-tutorial-block/assets/js/gfx-embed-mount.js`, `tutorial-embed.js`, `basic-highlight.js`, `vfs-helpers.js` | Loads `basic-canvas.js` into a `<div>` inside a WP page; exposes Run / Stop and a framebuffer canvas. May be embedded in third-party WP sites we don't control. |
| Tutorial example page | `web/tutorial-example.html`, `web/tutorial-gfx-features.html` | Standalone HTML demonstrating iframe/div embed patterns — doubles as doc + manual regression target. |
| Host-exec embed | `web/host-exec-example.html` | External page embedding basic-canvas with a host-driven exec harness. |
| IDE iframe (primary) | `web/canvas.html` via `rgc-basic-iframe.html` | Covered in §2. |
| Direct canvas page | `web/index.html` | Standalone demo of the canvas build. |

Policy for each surface during migration:

1. **Audit** each page's assumptions about global `window.Module` shape, `Module.canvas`, `basic-canvas.js` URL, and any direct `HEAPU8` / `ccall` usage. Record findings in a follow-up `docs/wasm-embed-audit.md` once scanned.
2. **Dual-renderer support**: every embed page that today loads `basic-canvas.js` should gain an opt-in `?renderer=raylib` or a `data-renderer="raylib"` attribute that loads the raylib variant instead. Embed consumers who do not opt in keep the current canvas runtime, frozen.
3. **Continuous testing**: add a smoke test in `tests/wasm_browser_*.py` (or Playwright) for each embed surface that boots the page, runs a canonical `.bas`, and asserts the framebuffer produces a non-blank PNG. Run under both `canvas` and `raylib` variants. Failing either renderer fails CI.
4. **Versioned URLs**: `src/platform/rgc-basic-asset-cb.gen.ts` already cache-busts `basic-canvas.*`. Extend to `basic-raylib.*`. Publish both bundles to the WordPress plugin release asset pipeline.
5. **Documented limitations**: if any embed surface is NOT ported to raylib (e.g. because its host page injects framebuffer JS directly), document that in the embed's README with a clear "`?renderer=canvas` only; new graphics features unavailable here" notice, and decide whether to freeze-and-keep or deprecate-and-remove that embed before the final canvas retirement (§4.4).
6. **WordPress plugin release**: the plugin (`wordpress/rgc-basic-tutorial-block/`) ships its own asset bundle. The migration plan is not complete until a WP plugin release is published that ships the raylib bundle alongside the canvas bundle, and a post-migration release that removes the canvas bundle when §4.4 fires.

### 4.4 Retirement

After the raylib path has been default for ~3 months with no blocking regressions, delete:

- `gfx/gfx_canvas.c`
- `web/canvas.html`, `web/basic-canvas.js`, `web/basic-canvas.wasm`
- Related Makefile targets
- Canvas-only tests (or port to raylib path)

Keep the `?renderer=canvas` query param wired up to return HTTP 410 or a deprecation page, so old bookmarks don't silently break.

---

## 5. Schedule estimate

Rough, assuming evenings/weekends:

| Week | Milestone |
|------|-----------|
| 1 | `basic-wasm-raylib` builds, loads in iframe, renders static text screen |
| 2 | Main-loop integration (interpreter + Asyncify sleep + timer pump); 40×25 text parity; keyboard input |
| 3 | Bitmap mode, sprites, mouse, audio parity |
| 4 | Iframe switch live (`?renderer=raylib` opt-in); screenshot verified; IDE tested end-to-end |
| 5–8 | Dogfood, bug reports, perf measurements with real shmup-shaped programs |
| 9 | Default flips to raylib |
| 12+ | Retire canvas renderer |

Ongoing maintenance drag during parallel period: ~1–2 hr/week assuming freeze policy is honoured.

---

## 6. Risks

- **WebGL2 context creation failures** on blocklisted GPUs. Mitigation: iframe detects `WEBGL_CONTEXT_LOST` and falls back to `?renderer=canvas` automatically with a user-visible notice.
- **WASM bundle size** increases by ~300–500 KB (raylib + GLFW). Mitigation: accept; measure with `wasm-opt -Oz`; consider code splitting if it proves painful.
- **Startup time** slower than canvas path. Mitigation: show loading indicator; ensure the iframe still emits `rgc-basic-status: ready` at the right moment so IDE doesn't time out.
- **Audio system change.** Current canvas path's audio (if any) may differ from raylib's miniaudio. Audit during parity work.
- **Asset loading path.** Current `basic-canvas.js` uses Emscripten MEMFS / `--preload-file`. Verify raylib build uses the same `FS.writeFile` / preload semantics so `LOAD`, `LOADSPRITE`, etc. work unchanged.
- **IDE version skew.** If the IDE ships a version that assumes raylib and a user loads an old canvas build (or vice versa), the postMessage contract must remain compatible across versions. Version the contract if it ever grows.

---

## 7. Open questions

- Do we ship `?renderer=raylib` as a user-level preference in the IDE (persisted per user), per-program (`#OPTION renderer raylib` inline), or both?
- Should `-fullscreen` translate to the browser Fullscreen API in WASM, or continue to be a no-op?
- Keep `basic-modular.wasm` (the ES module variant) in sync with both renderers, or only raylib?
- Third-party embeds (WordPress block, tutorial pages, host-exec): covered by §4.3. Audit pending; track in `docs/wasm-embed-audit.md` once started.
