## Changelog

### 2.0.1 – 2026-04-21

Fix: bundled tracker modules (`examples/music/*.mod`) were missing
from the v2.0 release archives. Root cause: `.gitignore` carries a
`*.mod*` rule (Linux kernel build artifact convention) that also
swept the `.mod` tracker files under its net, so they were never
`git add`ed. `LICENSES.md` shipped (.md extension), the nine MOD
files didn't, and CI — cloning a clean repo at tag time — had
nothing to bundle.

Added `!examples/music/*.mod` negation to `.gitignore`, committed
the nine MODs, cut 2.0.1. Content-identical to 2.0 otherwise; only
the release archives differ.

### 2.0 – 2026-04-21

**Music milestone.** Streaming tracker-module playback ships end to
end on **basic-gfx** and **basic-wasm-raylib**, with nine bundled
Public Domain MODs and a rich music demo.

**New BASIC statements:**

- `LOADMUSIC slot, "path"` / `UNLOADMUSIC slot` — load / free a
  streaming track (MOD / XM / S3M / IT / OGG / MP3).
- `PLAYMUSIC slot` / `STOPMUSIC slot` / `PAUSEMUSIC slot` /
  `RESUMEMUSIC slot` — transport control.
- `MUSICVOLUME slot, 0.0..1.0` / `MUSICLOOP slot, 0|1` — per-slot
  gain + repeat-on-end.

**New BASIC functions:**

- `MUSICPLAYING(slot)` — 1 while audible, 0 when idle / paused.
- `MUSICLENGTH(slot)` — total seconds. For MOD the length is computed
  in `gfx_sound.c` by walking the pattern / order table honouring
  `Fxx` (speed / BPM), `Bxx` (order jump), `Dxx` (pattern break), and
  `E6x` (pattern loop), with a 2-visit cap per order entry and a
  200 000-row budget. Cached at `LOADMUSIC`. Non-MOD formats fall
  back to raylib's `GetMusicTimeLength`. Returns `0.0` when unknown.
- `MUSICTIME(slot)` — elapsed seconds via `GetMusicTimePlayed`.
  Wraps on loop. Requires the raudio `modCount` cap patch (below).
- `MUSICPEAK()` — `0..1` master-mix held-peak, decays ~`0.92` per
  mix chunk. Suitable for VU bars. Global (raylib's stream-processor
  API carries no userdata).
- `MUSICTITLE$(slot)` — 20-byte MOD title, trimmed.
- `MUSICSAMPLENAME$(slot, idx)` — 22-byte sample name, idx 0..30.
- `MUSICCHANNELS(slot)` — parsed from the MOD tag at offset 1080.
- `MUSICPATTERNS(slot)` — unique patterns = `max(order[]) + 1`.
- `MUSICORDERS(slot)` — order-table length (MOD song-length byte).
- `MUSICSAMPLECOUNT(slot)` — 31 for classic MODs, 0 otherwise.

**Under the hood:**

- `gfx/gfx_sound.c` — tracker-module pool separate from the WAV pool,
  per-slot length cache + 20-byte title + 31-sample name table parsed
  at load time, master-mix peak tap via `AttachAudioMixedProcessor`.
- `patches/jar_mod_max_samples.patch` — chunked 4096-sample decode for
  `jar_mod_max_samples` (web freeze mitigation — see 2026-04-20 entry
  below for the history).
- `patches/raudio_mod_skip_max_samples.patch` — now also caps the
  `GetMusicTimePlayed` modulo at `INT_MAX` when `music.frameCount ==
  UINT_MAX` (the unconditional MOD skip). Without this the upstream
  `(int)music.frameCount` underflows to `-1` and `MUSICTIME()` sticks
  at zero on MOD tracks.
- `scripts/build-raylib-native.sh` + `scripts/build-raylib-native.cmd`
  — clone + patch raylib 5.5 into `third_party/raylib-native/`, build
  a static `libraylib.a` that `basic-gfx` links against. No system
  libraylib dependency; no MinGW mingw-w64-raylib dependency on
  Windows. See the "build system" hunk for the per-OS link set.
- `.gitattributes` — `patches/*.patch text eol=lf` pins LF on the
  patch tree so Git-for-Windows `autocrlf` doesn't silently rewrite
  them to CRLF and cause `git apply` to fail the whitespace check.
- CI: nightly + tag workflows (`.github/workflows/{nightly,ci}.yml`)
  drop the old system-raylib install and build the patched raylib
  from source on Linux / macOS / Windows. "Not a full CI without the
  patched audio path" is now enforced end-to-end.
- IDE asset preload (`src/ide/ui.ts`, `src/ide/shareexport.ts`,
  `rgc-basic-iframe.html`, `rgc-basic-raylib-iframe.html`) — regex
  now also catches string literals whose extension matches a known
  asset type, so programs that stash paths in variables or DIM arrays
  (e.g. `PATH$(N) = "music/foo.mod"`) get their assets auto-fetched
  into MEMFS before the program runs.
- `scripts/sync-rgc-basic.sh` — tracker modules copied into
  `presets/rgc-basic/music/` preserving the subdir (was flat before,
  which meant `LOADMUSIC "music/foo.mod"` missed on the IDE).
- `rgc-basic-raylib-iframe.html` — `keyIndex` now forwards all
  printable ASCII (32..126) into `key_state[]`, not just alpha +
  digits. Fixes `KEYPRESS(ASC("+"))` / `ASC("=")` / `ASC("-")` in the
  music-volume controls (and any program using punctuation keys).

**Docs:**

- `README.md` feature bullet for music, alongside the existing sound
  bullet.
- `retrodocs/.../rgc-basic/language.md` intrinsic table extended with
  the whole `MUSIC*` family.
- `docs/rgc-sound-sample-spec.md` status flipped from "design only"
  to "shipped" with pointer back to this CHANGELOG entry.

**Tooling / CLI:**

- `-v` / `-V` / `--version` flag on `basic` and `basic-gfx` prints
  `RGC-BASIC <version> (<release-date>) — <variant>` and the repo
  URL, then exits. Version is injected at build time via
  `git describe --tags --dirty --always`; release date is the
  tagged commit's committer-date. Release tarballs without a
  `.git` directory fall through to `dev` / `unknown`, overridable
  with `make RGC_BASIC_GIT_VERSION=v2.0.0
  RGC_BASIC_GIT_DATE=2026-04-21`. Defines are also plumbed into
  every `basic-wasm*` build for the browser console banner.

**Bundled demo:**

- `examples/gfx_music_demo.bas` — keys 1..9, two-column track list,
  NOW PLAYING strip with title + channel / pattern / order / sample
  counts + first 4 sample names, elapsed / length display,
  proportional progress bar, 32-bar green/yellow/red VU, 32-bar
  volume meter. `DOUBLEBUFFER ON` + `VSYNC` so the VU doesn't
  flicker. Synced to `presets/rgc-basic/gfx_music_demo.bas`.
- `examples/music/` — nine Public Domain tracks from modarchive.org
  (total ~1.4 MB). See `examples/music/LICENSES.md` for credits.

### Music metadata + VU meter (2026-04-21)

_(Historical working entry; folded into **2.0.0** above. Kept here
for the incremental diff record.)_

- `MUSICLENGTH(slot)`, `MUSICTIME(slot)`, `MUSICPEAK()` added.
- MOD length computed via pattern-walker in `gfx_sound.c`.
- `AttachAudioMixedProcessor` master-mix peak tap.
- `examples/gfx_music_demo.bas` rewritten with time display, progress
  bar, VU meter, volume meter.

### MOD load freeze fix (2026-04-20)

**Bug:** `LOADMUSIC <slot>, "*.mod"` froze the browser on the
`basic-wasm-raylib` target. Chrome's "page unresponsive" dialog would
fire within a few seconds of pressing a track-select key in
`examples/gfx_music_demo.bas`. The tab had to be force-closed. Other
formats (WAV via `LOADSOUND`) were unaffected. Native `basic-gfx`
played MOD files fine.

**Root cause:** raylib 5.5 (pinned by `scripts/build-raylib-web.sh`)
calls `jar_mod_max_samples` inside `LoadMusicStream` at
`third_party/raylib-src/src/raudio.c:1486` to compute the
`music.frameCount` field. Upstream `jar_mod_max_samples` is implemented
as a full-song simulation that calls `jar_mod_fillbuffer` with
`nbsample=1` — one stereo pair per iteration. For a 3-5 minute MOD at
48 kHz that's 10-15 million iterations on the main thread. Native
builds finish in a few hundred milliseconds. The web build compiles
with `-s ASYNCIFY=1` (so BASIC's `SLEEP` and our async HTTP helpers
can yield), which wraps every wasm function call in asyncify state
bookkeeping. Under asyncify the same loop runs 50-200x slower, blocking
the main thread for tens of seconds. Chrome interprets that as a hung
renderer.

The upstream source even admits the problem:

```c
// Works, however it is very slow, this data should be cached to
// ensure it is run only once per file
mulong jar_mod_max_samples(jar_mod_context_t * ctx)
```

**Fix:** `patches/jar_mod_max_samples.patch` decodes in 4096-sample
chunks instead of 1. Same `samplenb` result (jar_mod accumulates it
regardless of chunk size); the `while (loopcount <= lastcount)` exit
condition still fires when the song wraps. `~4000x` fewer iterations
— LOADMUSIC now returns in tens of milliseconds on the web build.

Applied automatically by `scripts/build-raylib-web.sh` step 2b after
the raylib tag checkout, so fresh clones and `RAYLIB_FORCE=1` rebuilds
both pick it up. Idempotent — re-runs skip already-applied patches
rather than failing.

**⚠ Notes for future work / future agents:**

1. `third_party/raylib-src/` is gitignored. **Do not** commit a modified
   `jar_mod.h` to the repo directly — it would be wiped on the next
   `rm -rf third_party/raylib-src/` and give the false impression the
   fix had been lost. The canonical copy lives in
   `patches/jar_mod_max_samples.patch`.
2. If someone bumps `RAYLIB_VERSION` in `scripts/build-raylib-web.sh`
   and the patch hunk drifts, the build script fails at step 2b with a
   clear error. Rebase the patch against the new tag. Before rebasing,
   check whether upstream has merged an equivalent fix — remove the
   patch file entirely and note it here if so.
3. The same pattern (single-sample simulation) likely exists in `jar_xm`
   (XM format) — if we ever add XM support to the bundled demos, test a
   long track on the web build first. If it hangs, clone the approach
   used in this patch.
4. Diagnostic tool of record: Claude Desktop's Chrome extension. The
   terminal CLI cannot see the canvas or drive the running WASM. The
   freeze was confirmed by installing a parent-window heartbeat +
   dispatching a real user keypress while watching for the CDP
   "renderer unresponsive" timeout.

**Affected:** `basic-wasm-raylib` target only. `basic-gfx` native,
`basic-wasm` terminal, and `basic-wasm-canvas` PETSCII builds do not
link jar_mod and were never affected.

**What actually fixed it — read this before touching the patches:**

Initial diagnosis blamed `jar_mod_max_samples`'s `nbsample=1` per-call
inner loop (first patch: `patches/jar_mod_max_samples.patch`, decoded
in 4096-sample chunks). That patch landed and verifiably made it into
the compiled wasm (`-16384` stack alloc for `buff[4096*2]` visible in
raudio.o) — but **the browser still froze**. The 4000× reduction in
outer iterations wasn't enough: `jar_mod_fillbuffer`'s per-sample inner
loop still runs ~11 M iterations per song (48 kHz × 4 min × 2 channels
× per-sample worknote/mixing), which is many seconds of main-thread
compute under asyncify.

Second attempt added `ASYNCIFY_REMOVE=@scripts/asyncify-remove.txt` to
the Makefile to exclude jar_mod / miniaudio / decoder leaf functions
from asyncify instrumentation. Emscripten reported that most of those
symbols weren't in the asyncify set to begin with (they don't
transitively reach `emscripten_sleep`), so that change did nothing for
the hang either. It did shrink the wasm by ~40 KB; it's left in for
now as harmless hygiene.

What finally worked: **skip `jar_mod_max_samples` entirely on
Emscripten** and hard-code `music.frameCount = 0xFFFFFFFFu` for MOD
(`patches/raudio_mod_skip_max_samples.patch`). Looping MOD playback
doesn't need a real frame count — raylib's `UpdateMusicStream` just
modulos `framesProcessed` by `frameCount`, and jar_mod's internal
`loopcount` handles song-wrap. With `frameCount = UINT_MAX` the modulo
never wraps, the stream never signals end, and the track plays forever
(or until `STOPMUSIC`). For non-looping MOD the playback runs out the
final pattern into silence rather than stopping precisely — acceptable
given the alternative (browser freeze).

**Diagnostic technique worth remembering.** Console logs were useless
once the renderer froze — CDP couldn't read them. Solution: emit
traces via `EM_ASM({ localStorage.setItem(...); })` from C, then open a
separate same-origin tab **after** the freeze and read `localStorage`.
Survives the hang because writes are committed synchronously per call.
Use it whenever you need to localise a WASM-side hang that kills the
debug channel.

**Patches that survive this fix:**

- `patches/jar_mod_max_samples.patch` — still useful: the native
  `basic-gfx` and WASM canvas/terminal builds still call
  `jar_mod_max_samples` via the non-Emscripten path. Chunked decoding
  gives them a ~4000× speedup for essentially free.
- `patches/raudio_mod_skip_max_samples.patch` — the actual browser-
  freeze fix. Emscripten-only (`#ifdef __EMSCRIPTEN__`).

**Build system hook (also landed 2026-04-20):**

- `scripts/build-raylib-web.sh` step 2b compares patch mtimes against
  `libraylib.a` and forces a rebuild when any `patches/*.patch` is
  newer. Editing a patch file is enough to trigger a clean raylib
  rebuild on the next build — no explicit `RAYLIB_FORCE=1` needed.
- `scripts/pullmake.sh` now calls `scripts/build-raylib-web.sh`
  unconditionally before `make basic-wasm-raylib` (it's idempotent and
  fast when up to date). Fresh `rgc-basic` clones bootstrap raylib
  automatically; patch edits propagate into the archive on the next
  `./rebuild-run.sh` without manual steps.

First symptom of this gap: running
`RAYLIB_FORCE=1 ./rebuild-run.sh` after landing the jar_mod patch did
**not** rebuild `libraylib.a` — pullmake never invoked
`build-raylib-web.sh`, so the buggy archive was relinked and the
browser freeze persisted. The hook above closes that loop.

### 1.11.0 – 2026-04-19

**Sound MVP: single-voice WAV playback.**

Ships the minimum useful surface from
`docs/rgc-sound-sample-spec.md` in both the native **basic-gfx** and
the experimental **basic-wasm-raylib** targets. Canvas WASM stays
frozen (per its 2026-04-17 policy) and raises a teachable runtime
error if these verbs are used there.

| Verb | Effect |
|------|--------|
| **`LOADSOUND slot, "path.wav"`** | Decode a WAV into slot (0..31). Replaces existing slot contents; stops playback on that slot first. Paths resolve relative to the BASIC file. |
| **`PLAYSOUND slot`** | Non-blocking playback. Starting a new slot stops whichever voice was already audible (single-voice rule). |
| **`STOPSOUND`** | Halt the active voice. |
| **`UNLOADSOUND slot`** | Free a slot (stops playback first if playing). |
| **`SOUNDPLAYING()`** | 1 while audible, 0 when idle. Self-clears at natural end-of-sample so programs don't need `STOPSOUND` after a one-shot. |

```basic
LOADSOUND 0, "blip.wav"
LOADSOUND 1, "boom.wav"
DO
  IF KEYPRESS(ASC("B")) THEN PLAYSOUND 0
  IF KEYPRESS(ASC("X")) THEN PLAYSOUND 1
  SLEEP 1
LOOP
```

Example: `examples/gfx_sound_demo.bas` with bundled
`examples/blip.wav` (880 Hz pluck) and `examples/boom.wav` (low
thump) generated as stand-in SFX.

Mechanics:

- `gfx/gfx_sound.{c,h}` — thin wrapper over raylib `Sound` +
  `PlaySound` / `StopSound` / `IsSoundPlaying` / `UnloadSound`.
  32-slot table, single `g_active_slot`. Raylib's miniaudio backend
  is thread-safe for Play/Stop/IsPlaying, and `LoadSound` does only
  file I/O + alloc, so every entry point runs directly from the
  interpreter thread — no command queue needed.
- `InitAudioDevice()` is called lazily on first `LOADSOUND` /
  `PLAYSOUND`; `CloseAudioDevice()` + `UnloadSound` for every slot
  runs from the Raylib render loop teardown alongside sprite
  shutdown.
- `basic.c` dispatches LOADSOUND / UNLOADSOUND / PLAYSOUND /
  STOPSOUND statements and the `SOUNDPLAYING()` function. Non-
  Raylib builds (`__EMSCRIPTEN__` without `GFX_USE_RAYLIB`, and
  terminal `basic`) stub to clear errors so the parser can still
  skip past unavailable statements in `IF ... THEN ... : ...`.
- Gesture policy: browsers keep `AudioContext` suspended until a
  user gesture. Programs should gate the first `PLAYSOUND` on
  `KEYPRESS` / `ISMOUSEBUTTONPRESSED` (which the demo does).
- Reserved words: `LOADSOUND UNLOADSOUND PLAYSOUND STOPSOUND
  SOUNDPLAYING`.

Still deferred: `PAUSESOUND` / `RESUMESOUND`, `SOUNDVOL`, looping,
second voice / mixing, canvas-WASM sound backend, MP3/OGG formats.

### 1.10.0 – 2026-04-19

**Non-gfx utility batch: filesystem, timing, JSON iteration, FOREACH.**

Five features that were proposed in `to-do.md` and now ship together.
None are gfx; they round out the "scripting in basic" story.

| Feature | Shape |
|---------|-------|
| **`TICKUS()` / `TICKMS()`** | Monotonic high-resolution counters (µs / ms). Native: `clock_gettime(CLOCK_MONOTONIC)`. Browser WASM: `emscripten_get_now()`. Unblocks BASIC-level benchmarking of user helpers before promoting to C. |
| **`CWD$()` / `CHDIR path$`** | Current working directory + change directory. Native `getcwd`/`chdir`; MEMFS on browser WASM via the same POSIX layer. `CHDIR` raises a runtime error on missing paths. |
| **`DIR$(path$ [, delim$])` + `DIR path$ INTO arr$ [, count]`** | Directory listing, both string and array forms. Default delim is newline. Hidden files (leading `.`) excluded. 1-D string-array target; optional count var. |
| **`JSONLEN(j$, path$)` / `JSONKEY$(j$, path$, n)`** | Iterate JSON. `JSONLEN` returns count of entries at a path resolving to an array/object. `JSONKEY$` returns the 0-based Nth key of an object (empty for arrays/scalars). Pairs with the existing `JSON$` for `FOR I = 0 TO JSONLEN(...) - 1` patterns. |
| **`FOREACH var IN arr[()] ... NEXT var`** | Iterate each element of a 1-D array (numeric or string). Reuses the FOR stack via a new `is_each` flag on `struct for_frame`. Empty arrays run zero iterations via `skip_foreach_to_next`. `EXIT` works the same as inside FOR. |

Mechanics:

- Single-arg TICKUS / TICKMS / CWD$ dispatch early in `eval_factor`
  before the standard `eval_expr(p)` call — they take no args.
- DIR$ / JSONLEN / JSONKEY$ handle their own `)` close so they can
  take variable arg counts.
- `statement_dir_into` mirrors `statement_split` (reads array via
  `vars[]`, writes filenames in place, optional count var stored via
  `find_or_create_var`).
- `statement_foreach` assigns first element before pushing the FOR
  frame; `statement_next` branches on `is_each` to load the next
  element or pop.
- Normaliser no longer splits `FOREACH` into `FOR EACH` (one-line
  guard in `normalize_keywords_line`).
- Added to `reserved_words[]`: `TICKUS TICKMS CWD DIR CHDIR JSONLEN JSONKEY FOREACH IN`.

Tests: `tests/foreach_numeric.bas`, `tests/foreach_string.bas`.

### 1.9.9 – 2026-04-19

**Pixel-perfect `ISMOUSEOVERSPRITE`.**

Closes step 3 of `docs/mouse-over-sprite-plan.md`:

```basic
IF ISMOUSEOVERSPRITE(slot, 16) THEN ...    ' alpha > 16 passes
IF ISMOUSEOVERSPRITE(slot, 0) THEN ...     ' any non-zero alpha
IF ISMOUSEOVERSPRITE(slot) THEN ...        ' legacy bbox only
```

Optional trailing `alpha_cutoff` (0..255) flips the hit test into
alpha-aware mode: the engine inverse-scales the mouse coord back into
the sprite's source rect (honouring `SPRITEFRAME` / tile grid /
`SPRITEMODULATE` scale) and only returns 1 when the sampled source
alpha exceeds the cutoff. No arg = bbox behaviour unchanged.

Typical values:
- `0` — purist: ignore fully-transparent pixels only.
- `16` — forgiving: skips PNG edge-softening dust (recommended).
- `128` — only count firmly-opaque pixels; useful for gradient art.

Mechanics:

- `GfxSpriteSlot` in `gfx/gfx_raylib.c` gains `Image src_image` — the
  load path now does `LoadImage` + `LoadTextureFromImage` and keeps
  both so CPU-side pixel data stays live for hit tests. `UNLOAD`
  and shutdown free the image alongside the texture.
- `SPRITECOPY` carries the copied pixels into the destination slot
  via `ImageCopy` so src and dst have independent CPU buffers
  (protects against dangling aliases if src unloads first).
- Canvas WASM / software path (`gfx/gfx_software_sprites.c`) reuses
  the existing `rgba` buffer — no extra memory cost there.
- New C helper `gfx_sprite_hit_pixel(slot, wx, wy, alpha_cutoff)` in
  both back-ends. The BASIC `ISMOUSEOVERSPRITE` dispatcher in
  `basic.c` picks bbox vs pixel-perfect based on arg count. Slots
  without CPU pixels fall back to bbox.

`examples/gfx_sprite_at_demo.bas` now combines `SPRITEAT` with
`ISMOUSEOVERSPRITE(hit, 16)` so transparent PNG corners no longer
grab the wrong sprite.

### 1.9.8 – 2026-04-19

**`SPRITEAT(x, y)` + SCROLL-aware `ISMOUSEOVERSPRITE`.**

Finishes the non-pixel-perfect half of
`docs/mouse-over-sprite-plan.md`:

- **`SPRITEAT(x, y)`** — topmost visible sprite whose last-drawn rect
  contains world-space `(x, y)`, or `-1`. Ties broken by `Z`
  (passed to `DRAWSPRITE`) then slot index. Lets "click to select
  from a pile" drop out of one call.
- **`ISMOUSEOVERSPRITE` now respects `SCROLL`.** Sprite positions
  are stored in world space; mouse coordinates come back in screen
  space. The engine transforms by `scroll_x/y` before the rect
  test so hits line up with what the user sees. Same convention
  `SPRITECOLLIDE` uses internally.
- **Z cached in the per-slot draw-pos table.** New `z` field on the
  interpreter-thread hit-test cache in both `gfx/gfx_raylib.c` and
  `gfx/gfx_software_sprites.c` (canvas / WASM parity).

New C helpers: `gfx_sprite_hit_rect(slot, wx, wy)` and
`gfx_sprite_at(wx, wy)`. Existing `gfx_sprite_is_mouse_over(slot)`
kept as a thin wrapper (raw-mouse, SCROLL-unaware) for C-side
callers; BASIC-level `ISMOUSEOVERSPRITE` uses the world-space path.

Example: `examples/gfx_sprite_at_demo.bas` — three sprites stacked
with explicit Z, click-to-pick-topmost with drag-and-drop that bumps
the grabbed slot to the front of the stack on pick-up.

Pixel-perfect alpha sampling (step 3 of the plan) still outstanding
— needs a CPU-side RGBA buffer kept alongside the GPU texture, which
is larger surgery; deferred to a follow-up tick.

### 1.9.7 – 2026-04-19

**`CLS x, y TO x2, y2` partial clear + `DRAWTEXT` integer scale.**

Two bite-sized ergonomics wins that compose cleanly with 1.9.6's
multi-plane buffers:

- `CLS x, y TO x2, y2` — clear only the specified pixel rectangle in
  the current draw plane (erases bits, matches `FILLRECT` with
  `COLOR 0`). Bare `CLS` still does a full screen clear. Especially
  handy inside `DOUBLEBUFFER`/`SCREEN BUFFER` loops that only need
  to wipe a HUD band each frame.
- `DRAWTEXT x, y, text$, scale` — optional trailing integer `scale`
  (clamped to 1..8) pixel-doubles each source glyph pixel into a
  `scale × scale` block, giving 16×16 / 24×24 / ... text against the
  existing 8×8 chargen. No Font system required. Per-call fg/bg
  colour still wait on the Font work (`docs/bitmap-text-plan.md`).

Example: `examples/gfx_drawtext_scale_demo.bas` — four title rows at
scales 1..4 plus a bottom HUD band redrawn via `CLS rect` each frame.

Mechanics:

- `statement_cls` in `basic.c` now parses an optional `x,y TO x2,y2`
  and delegates to `gfx_bitmap_line` (per-row, pixel-clear) when
  present; the cell-list clear only runs on the full-screen path.
- `gfx_video_bitmap_stamp_glyph_px_scaled` in `gfx/gfx_video.c` —
  new helper that expands each glyph bit to a scale×scale block via
  `gfx_bitmap_set_pixel`. scale ≤ 1 falls through to the existing
  fast path; scale > 8 clamps. Unit tests in `tests/gfx_video_test.c`.
- `statement_drawtext` accepts and clamps the scale arg; positions
  each glyph at `x + i * 8 * scale` so the caller's coordinate space
  is pixel-accurate at every scale.

### 1.9.6 – 2026-04-19

**Multi-plane screen buffers (`SCREEN BUFFER / DRAW / SHOW / FREE / SWAP / COPY`).**

Promoted the 1.9.5 double-buffer from a hardcoded two-plane pair into
a general buffer table. Up to eight bitmap planes are addressable by
index (slots 0..7): slot 0 is the live `bitmap[]`, slot 1 is the
existing `bitmap_show[]` reserved for DOUBLEBUFFER, and slots 2..7 are
caller-allocated via `SCREEN BUFFER n`. BASIC writes target the
current draw slot; the renderer samples the current show slot. Typical
flipbook / dual-playfield pattern:

```basic
SCREEN BUFFER 2                ' alloc slot 2
SCREEN BUFFER 3                ' alloc slot 3
SCREEN DRAW 2 : CLS : FILLRECT 40,40 TO 280,160   ' scene A
SCREEN DRAW 3 : CLS : FILLCIRCLE 160,100,60       ' scene B
SCREEN DRAW 0
SCREEN SHOW 2                  ' show scene A - costs nothing per frame
IF KEYPRESS(ASC(" ")) THEN SCREEN SHOW 3
```

Statements:

| Form | Effect |
|------|--------|
| `SCREEN BUFFER n` | Allocate slot `n` (2..7) as an offscreen bitmap plane. |
| `SCREEN DRAW n` | Retarget all bitmap writes (`PSET`/`LINE`/`CLS`/`DRAWTEXT`/...) to slot `n`. |
| `SCREEN SHOW n` | Renderer samples slot `n` on the next composite. |
| `SCREEN FREE n` | Release slot `n` (refused if currently draw or show). |
| `SCREEN SWAP a, b` | Atomic `draw = a, show = b`. |
| `SCREEN COPY src, dst` | Blit one plane into another. |

`DOUBLEBUFFER ON` is now shorthand for `SCREEN DRAW 0 : SCREEN SHOW 1
+ auto-flip on VSYNC`; `DOUBLEBUFFER OFF` folds both indices back to
slot 0. Existing programs are unaffected. See
`examples/gfx_screen_buffer_demo.bas` for a pre-rendered flipbook.

Mechanics:

- `GfxVideoState` gains `screen_buffers[GFX_MAX_SCREEN_BUFFERS]`,
  ownership flags, and `screen_draw` / `screen_show` indices.
- Every `gfx_video.c` write site (PSET, line, clear, glyph stamp,
  scroll, POKE to bitmap region) now routes through
  `gfx_video_draw_plane(s)`; `gfx_bitmap_get_show_pixel` reads
  through `gfx_video_show_plane(s)`.
- `gfx_video_bitmap_flip` memcpys draw → show when `double_buffer`
  is on and the two slots differ (no-op otherwise).
- New helpers on the C side: `gfx_video_screen_buffer_alloc/free`,
  `gfx_video_screen_set_draw/show`, `gfx_video_screen_swap`,
  `gfx_video_screen_copy`. Unit tests in `tests/gfx_video_test.c`.

### 1.9.5 – 2026-04-19

**Bitmap-plane double-buffering (`DOUBLEBUFFER ON | OFF`).**

The bitmap plane now has a committed back-buffer. With `DOUBLEBUFFER
ON`, BASIC keeps drawing to `bitmap[]` but the renderer displays
`bitmap_show[]`; `VSYNC` `memcpy`s build → show atomically. Combined
with the always-double-buffered sprite cell list, a canonical per-
frame loop

```basic
DOUBLEBUFFER ON
DO
  CLS
  FILLCIRCLE BX, BY, BR
  DRAWTEXT 12, 182, "BOUNCES " + STR$(BOUNCES)
  SPRITE STAMP 0, PX, PY, 0, 10
  VSYNC
LOOP
```

never shows a half-drawn frame — no more partial-erase idiom required
for simple scenes. See `examples/gfx_doublebuffer_demo.bas` (SPACE
toggles the mode in-flight so you can see the flicker disappear).

Mechanics:

- New `bitmap_show[GFX_BITMAP_BYTES]` + `double_buffer` flag on
  `GfxVideoState`.
- Two new `gfx/gfx_video.c` helpers: `gfx_bitmap_get_show_pixel`
  (renderer-side reader) and `gfx_video_bitmap_flip` (build → show
  memcpy; no-op when disabled).
- Renderers in `gfx_raylib.c` (desktop + WASM-raylib) and
  `gfx_canvas.c` (canvas WASM) read via the new show-pixel helper.
- `VSYNC` now calls both `gfx_cells_flip` and `gfx_video_bitmap_flip`
  so the two planes commit as one unit.
- Default is **OFF** so CBM-era "draw-as-you-go" programs keep
  working unchanged. Enabling eagerly promotes the current bitmap
  into `bitmap_show` so the first frame isn't blank.

Still queued (in `to-do.md`): user-selectable **screen buffers** —
multiple bitmap planes selectable for draw-target vs display (AMOS
dual-playfield / flipbook / triple-buffer use cases).

### 1.9.4 – 2026-04-19

**Compound assignment + increment / decrement.**

Added C-style shortcuts at the statement level (sugar over the
existing implicit-LET path):

| Form | Equivalent |
|------|------------|
| `A++` | `A = A + 1` |
| `A--` | `A = A - 1` |
| `A += expr` | `A = A + expr` |
| `A -= expr` | `A = A - expr` |
| `A *= expr` | `A = A * expr` |
| `A /= expr` | `A = A / expr` |
| `S$ += "x"` | `S$ = S$ + "x"` (string concat) |

Statement-only, not expression: `A++B` still means `A + (+B)` as today.
String variables accept only `+=`; `-= *= /=` raise on strings. Division
by zero on `/=` raises the same error as plain `/`. No new keywords; no
tokenizer / normaliser changes. Test: `tests/compound_assign.bas`.

Compat: zero regression risk — all four forms are new syntax that was
previously rejected by the parser.

### 1.9.3 – 2026-04-19

**`FILEEXISTS` + `DOWNLOAD` + WASM-raylib IMAGE GRAB fix.**

- **WASM-raylib deadlock fix.** `IMAGE GRAB` in the browser (raylib
  backend, the default) hung the tab because it tried to `pthread_cond_wait`
  for the render thread to service the grab — but browser WASM is
  single-threaded (Asyncify), so nothing could ever signal the CV.
  `gfx_grab_visible_rgba` now takes an `#ifdef __EMSCRIPTEN__` inline
  path that runs `LoadImageFromTexture(g_wasm_target)` from the
  interpreter directly — the most recent `VSYNC` already composited
  the target, so its pixels are current. The readback helper is shared
  with the desktop render-thread service.

- **`FILEEXISTS(path$)` intrinsic.** Returns `1` if `path$` opens for
  reading, `0` otherwise. Works against MEMFS in browser WASM and the
  host filesystem natively. Pairs cleanly with `IMAGE SAVE` so programs
  can verify the write landed before telling the user / triggering a
  download:

  ```basic
  IMAGE SAVE 1, P$
  IF FILEEXISTS(P$) THEN PRINT "SAVED: "; P$ : DOWNLOAD P$
  ```

- **`DOWNLOAD path$` statement.** Browser WASM reads the file from
  MEMFS, wraps the bytes in a `Blob` with a guessed MIME type (png /
  bmp / jpg / gif / wav / txt / bas → `image/png`, etc.), creates an
  object URL, and fires a synthetic click on an `<a download>` anchor —
  the user gets a real file on disk. Kept as a separate statement
  (not folded into `IMAGE SAVE`) so per-frame recorders can write 300
  frames to MEMFS without spamming 300 download prompts. On native
  builds it's a no-op that prints a one-shot hint on stderr.

- **`examples/gfx_screenshot_demo.bas` updated** to verify with
  `FILEEXISTS` after `IMAGE SAVE` and call `DOWNLOAD` on success.
  Prints `SAVED: screenshot_0001.png` (or `SAVE FAILED:` on error) as
  on-screen confirmation.

### 1.9.2 – 2026-04-19

**IMAGE GRAB + IMAGE SAVE: full-colour PNG screenshots / video frames.**

- **`IMAGE GRAB slot, sx, sy, sw, sh` now captures the composited
  framebuffer as RGBA** — bitmap plane + text plane + sprites +
  tilemap cells, full 16-colour palette with alpha. Previously the
  grab was a 1bpp copy of the bitmap plane, which dropped colour and
  sprites entirely.
  - **Desktop basic-gfx:** interpreter posts a grab request under a
    new mutex/cond var (`g_grab_mtx` / `g_grab_cv` in `gfx_raylib.c`);
    the render thread, right after `gfx_sprite_composite_range`, reads
    back the RenderTexture via `LoadImageFromTexture`, y-flips to match
    top-left coords, and memcpys the sub-rect into the slot's new RGBA
    buffer. Worst-case block ≈ one display frame (~16 ms).
  - **Canvas WASM:** single-threaded, so the grab composites inline via
    `gfx_canvas_render_full_frame` (already used by the normal renderer)
    and crops into the slot. No mutex needed.
  - **WASM-raylib build:** not yet wired — falls through to the legacy
    1bpp copy. Planned alongside that backend becoming the default web
    renderer.

- **`IMAGE SAVE slot, "path"` auto-routes on extension.** `.png` writes
  32-bit RGBA; anything else keeps the existing 24-bit BMP writer.
  The PNG path is extension-insensitive (`.PNG` / `.Png` / `.png` all
  work) and uses a file-scope-static `stb_image_write` so linking
  against `libraylib.a` (which also pulls `stbiw_*` symbols) stays
  collision-free.
  - **RGBA grab:** PNG writes the buffer directly — composited frame,
    alpha preserved.
  - **Slot 0 without a grab:** falls back to the current-palette
    resolve (on-pixel = `bitmap_fg` entry in the palette, off-pixel =
    `bg_color`, alpha = 255).
  - **Slots 1..31 that are still 1bpp:** written as a transparent-off
    mask (on = opaque white, off = `rgba(0,0,0,0)`).
  - **BMP on an RGBA slot:** premultiplies alpha against black (BMP has
    no alpha channel), keeping existing behaviour for the mono path.

- **Video / animated-GIF pipeline.** Grab one frame per tick, save as
  sequenced PNGs, feed to ffmpeg. See the new
  `examples/gfx_screenshot_demo.bas` for a single-key screenshot capture
  plus a commented-out per-frame recorder block.

- **Slot model:** `GfxImageSlot` gained an optional `rgba` buffer
  alongside the existing 1bpp `pixels` buffer. `gfx_image_new_rgba`
  allocates (used by the grab path); `gfx_image_free` releases both.
  `gfx_image_get_visible_state()` now exposes the cached video-state
  pointer so backends can reach it during a grab without re-routing the
  handle through every call site.

- **Renames / new API surface:** `gfx_grab_visible_rgba`,
  `gfx_image_save_png`, `gfx_image_save` (extension dispatcher),
  `gfx_image_new_rgba`, `gfx_image_rgba_buffer`,
  `gfx_image_get_visible_state`. All declared in `basic_api.h`.

- **to-do.md:** IMAGE GRAB / IMAGE SAVE entries moved from "planned"
  to shipped; new note on bitmap-plane flicker (VSYNC covers the cell
  list only — partial-erase idiom already in `gfx_hud_demo.bas` and
  `gfx_showcase.bas`, newly applied to `gfx_ball_demo.bas`).

### 1.9.1 – 2026-04-18

**Post-Graphics-1.0 polish pass.** Small features + a pile of fixes
from porting real user programs (C64-style `cards.bas`, `bounce.bas`,
`options.bas`, `fileio_basics.bas`, `tutorial_functions.bas`,
`gfx_menu_demo.bas`) to the WASM raylib runtime. No breaking changes
from 1.9.0.

- **Statement: `PAPER n` — per-cell background colour (0–15).** Unlike
  `BACKGROUND` (global bg register), `PAPER` only changes the value
  stamped into each cell's `bgcolor[]` by subsequent `PRINT`s. Lets
  BASIC draw a highlighted menu row, a card border, or a status-bar
  stripe without repainting the rest of the screen. New `uint8_t
  bgcolor[GFX_COLOR_SIZE]` field in `GfxVideoState`; `gfx_put_byte`
  stamps `bgcolor[idx] = gfx_bg`; `CLS` and scroll fill / slide the bg
  plane alongside the fg plane; the raylib text renderer reads per-cell
  bg from `s->bgcolor[idx]`. Canvas backend unchanged (frozen
  2026-04-17). New example: `examples/gfx_menu_demo.bas`.

- **Named key-code constants: `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`,
  `KEY_RIGHT`, `KEY_SPACE`, `KEY_ENTER`, `KEY_ESC`, `KEY_TAB`, `KEY_BACK`.**
  Resolve at identifier-parse time in `eval_factor` (same path as `TI` /
  `TI$`) to the PETSCII CHR$ control codes: UP=145, DOWN=17, LEFT=157,
  RIGHT=29, SPACE=32, ENTER=13, ESC=27, TAB=9, BACK=8. So `IF
  KEYDOWN(KEY_UP) THEN …` replaces the magic number `145`.

- **Default charset flipped to lower/uppercase ROM.** `petscii_lowercase_cli`
  defaults to `1` and `GfxVideoState.charset_lowercase` initialises `1`
  so mixed-case ASCII source (`PRINT "Hello"`) renders as mixed-case
  glyphs. Pure-uppercase demos still look uppercase (A–Z at SC 65–90 in
  lower ROM). `#OPTION PETSCII` auto-switches back to upper ROM so
  PETSCII graphic bytes (208 → SC 80 corner, etc.) render as shapes,
  but only if the user hasn't already pinned a charset explicitly via
  `#OPTION CHARSET`.

- **`#OPTION CHARSET` + `#OPTION PETSCII` interaction fix.** New
  `charset_explicit_opt` flag (reset per-load). Setting `#OPTION
  CHARSET PET-LOWER` / `PET-UPPER` / `C64-UPPER` / `C64-LOWER` raises
  the flag; `#OPTION PETSCII` checks it before clobbering the charset.
  Previously `#OPTION CHARSET PET-LOWER : #OPTION PETSCII` (as in
  `options.bas`) ended up on upper ROM because `PETSCII` was parsed
  last.

- **`FILLRECT` in bitmap mode: `COLOR 0` now clears bits; `COLOR n>0`
  still sets bits.** Bitmap is 1bpp, so `COLOR` only picks set-vs-clear
  here; the global `bitmap_fg` register still drives how set bits
  render. Lets `gfx_hud_demo` / `gfx_showcase` erase just the spinner /
  star area without a whole-screen `CLS` flicker.

- **ASCII `[ \ ] ^ _` pick up the real C64 glyphs in both ROMs.**
  `gfx_ascii_to_screencode` (upper) and
  `gfx_ascii_to_screencode_lowcharset` (lower) now map 91–94 → SC 27–30
  (`[` `£` `]` `↑`) and 95 → SC 100 (real bottom-bar underscore).
  Previously they returned the raw ASCII byte, which indexed into
  whatever lived at SC 91–95 in the ROM (cross, pipe, diagonal).

- **Unicode box-drawing (`┌ ─ ┐ │ └ ┘ ├ ┤ ┬ ┴ ┼`) renders in default
  mode.** `gfx_put_byte`'s `else sc = b` fallback for `b >= 128` now
  routes through `petscii_to_screencode` instead of using the raw byte.
  `print_value` decodes UTF-8 via `unicode_to_petscii` and emits the
  PETSCII byte; without the conversion the byte indexed the reverse-
  video region.

- **`CHR$(208)` and other high PETSCII bytes in concatenated strings.**
  `print_value`'s UTF-8 decoder previously ate any byte in `0xC2..0xF4`
  as a possible 2-byte UTF-8 start and fell back to `gfx_put_byte(' ')`
  when the "codepoint" wasn't in `unicode_to_petscii` — so
  `CHR$(208) = 0xD0` silently turned into a space. The decoder now also
  requires a valid continuation byte (`0x80..0xBF`) before committing;
  raw PETSCII bytes pass straight through. `bounce.bas`'s paddle
  (`" {DOWN}{LEFT}"+CHR$(208)+…`) renders correctly.

- **WASM raylib: forced refresh at end of run.** New file-scope
  `g_wasm_force_next_refresh` flag bypasses the 60 Hz rate-limit in
  `wasm_gfx_refresh_js` exactly once per run. Short programs whose last
  `PRINT` stamped the screen within 16 ms of a prior budget-tick
  render (e.g. `fileio_basics.bas`) no longer leave the final text
  invisible.

- **WASM raylib: `ticks60` advances per render tick.** Without this the
  jiffy counter stayed at `0` and `ANIMFRAME(first, last, per)` always
  returned `first` — `gfx_anim_demo.bas` looked static. Matches the
  native raylib loop which calls `gfx_video_advance_ticks60(&vs, 1)`
  each frame.

- **WASM raylib: window + render texture resize on `#OPTION COLUMNS 80`.**
  `wasm_raylib_init_once` used to build the 40-col-sized GL target
  before `basic_load` parsed the file's options. New
  `wasm_resize_if_cols_changed` unloads the old render texture, calls
  `SetWindowSize`, re-creates at `want_cols * CELL_W`, and restores the
  filter. Called after `basic_load`.

- **WASM raylib iframe: stderr parsed for `Error on line N: …` and
  forwarded via `postMessage` as `rgc-basic-runtime-error`.** The
  canvas iframe already did this; the raylib iframe's `printErr` only
  logged to `console.warn`, so the IDE overlay never saw runtime errors
  on that renderer. Now both iframes emit the same event shape.

- **8bitworkshop: local cache-bust script.**
  `scripts/bump-rgc-basic-cb.sh` writes a fresh `YYYYMMDD-HHMMSS` token
  to `rgc-basic/asset-cb.txt` and `src/platform/rgc-basic-asset-cb.gen.ts`
  (same logic as `deploy.sh`). Run after each local WASM rebuild.

- **IDE asset preload: strip REM comment lines + drop `OPEN` from the
  regex.** Previously `5 REM OPEN uses: logical, device, secondary,
  "filename"` in `fileio_basics.bas` caused the IDE to fetch
  `presets/rgc-basic/filename` (404 + CORS). The regex now runs over a
  REM-stripped copy of the source, and asset verbs are limited to
  `LOADSPRITE` / `SPRITE LOAD` / `IMAGE LOAD` / `LOADFONT`. Applied to
  all four parser sites.

- **Example: `examples/gfx_menu_demo.bas` — per-row + per-char
  PAPER/COLOR menu.** Five menu items with the selected row highlighted
  via `PAPER 2` (red bg, full-width), a box-drawn frame (`┌─┐ │ └─┘`)
  with `PAPER 0` (black bg per-char), a rainbow title (one PRINT
  fragment per letter, different `COLOR` each), and W/S or cursor up /
  down to cycle the selection. Demonstrates both modes of colour
  attribute control in one screen.

### 1.9.0 – 2026-04-18

**Graphics 1.0 milestone.** The entries below collectively round
RGC-BASIC's bitmap / sprite / tile / blitter / input surface out to
classic-BASIC feature parity: AMOS-class 2-D primitives, a double-
buffered per-frame cell pipeline, a complete blitter-surface I/O
round-trip (load PNG/BMP/JPG, grab visible region, save to BMP), and
named intrinsics for every host-input axis the interpreter polls.
See `examples/gfx_showcase.bas` for a one-screen tour of every
bitmap primitive.

- **Statement: `ANTIALIAS ON | OFF` — global texture-filter toggle (raylib renderer).** Flips every loaded sprite texture and the render target between `TEXTURE_FILTER_POINT` (nearest-neighbour, hard-pixel retro look — default) and `TEXTURE_FILTER_BILINEAR` (smoothed). Also accepts `ANTIALIAS 0` / `ANTIALIAS 1`. Applies immediately to already-loaded slots (walks `g_sprite_slots[]` under the sprite mutex and re-calls `SetTextureFilter`) and governs future `SPRITE LOAD`. Canvas/software backend is always nearest pixels and silently ignores the call. The current (not-yet-shipped) `DRAWTEXT` + future `LOADFONT` paths will inherit the same filter when they composite through the sprite/texture stage.

- **Example: `examples/gfx_showcase.bas` — every bitmap primitive in one frame.** Tours `RECT` / `CIRCLE` / `ELLIPSE` / `TRIANGLE` / `LINE` / `PSET` outlines, matching `FILLRECT` / `FILLCIRCLE` / `FILLELLIPSE` / `FILLTRIANGLE` solid forms, a `POLYGON` from a `DIM`-ed vertex array, a `FLOODFILL`-ed panel, pixel-placed `DRAWTEXT` labels, and an animated spinner driven by per-frame `CLS` + `VSYNC`. Intended as the screenshot / capture source for the "Graphics 1.0" announcement.

- **Function: `ANIMFRAME(first, last, jiffies_per_frame)` — time-based sprite frame selector.** Cycles through `first..last` inclusive, advancing every `jiffies_per_frame` ticks (60 jiffies = 1 second, same unit as `SLEEP`). Typical use: `SPRITE FRAME 0, ANIMFRAME(1, 4, 6)` to cycle four frames at 10 FPS without maintaining frame state in BASIC. Draws the jiffy value from `gfx_vs->ticks60` in basic-gfx / canvas WASM, or wall-clock seconds × 60 in the terminal build. Invalid spans (`last < first`) fall back to `first`; `jiffies_per_frame <= 0` treats as 1.

- **`SPRITE STAMP` gains a rotation arg.** Optional 6th parameter: `SPRITE STAMP slot, x, y, frame, z, rot_deg`. Raylib backend rotates via `DrawTexturePro` around the sprite's centre (pivot offset handled internally so the `(x, y)` argument still means "top-left of the un-rotated quad"). Canvas/WASM software backend accepts the arg for API parity but ignores it — 1bpp per-pixel rotation isn't fast enough for the software blitter; programs that must rotate under WASM should pre-rotate the asset or use multiple frames. `gfx_sprite_stamp()` signature in `basic_api.h` extended with `float rot_deg`. New example: `examples/gfx_rotate_demo.bas` — 16 ships fanned out in a ring, each pointing outward, whole ring spinning.

- **Statement: `VSYNC` — frame-commit + display-frame wait (double-buffered cell list).** Adds the vertical-blank equivalent BASIC previously lacked. The `TILEMAP DRAW` / `SPRITE STAMP` cell list is now genuinely double-buffered: BASIC appends to a BUILD buffer, the renderer reads a SHOW buffer, and `VSYNC` atomically flips BUILD → SHOW. Without this the compositor could snapshot the list mid-append and the user saw flicker — raylib's GL framebuffer is already double-buffered at the pixel level, but the intermediate cell list was a single shared array. `VSYNC` also waits one ~16 ms display frame (via `emscripten_sleep(16)` on WASM or `do_sleep_ticks(1.0)` on native, same timer-aware path `SLEEP` goes through) so `ON TIMER` handlers keep firing. Idiomatic loop is now `CLS : TILEMAP DRAW … : SPRITE STAMP … : DRAWSPRITE … : VSYNC : GOTO loop`. `CLS` clears the BUILD buffer alongside the bitmap + text planes, so programs that rebuild their scene each tick get a clean slate; the SHOW buffer only changes on `VSYNC`, so the renderer draws the last committed frame while BASIC is mid-build. Reserved word: `VSYNC`. Updated demos: `examples/gfx_stamp_demo.bas`, `examples/gfx_world_demo.bas`, `examples/gfx_tilemap_demo.bas`.

- **Statement: `IMAGE SAVE slot, "path.bmp"` — export a blitter surface as 24-bit BMP.** Completes a minimal screenshot / off-screen-export workflow on top of the Phase 1 blitter. Pen=1 pixels encode as white (0xFFFFFF), pen=0 as black (0x000000). Header is the standard 54-byte BMP preamble; pixel rows are bottom-up with the usual 4-byte padding. BMP chosen over PNG because it needs no extra dependency — pulling in stb_image_write (or zlib) for a Phase-1 export path isn't worth it; programs that want PNG can convert externally. Usage: `IMAGE COPY 0, 0, 0, 320, 200 TO 1, 0, 0 : IMAGE SAVE 1, "shot.bmp"` for a screenshot of the current visible bitmap. Declared in `basic_api.h`; defined at the end of `gfx/gfx_images.c` (below `img_get_pixel`).

- **Statements: `IMAGE LOAD slot, "path"` + `IMAGE GRAB slot, sx, sy, sw, sh` — finish the blitter I/O loop.** `IMAGE LOAD` uses `stb_image` to decode PNG/BMP/JPG/TGA/GIF and thresholds luminance (Rec.601 weights) to 1bpp; alpha=0 always maps off, luminance ≥128 → pen. `IMAGE GRAB` is a one-statement shortcut for `IMAGE NEW slot, sw, sh : IMAGE COPY 0, sx, sy, sw, sh TO slot, 0, 0` — snapshot a rectangle of the live visible bitmap into a new off-screen slot. Pairs with the existing `IMAGE SAVE` (24-bit BMP export) for round-trip editor / screenshot workflows. Refactor: `STB_IMAGE_IMPLEMENTATION` moved from `gfx_software_sprites.c` into `gfx_images.c` so every GFX target links one copy (the raylib build previously had no stb impl linked, which was fine until the loader needed it).

- **Statements: `POLYGON n, vx(), vy()` / `FILLPOLYGON n, vx(), vy()` — N-sided polygon primitives.** Takes a vertex count plus two numeric arrays of x and y coordinates. `POLYGON` draws the outline via `n` closed `LINE` segments; `FILLPOLYGON` triangulates from vertex 0 (fan) and scanline-fills each triangle. Correct for convex polygons; concave shapes get fan-overlap artefacts — recommend stitching multiple `FILLTRIANGLE` calls for those. Up to 256 vertices per call. Parse pattern mirrors `TILEMAP DRAW` (identifier + optional empty parens accepted for the arrays). Reserved words: `POLYGON`, `FILLPOLYGON`.

- **Statement: `FLOODFILL x, y` — paint-bucket seed fill on the bitmap.** Walks the 4-connected region of pixels sharing the seed value and flips them to pen. Scanline implementation with an explicit LIFO stack (sized for one entry per bitmap pixel, 320×200), so it won't blow the C stack on large regions. 1bpp semantics: seed pixel = pen → no-op; seed pixel = off → connected-off region becomes on. Reserved word: `FLOODFILL`.

- **Statements: `TRIANGLE x1,y1, x2,y2, x3,y3` / `FILLTRIANGLE x1,y1, x2,y2, x3,y3` — bitmap triangle primitives.** `TRIANGLE` outlines with three `LINE` segments; `FILLTRIANGLE` sorts the vertices by y and runs the classic scanline fill (one-edge-vs-two-edges split at the middle vertex, hline per scanline). Handles degenerate cases (flat triangle → single hline; zero-height edges → vertex fallback). Six-numeric-arg syntax matches typical BASIC graphics conventions. Reserved words: `TRIANGLE`, `FILLTRIANGLE`.

- **Statements: `ELLIPSE x, y, rx, ry` / `FILLELLIPSE x, y, rx, ry` — bitmap ellipse primitives.** Axis-aligned midpoint-ellipse rasteriser alongside `CIRCLE` / `FILLCIRCLE`. `ELLIPSE` plots the 4-way-symmetric contour; `FILLELLIPSE` emits horizontal spans between mirrored points per step. `rx`/`ry` = 0 draws a single pixel; negatives are no-ops. Reserved words: `ELLIPSE`, `FILLELLIPSE`.

- **Statements: `CIRCLE x, y, r` / `FILLCIRCLE x, y, r` — bitmap circle primitives.** Midpoint-circle (Bresenham) rasteriser. `CIRCLE` strokes the 8-way-symmetric outline in the current pen; `FILLCIRCLE` emits horizontal spans between the mirrored points for a solid disk. `r = 0` draws a single pixel; `r < 0` is a no-op. Pairs with `RECT` / `FILLRECT` so BASIC programs can do all the common HUD / sprite-placeholder / particle shapes without a `PSET` loop. Reserved words: `CIRCLE`, `FILLCIRCLE`.

- **Statements: `RECT x1,y1 TO x2,y2` / `FILLRECT x1,y1 TO x2,y2` — bitmap rectangle primitives.** Two new bitmap-mode draw verbs on top of `PSET` and `LINE`: `RECT` strokes the four edges of a rectangle in the current pen; `FILLRECT` paints the solid interior. Both use the `x,y TO x,y` syntax that already exists on `LINE` so the surface stays consistent; both normalise corner order internally so either diagonal parses. Lets BASIC programs draw HUD frames, status bars, backgrounds, or score panels without a `FOR dy/FOR dx` loop. Minimal shared `parse_rect_coords` helper keeps the two handlers small. Reserved words: `RECT`, `FILLRECT`. Example: `examples/gfx_hud_demo.bas`.

- **Statement: `DRAWTEXT x, y, text$` — pixel-space text on the bitmap.** Minimal v1 of `docs/bitmap-text-plan.md` §Part 2. Stamps a string at an arbitrary pixel `(x, y)` using the active character-set glyphs, so HUDs / scores / annotations in `SCREEN 1` sit wherever the programmer wants rather than snapping to the 8×8 text-cell grid of `PRINT` / `TEXTAT`. Bytes of `text$` go through `petscii_to_screencode` so `DRAWTEXT 50, 20, "HP 99"` reads as expected. Transparent background (bit-wise OR), current pen, 8×8 glyphs, no scale, no Font slot — enough for the common HUD use case. The remaining spec pieces (`fg`, `bg`, `font_slot`, `scale`) stay deferred until the Font system lands. New helper `gfx_video_bitmap_stamp_glyph_px()` handles mid-byte `x` via a two-byte shift per glyph row (the existing byte-aligned `gfx_video_bitmap_stamp_glyph` can only place at cell granularity). Example: `examples/gfx_hud_demo.bas`.

- **Statement: `SPRITE STAMP slot, x, y [, frame [, z]]` — multi-instance immediate sprite draw.** `DRAWSPRITE` tracks one persistent position per slot — N calls with the same slot collapse to the last position — so rendering multiple instances of one sheet (particles, bullets, enemy swarms, starfields) previously required `SPRITECOPY` into N slots. `SPRITE STAMP` appends a single cell to the same per-frame list `TILEMAP DRAW` writes to, so N stamps of one slot in one frame all render at distinct positions. `frame` is a 1-based tile index into the slot's sheet; `0` or omitted falls back to the slot's current `SPRITE FRAME`, and if the slot holds a single image with no tile grid the draw uses the full sprite rect. `z` sorts against both the tilemap and other stamps so mixed scenes layer correctly. Unified cell list now **appends** on `TILEMAP DRAW` and `SPRITE STAMP` rather than replacing — the compositor drains after each render pass, so per-frame redraws behave unchanged and programs can layer a tilemap + stamps by calling both. On raylib the snapshot is qsorted by z before DrawTexturePro (previously insertion-order), matching the canvas/software backend. Example: `examples/gfx_stamp_demo.bas` — 50 scrolling particles (slot 0 via STAMP) under a WASD-controlled player ship (slot 1 via DRAWSPRITE).

- **Two-word graphics command family — `SPRITE LOAD / DRAW / FRAME / FREE`, `TILE DRAW`, `TILEMAP DRAW`, plus `SHEET` / `SPRITE FRAMES` / `TILE COUNT` accessors.** Naming convention added at the top of `to-do.md`: new graphics commands follow AMOS/STOS-style two-word verb/noun grammar (`VERB NOUN`), grouping related features visually (`SPRITE *`, `TILE *`, `SHEET *`, `IMAGE *`). Existing concat names (`LOADSPRITE`, `DRAWSPRITE`, `SPRITEFRAME`, `UNLOADSPRITE`, `DRAWSPRITETILE`, `DRAWTILEMAP`, `SPRITETILES`) stay as permanent aliases — both spellings tokenise to the same handler, no deprecation, no removal date. Tokeniser rewrites in the `S` and `T` branches use a scratch-pointer peek-ahead so non-matching input (e.g. user variable `SPRITE = 5`) falls through unharmed. Expression-level intrinsics (`SPRITE FRAMES(slot)`, `TILE COUNT(slot)`, `SHEET COLS/ROWS/WIDTH/HEIGHT(slot)`) use a `starts_with_two_words()` detector plus a glue step in `eval_function` that concatenates `SPRITE`+`FRAMES` into `SPRITEFRAMES` before `function_lookup` runs. See `docs/tilemap-sheet-plan.md` and `to-do.md` for the full rule.

- **Statement: `TILEMAP DRAW slot, x0, y0, cols, rows, map [, z]` — batched tile grid stamp.** Replaces the one-interpreter-call-per-cell loop needed for background rendering (on WASM that was ~1 µs of asyncify yield overhead per tile = ~1 ms for a 1000-tile screen). `map` is a BASIC 1-D numeric array of length `cols*rows`; each entry is a 1-based tile index from the sheet, `0` = transparent (skip). Runtime iterates in C and produces one cell list that the compositor draws in bulk — one BASIC statement = one yield regardless of tile count. Supports negative `x0`/`y0` for scrolling the tilemap under a fixed viewport. Implementation is split from the sprite queue: a dedicated `g_tm_cells[]` list (max 4096 cells) replaces per-slot persistent draw state so N cells sharing one sheet slot all render correctly. On raylib (`gfx/gfx_raylib.c`) the tilemap renders before the sprite pass so a player sprite at `z=100` composites on top of a background tilemap at `z=0`. On canvas/WASM (`gfx/gfx_software_sprites.c`) tilemap cells z-sort with sprite draws so layering matches. Concat alias `DRAWTILEMAP` tokenises to the same handler. Example: `examples/gfx_tilemap_demo.bas`.

- **Functions: `SHEET COLS/ROWS/WIDTH/HEIGHT(slot)`, `SPRITE FRAMES(slot)`, `TILE COUNT(slot)` — sheet metadata accessors.** Six intent-named queries over the loaded sheet record; all return 0 when the slot is unloaded or the sheet has no tile grid. `SHEET COLS` / `SHEET ROWS` give the grid shape, `SHEET WIDTH` / `SHEET HEIGHT` give the cell size in pixels; `SPRITE FRAMES` and `TILE COUNT` both return the total cell count (`tiles_x * tiles_y`), named for whichever intent reads cleanly in the caller's code (`SPRITE FRAMES` for animation, `TILE COUNT` for tilemap use). `SPRITETILES(slot)` kept as the legacy concat alias (returns the same value). Terminal build returns the neutral value (0) instead of erroring, so headless scripts can probe without crashing. Example: `examples/gfx_sheet_info_demo.bas`.

- **Statements: `IMAGE NEW slot, w, h` / `IMAGE FREE slot` / `IMAGE COPY src, sx, sy, sw, sh TO dst, dx, dy` — blitter Phase 1.** First shipped piece of `docs/rgc-blitter-surface-spec.md`: off-screen 1bpp bitmap surfaces for scroll/parallax/work-buffer patterns from AMOS/STOS-style BASIC. Slot `0` is bound to the live visible bitmap (320×200, same MSB-first packing as `gfx_bitmap_get/set_pixel`) so `IMAGE COPY` works in both directions without format conversion. Slots `1..31` are caller-allocated via `IMAGE NEW` with any width/height. `IMAGE COPY` clips source and destination rects to each surface's bounds and stages overlapping copies through a scratch row buffer so same-slot rect moves are safe. Scrolling recipe (`examples/gfx_scroll_demo.bas`): allocate an oversized world surface, stamp content in, blit a 320×200 window onto the visible bitmap each frame at a moving offset. Parallax (`examples/gfx_parallax_demo.bas`): one surface per band, independent `IMAGE COPY` offsets. New files `gfx/gfx_images.h` + `gfx/gfx_images.c`; `basic_set_video` now calls `gfx_image_bind_visible` so slot 0 is ready the moment the interpreter attaches. Phase 2 (RGBA surfaces) and Phase 3 (`IMAGE GRAB` / `TOSPRITE`) still pending. Deferred and dropped: `SCREEN OFFSET` / `SCREEN ZONE` / `SCREEN SCROLL` from the earlier tilemap spec — `IMAGE COPY` with a user-managed offset covers both scrolling and parallax without adding viewport state to the renderer (see the "Scrolling — covered by IMAGE COPY" section in `docs/tilemap-sheet-plan.md`).

- **Functions: `KEYDOWN(code)` / `KEYUP(code)` / `KEYPRESS(code)` — host keyboard polling without `PEEK`.** Replaces the `PEEK(56320 + ASC("W"))` idiom for WASD-style movement with a named intrinsic that survives `#OPTION memory` base changes. `KEYDOWN(code)` returns 1 while the key is held (lets A+D or A+W fire simultaneously for diagonal movement); `KEYUP(code)` is the inverse; `KEYPRESS(code)` is a rising-edge latch — 1 exactly once per press, then 0 until the key is released and pressed again (per-key `g_key_press_seen[256]` byte map, cleared whenever the key lifts). `code` is the same scan index as `PEEK(GFX_KEY_BASE + code)` — uppercase ASCII for letters/digits, special codes for arrows etc. (Up=145, Down=17, Left=157, Right=29, Esc=27, Space=32, Enter=13, Tab=9, Backspace=8). Terminal (non-GFX) build returns the neutral value — `KEYUP` = 1, others = 0 — so scripts that poll in a loop run cleanly under `./basic` too. Example: `examples/gfx_world_demo.bas` (WASD + vertical auto-scroll, diagonal movement via `KEYDOWN`). Regression: `tests/keyboard_intrinsics_test.bas`.

- **Parser: single-line `IF cond THEN stmt1 ELSE stmt2` — half-broken, now fully routed.** The condition-true path previously executed the THEN statements and then crashed into `ELSE` at statement level with `"ELSE without IF"`; the false path skipped the rest of the line and never ran the ELSE body. Fix: `statement_if` now scans the rest of the line for a top-level `ELSE` (`find_inline_else` handles string literals and word boundaries, so `"text ELSE text"` and identifiers like `CELSE` don't match), and routes based on the condition. An `inline_if_then_active` counter gets armed on condition-true and consumed by `statement_else`, which short-circuits to end-of-line. The counter is reset at every line transition — including the `GOTO` path where `statement_pos` is re-set from `NULL` — so a `IF … THEN GOTO N` can't leak state onto line `N`'s own ELSE. Block `IF / ELSE / END IF` is unchanged. Nested inline IFs with separate ELSEs per level remain limitation territory; use block form when pairing is ambiguous. Regression: `tests/if_inline_else_test.bas` — 15 cases covering true/false × single/multi-statement × MOD-in-condition × ELSE-inside-string × identifier-suffix-ELSE × block-IF regression × GOTO-leak × FOR-body × both-arms-GOTO.

- **Parser: `IF (expr) MOD n = 0 THEN …` — arithmetic continuation after `(expr)` in conditions.** `eval_simple_condition`'s leading-`(` branch consumed the outer paren as if it always opened the whole relational left-hand side, then expected a relational operator (`<`, `>`, `=`) right after the closing `)`. When the following token was an arithmetic continuation (`MOD`, `+`, `-`, `*`, `/`) — which just means the `(…)` was precedence-grouping the first term of a larger arithmetic expression — the parser took a wrong turn and reported `"Missing THEN"`. Fix: peek the first post-`)` token, and if it's arithmetic, rewind to before the `(` and re-run `eval_expr` over the whole left operand so the full arithmetic tree is parsed before the relational compare. Relational and terminator cases (`<`, `>`, `=`, `:`, `\0`, `THEN`, `AND`, `OR`) keep the original fast path. Regression covered in `tests/if_inline_else_test.bas` case 7.

- **Parser: `TI` / `TI$` jiffy-clock no longer swallows any identifier starting with `TI`.** `eval_factor` used a `len >= 2 && name[0]=='T' && name[1]=='I'` check to mimic CBM BASIC's 2-character-significance rule (where `TIME`, `TICKS`, etc. all resolve to `TI`). RGC-BASIC keeps full-length identifier names, so that abbreviation silently consumed user names like `TILE`, `TILEMAP`, `TIDE`, etc. and returned the jiffy counter instead. Symptom: `PRINT TILE COUNT(0)` printed the tick count, left `COUNT(0);…` for the next statement, and the dispatcher tripped `"Expected '='"` on `COUNT`. Tightened to `len == 2 || (len == 3 && name[2] == '$')` so only exact `TI` / `TI$` match.

- **Statement: `SPRITECOPY src, dst` — clone a sprite slot without re-loading the file.** Copies pixel data and all metadata (tile grid, modulation, frame) from slot `src` into slot `dst` as an independent allocation. Both slots can then be independently positioned with `DRAWSPRITE`, modulated with `SPRITEMODULATE`, and unloaded with `UNLOADSPRITE` without affecting each other. Primary use case: load one PNG once with `LOADSPRITE`, then `SPRITECOPY` into N slots instead of calling `LOADSPRITE` N times (avoids repeated file I/O for identical sprites). Software/WASM backend: `malloc` + `memcpy` of the RGBA pixel buffer. Raylib backend: `LoadImageFromTexture` + `LoadTextureFromImage` for an independent GPU texture. Requires basic-gfx or canvas WASM; prints an error hint in the terminal build. Example: `examples/chicks.bas`.


- **Statement: `TIMER` — cooperative periodic callbacks ("IRQ-light").** `TIMER id, interval_ms, FuncName` registers a zero-argument `FUNCTION`/`END FUNCTION` handler that fires every `interval_ms` milliseconds (minimum 16 ms, max 12 concurrent timers, ids 1–12). Dispatch is cooperative: handlers are called between statements in the main interpreter loop, so no pre-emptive interruption occurs. `TIMER STOP id` disables without removing; `TIMER ON id` re-enables; `TIMER CLEAR id` removes entirely. Re-entrancy is skipped (not queued) — if a handler is still running when its next tick fires, that tick is silently dropped and the due time reset from now. Wall-clock source: `emscripten_get_now()` on WASM, `GetTickCount()` on Windows, `clock_gettime(CLOCK_MONOTONIC)` on POSIX. All timers are reset at the start of each run. Works in terminal, basic-gfx, and WASM builds. Examples: `examples/timer_demo.bas`, `examples/timer_clock.bas`.

- **`HTTP$` now works in Mac/Linux terminal builds via `curl` subprocess.** Previously `HTTP$(url$)` returned `""` outside the browser WASM build. On Unix/Mac it now forks `curl` with `--write-out %{http_code}` and captures the response body into the return string; `HTTPSTATUS()` reflects the real HTTP status. If `curl` is not on `PATH` (exit 127), a clear message is printed: `HTTP$: curl not found — install curl to use HTTP$ in the terminal build`. Windows and other non-POSIX platforms print `HTTP$: not supported on this platform`. WASM path unchanged.


- **Named constants: colour names, `TRUE`, `FALSE`, `PI`.** `BLACK`, `WHITE`, `RED`, `CYAN`, `PURPLE`, `GREEN`, `BLUE`, `YELLOW`, `ORANGE`, `BROWN`, `PINK`, `DARKGRAY`/`DARKGREY`, `MEDGRAY`/`MEDGREY`, `LIGHTGREEN`, `LIGHTBLUE`, `LIGHTGRAY`/`LIGHTGREY` resolve to their C64 palette indices 0–15 in any numeric expression, so `COLOR WHITE`, `BACKGROUND BLUE`, `IF c = RED` all work without magic numbers. `TRUE` = 1, `FALSE` = 0, `PI` = π. All are reserved words. The constants use the `COLOR`/`BACKGROUND` palette-index scheme (0–15), which is separate from the `{WHITE}` PETSCII brace-expansion codes used inside string literals. Regression: `tests/color_constants_test.bas`.

- **Operator: `NOT` — unary logical negation in conditions.** `NOT expr`, `NOT (cond)`, and chained `NOT NOT x` now work in `IF`, `WHILE`, `DO WHILE`, and `LOOP UNTIL` conditions. `NOT FALSE` → true, `NOT TRUE` → false, `NOT 0` → true, `NOT (X=Y)` → true when X≠Y. Regression: `tests/not_test.bas`.

- **Statement: `DO WHILE cond … LOOP` — pre-test loop variant.** Extends the existing `DO … LOOP [UNTIL]` construct with an optional `WHILE cond` clause immediately after `DO`. The condition is evaluated on entry and on every `LOOP` jump-back; if false the body is skipped entirely (zero-iteration loops work correctly). Plain `DO … LOOP`, `DO … LOOP UNTIL cond`, and `EXIT` are completely unchanged. Nested `DO WHILE` loops and mixing with `DO … LOOP UNTIL` in the same program both work. Regression: `tests/do_while_test.bas`.

- **New type: `BUFFER` — large-data companion to strings (step 1 of the rollout in `docs/buffer-type-plan.md`).** BASIC strings are capped at `MAX_STR_LEN` (4096) because every `struct value` carries an inline `char str[MAX_STR_LEN]`; raising the cap grows every local, every array slot, and every on-stack temporary by the same factor — a non-starter on canvas WASM. The visible consequence was that `HTTP$(url)` silently truncated responses at byte 4095, so an 83-entry JSON feed would return a half-parsed blob and subsequent `INSTR` / `JSON$` calls would miss data past the cap. Fix is a new resource type, not a bigger string: a BUFFER is a slot (0..15) that owns a path under `/tmp/` (real /tmp on native, Emscripten MEMFS on canvas WASM where `FORCE_FILESYSTEM=1` is already on). Four statements + two functions, all in the 'B' dispatcher block: `BUFFERNEW slot` allocates the slot and creates a zero-byte backing file; `BUFFERFETCH slot, url$ [, method$ [, body$]]` HTTPs straight into that file (reuses `http_fetch_to_file_impl`, the same path `HTTPFETCH` uses); `BUFFERFREE slot` unlinks the file and releases the slot (idempotent); `BUFFERLEN(slot)` returns the file size via `fseek/ftell`; `BUFFERPATH$(slot)` returns the MEMFS/tmp path so programs feed it to the existing `OPEN`/`INPUT#`/`GET #`/`CLOSE` verbs. Zero changes to `struct value`, `open_files[]`, or any existing file-I/O verb — BUFFER rides on top. `statement_open` gained a small extension: the filename argument now accepts any string expression, not just a quoted literal, so `OPEN 1, 1, 0, BUFFERPATH$(0)` works (plain-quoted literals are unchanged). Program-end cleanup (`rgc_buffer_free_all`) unlinks all in-use buffers next to the existing file-close loop so `/tmp/` doesn't leak on native. Path format `/tmp/rgcbuf_NNNN` uses a monotonic counter so reusing a slot rotates the path and can't collide with a stale file. Regressions: `tests/buffer_basic_test.bas` (allocate → write → size-check → read-back → free → post-free accessors return 0/"" → idempotent free) and `tests/buffer_slots_test.bas` (three concurrent slots with distinct sizes and paths, replace-rotates-path behaviour). Example: `examples/buffer_http_demo.bas` — fetches a large JSON API response into a buffer, scans it byte-by-byte with `GET#` and a sliding window so no chunk boundary is ever missed, demonstrates the "best practice" streaming pattern that replaces `HTTP$` for anything over 4 KB. Deferred to steps 2 + 3: `JSONFILE$(path$, jpath$)` (file-aware JSON extract) and `RESTORE BUFFER` / `RESTORE FILE` (DATA/READ retargeting).

- **Statement: `CLS` — dialect-neutral clear-screen alias.** `PRINT CHR$(147);` is the C64/PETSCII-native form and will stay the canonical way to clear in programs that also switch charset or reset reverse mode, but it's a hieroglyph for anyone coming from QB, BBC, Amiga, Atari, or TRS-80 BASIC where `CLS` is the obvious word. New single-word statement routes to the same `gfx_clear_screen()` path in basic-gfx / canvas WASM (so it respects `SCREEN` mode — text plane in `SCREEN 0`, bitmap plane in `SCREEN 1`), and writes `\033[2J\033[H` to stdout in the terminal build. Cursor is homed to (0, 0) on every path. Added to reserved-word table and to the `C`-case statement dispatcher (sits above `CLR` so the longer word doesn't shadow — `starts_with_kw` matches on word boundary anyway, but ordering makes the grep-audit easier).

- **Mouse + sprites: `ISMOUSEOVERSPRITE(slot)` engine-level bounding-rect hit test.** Previously the only way to do mouse-over / click detection on a sprite from BASIC was to manually track the sprite's x/y/w/h and compare to `GETMOUSEX/Y` each iteration — painful, error-prone, and visibly laggy when dragging in the browser because every comparison runs through the interpreter. New function returns `1` if the current mouse position lies inside the bounding rect of the slot's most recent `DRAWSPRITE`, `0` otherwise. Implementation detail: `DRAWSPRITE` queues the draw onto a worker thread, so reading position/size from the queue would race the consumer. Instead, `gfx_sprite_enqueue_draw` now also writes into a `g_sprite_draw_pos[slot]` cache on the interpreter thread (same thread that calls the hit test), sw/sh ≤ 0 resolved via `gfx_sprite_effective_source_rect` for SPRITEFRAME / tilemap slots; `UNLOADSPRITE` zeroes the entry. Mirrored in `gfx/gfx_raylib.c` and `gfx/gfx_software_sprites.c` (canvas WASM) with identical semantics. Wired into `basic.c` as `FN_ISMOUSEOVERSPRITE = 62`: enum entry, 'I'-case name lookup, `eval_factor` dispatch (returns `0.0` when no gfx state), and `starts_with_kw` allow-list. Out of scope for MVP: pixel-perfect alpha test, rotation, scale pivot offsets — see `docs/mouse-over-sprite-plan.md` for the planned follow-ups. Example: `examples/ismouseoversprite_demo.bas`.

- **Mouse: `ISMOUSEBUTTONPRESSED` / `ISMOUSEBUTTONRELEASED` no longer lose edges between host polls.** The edge latches in `gfx/gfx_mouse.c` used to be recomputed from scratch on every `gfx_mouse_apply_poll` call (overwrite, not accumulate). On the canvas WASM build the poll runs once per `requestAnimationFrame` (~60 Hz, driven by the browser event loop), while BASIC's `DO ... LOOP` runs at whatever cadence the interpreter can sustain. When two polls happened between two BASIC iterations — trivially possible for a quick click or a heavy loop — the first poll would latch PRESSED, the second poll would see the button still down, clear PRESSED, set BTN_CUR=1, and BASIC would observe a button that was magically "down but never pressed." The visible symptom was buttons/sprites that sometimes didn't respond to a click; dragging felt fine because it uses DOWN (steady-state), not PRESSED (edge). Fix: `gfx_mouse_apply_poll` now OR-s new edges into `g_press_latch` / `g_release_latch` (sticky accumulation across polls), and `gfx_mouse_button_pressed` / `gfx_mouse_button_released` clear the latch on read (one observed edge per click). BTN_CUR and `gfx_mouse_button_down` / `_up` are unchanged. Raylib native and canvas WASM both get the fix automatically (shared `apply_poll` path). No BASIC-side behaviour change for well-behaved loops that read PRESSED once per iteration; programs that read PRESSED multiple times per loop will now see the edge only once, which matches the Raylib semantic.

- **Parser: `ENDIF` accepted as alias for `END IF`.** Many BASIC dialects (and tutorials) use the single-word form interchangeably with the two-word form, but the interpreter only recognised `END IF`. Two sites needed the fix: (1) the statement dispatcher, which matched `END` then required whitespace-then-`IF`, so `ENDIF` fell through to the generic "halt" branch; and (2) `skip_if_block_to_target`, the forward scanner used by block IF's false branch, which likewise only accepted `END IF`. The visible symptom was an inline `IF ... THEN stmt` followed by a block `IF ... THEN / ... / ENDIF` erroring as `"END IF expected"` — the false-branch skip walked past the single-word `ENDIF` without decrementing nesting and ran off the end of the program. Both sites now check `ENDIF` (one word) first; if not matched they fall through to the existing `END` + space + `IF` path. Regression: `tests/endif_alias_test.bas` covers the buttons.bas pattern (inline IF followed by block IF closed with `ENDIF`), false-branch skip across nested `ENDIF`, and a mixed `ENDIF` / `END IF` nested-with-ELSE case.

- **Text in bitmap mode — `PRINT` / `TEXTAT` / `CHR$(147)` now render in `SCREEN 1`.** Previously those statements wrote to the text plane (`screen[]` / `color[]`), which isn't visible in bitmap mode, so any HUD, score, or status line in a `SCREEN 1` program silently did nothing. The fix stamps the active 8×8 chargen glyph into `bitmap[]` at character-cell positions whenever `gfx_vs->screen_mode == GFX_SCREEN_BITMAP`. Solid paper per stamp so over-prints overwrite cleanly. `CHR$(147)` in bitmap mode clears the bitmap plane (same code path as `BITMAPCLEAR`) and leaves the text plane alone. Row-25 overflow in bitmap mode scrolls the bitmap up by one character cell (8 pixel rows, `memmove` on `bitmap[]`, bottom 320 bytes zeroed). Text-mode behaviour is unchanged in all three cases. 80-col requested before `SCREEN 1` is clamped to 40 columns for the character-set path (80-col remains text-mode only per `docs/bitmap-text-plan.md`). New helpers in `gfx/gfx_video.c`: `gfx_video_bitmap_clear()`, `gfx_video_bitmap_stamp_glyph()`, `gfx_video_bitmap_scroll_up_cell()`. `BITMAPCLEAR` now delegates to `gfx_video_bitmap_clear` for consistency. Regression: `tests/gfx_video_test.c` gains four new assertion blocks covering clear-doesn't-touch-text-plane, stamp at `(0,0)` and `(5,3)` with known patterns, transparent vs solid paper, out-of-range clip + NULL tolerance, `"HI"` walked through the same stamp-and-advance pattern `gfx_put_byte` uses, and unique-per-row fill then scroll with post-shift verification. `DRAWTEXT` pixel-space text + `LOADFONT` are still to come (see to-do "Text in bitmap mode + pixel-space `DRAWTEXT`").

### 1.6.3 – 2026-04-14

- **Engine: `gfx_poke` / `gfx_peek` bitmap/chars overlap** — C64-style memory map has bitmap `$2000–$3F3F` overlapping character RAM `$3000–$37FF`. Previously the chars region always won, so `MEMSET 8192, 8000, 0` from BASIC failed to clear the band of bitmap pixels whose bytes sat inside `$3000–$37FF` (roughly rows 102–167 of a 320×200 frame). Fix: when an address falls in both regions, dispatch on `screen_mode` — bitmap wins in `GFX_SCREEN_BITMAP`, chars wins in `GFX_SCREEN_TEXT`. Adds `addr_in()` helper and documents both overlap rules in `gfx_peek`. Regression: `tests/gfx_video_test.c` full-coverage POKE/clear loop across `$2000–$3F3F` plus TEXT↔BITMAP round-trip at `$3000`.

- **Parser: `IF cond THEN <stmt-with-comma-args> : <stmt>`** — `statement_poke`'s non-gfx-build fallback did `*p += strlen(*p)`, eating any trailing `: stmt` on the line. So `IF X = 5 THEN POKE 1024, 65 : Z = 99` never ran the assignment. Fix: parse the two args identically in both builds (so the parser pointer lands cleanly on `:` or end-of-line), then discard them via `(void)` casts in the terminal build. Audit context: every `*p += N` keyword-skip (68 sites) and every `*p += strlen(*p)` fallback (8 sites) in `basic.c` was reviewed — only POKE was buggy; the other strlen-fallbacks are intentional (REM, DEF FN body, IF false branch, DATA, END/STOP, unknown-token last-resort). Regression: `tests/then_compound_test.bas` (5 cases: COLOR, LOCATE, POKE, false-IF skip, PRINT comma-list) via `tests/then_compound_test.sh`.

- **Parser: `MOUSESET` keyword-skip off-by-one** — statement dispatcher advanced `*p` by 7 for the 8-character `MOUSESET`, so the trailing `T` was reparsed as a variable and the comma check failed with `MOUSESET expects x, y`.

- **Parser: mouse functions in `eval_factor` allow-list** — mouse feature merge added `FN_GETMOUSEX/Y` and `FN_ISMOUSEBUTTON*` opcodes and runtime handlers but missed adding the names to the function-name allow-list in `eval_factor`. Added `GETMOUSEX`, `GETMOUSEY`, `ISMOUSEBUTTONPRESSED`, `ISMOUSEBUTTONDOWN`, `ISMOUSEBUTTONRELEASED`, `ISMOUSEBUTTONUP` to the `starts_with_kw()` chain.

- **Statement: `BITMAPCLEAR`** — new no-arg statement that clears the 8000-byte bitmap plane (`memset(gfx_vs->bitmap, 0, sizeof(gfx_vs->bitmap))`) without touching text/colour RAM. Available in basic-gfx and canvas WASM; terminal build returns a runtime error hint. Complements `PRINT CHR$(147)` (text/colour clear) for programs that draw on both layers.

- **CI: `gfx_video_test` runs on every build** — `tests/gfx_video_test.c` (C-level unit test for `gfx_poke` / `gfx_peek` region dispatch) is now built and run on ubuntu/macos/windows. Pure C, no raylib, headless, sub-second. Catches regressions of the overlap fix automatically.

- **CI + tooling: `make check` target and shared suite runner** — `tests/run_bas_suite.sh` is now the single source of truth for the headless `.bas` suite's skip list; `Makefile`'s new `check` target and `.github/workflows/ci.yml` (Unix and Windows) both invoke it. `make check` builds the binaries, runs the C unit test, the shell wrappers (`get_test.sh`, `trek_test.sh`, `then_compound_test.sh`), and the `.bas` suite — so local dev mirrors CI exactly.

- **Example: `gfx_mouse_demo.bas`** — new self-contained demo exercising every mouse API (`GETMOUSEX/Y`, `ISMOUSEBUTTONDOWN/PRESSED`, `MOUSESET`, `SETMOUSECURSOR`, `HIDECURSOR`/`SHOWCURSOR`), plus `web/mouse-demo.html` for canvas WASM. Right-click uses `BITMAPCLEAR`; warp marker visibility counter shows where `MOUSESET` landed the pointer.

- **Mouse (basic-gfx + canvas WASM):** **`GETMOUSEX()`** / **`GETMOUSEY()`** in framebuffer pixel space (**0** … **width−1** / **height−1**). **`IsMouseButtonPressed(n)`** / **`IsMouseButtonDown(n)`** / **`IsMouseButtonReleased(n)`** / **`IsMouseButtonUp(n)`** — **n** = **0** left, **1** right, **2** middle (Raylib-compatible). **`MOUSESET x, y`** warps the pointer (native Raylib; WASM: **`Module.rgcMouseWarp`** in **`web/canvas.html`** and **`gfx-embed-mount.js`**). **`SETMOUSECURSOR code`** (Raylib **`MouseCursor`** enum; WASM maps to CSS **`cursor`**). **`HIDECURSOR`** / **`SHOWCURSOR`**. **`gfx/gfx_mouse.c`**; **`Makefile`**: **`gfx_mouse.c`** in **`GFX_BIN_SRCS`** and canvas WASM link; **`EXPORTED_FUNCTIONS`**: **`_wasm_mouse_js_frame`**. **`wasm_browser_canvas_test.py`**: asserts **`_wasm_mouse_js_frame`** is exported.

- **WASM `EXEC$` / `SYSTEM` host hook:** **`Module.rgcHostExec(cmd)`** (or **`Module.onRgcExec`**) — **`EM_ASYNC_JS`** **`wasm_js_host_exec_async`**; return **`{ stdout, exitCode }`**, a string, or a **Promise**. **`EXEC$`** trims trailing CR/LF like native **`popen`**. Flush before call (GFX **`wasm_gfx_refresh_js`** / terminal **`BEFORE_CSTDIO`** + **`emscripten_sleep(0)`**). **`Makefile`**: **`ASYNCIFY_IMPORTS`** includes **`__asyncjs__wasm_js_host_exec_async`**. Doc: **`docs/wasm-host-exec.md`**; demo hook + sentinel in **`web/index.html`**; Playwright: **`tests/wasm_browser_test.py`**.

- **WordPress plugin 1.2.7:** **`registerBlockType`** in **`block-editor.js`** and **`gfx-block-editor.js`** now sets **`apiVersion: 3`** explicitly. WordPress **6.9** iframe editor treats blocks registered as API **1** as legacy and **omits them from the block inserter** (console: `rgc-basic/gfx-embed` deprecated); this fixes **“No results”** when searching **gfx**.

- **`copy-web-assets.sh`:** After copying WASM/JS, syncs **`build/`** from **`$REPO`** when the plugin folder is **not** already inside that repo (e.g. copy plugin to Desktop then run with path to rgc-basic). If the script is run **from** `wordpress/rgc-basic-tutorial-block` inside the checkout, **`build/`** source and destination are the same — skip **`cp`** to avoid **`identical (not copied)`** errors.

- **WordPress plugin 1.2.6:** Renamed **`build/block-editor-gfx.js`** → **`build/gfx-block-editor.js`** — FTP had often left **`block-editor-gfx.js`** as a duplicate of **`block-editor.js`** (wrong **`registerBlockType`**), and Cloudflare cached **`max-age=31536000`**. New filename + comment guard; purge CDN after deploy. Bootstrap file may be **`rgc-basic-blocks.php`** (same code as historical **`rgc-basic-tutorial-block.php`**).

- **WordPress plugin 1.2.1:** **`enqueue_block_editor_assets`** now calls **`wp_enqueue_script`** for **`rgc-basic-tutorial-block-editor`** and **`rgc-basic-tutorial-block-editor-gfx`** so the GFX editor script always loads in Gutenberg (fixes missing second block when **`block-gfx.json`** on server was outdated or PHP opcode cache served old registration).

- **WordPress plugin 1.2.0:** Split editor scripts: **`build/block-editor-gfx.js`** registers **`rgc-basic/gfx-embed`**; **`block-gfx.json`** uses **`editorScript`** `rgc-basic-tutorial-block-editor-gfx`. Avoids missing second block when an old cached **`block-editor.js`** was uploaded without the combined two-block file.

- **WordPress plugin:** **`assets/js/gfx-embed-mount.js`** was listed in **`.gitignore`** under **`assets/js/*`**, so it never existed in the remote repo after **`git pull`** — fixed by un-ignoring that file and adding it to version control.

- **WordPress plugin 1.1.0:** Plugin version bump; **`block-gfx.json`** keywords expanded (**rgc**, **gfx**, **embed**) so the inserter search finds the GFX block; README troubleshooting when **`build/block-editor.js`** is stale (only terminal block appears).

- **`copy-web-assets.sh`:** Deploys **`gfx-embed-mount.js`** (not under **`web/`**): if **`assets/js/gfx-embed-mount.js`** already exists next to the script (after **`git pull`**), the script keeps it; otherwise copies from **`$REPO/wordpress/rgc-basic-tutorial-block/assets/js/`** when present. Fixes **404** for the GFX block when the file was never copied to the server.

- **WordPress plugin — RGC-BASIC GFX embed block:** **`wordpress/rgc-basic-tutorial-block`** registers **`rgc-basic/gfx-embed`** (`block-gfx.json`): canvas WASM via **`gfx-embed-mount.js`** + **`frontend-gfx-init.js`**, **`basic-canvas.js`** / **`basic-canvas.wasm`** from the same WASM base URL as the terminal block; inspector options for code, controls, fullscreen, poster image, interpreter flags. **`copy-web-assets.sh`** copies canvas WASM when present. **`docs/wordpress-canvas-embed.md`** documents **Option 4**.

- **Documentation:** **`docs/wordpress-canvas-embed.md`** — embedding **canvas WASM** (sprites, **`SCREEN 1`**) in WordPress: iframe **`canvas.html`**, custom HTML, vs terminal-only plugin; links to **`docs/ide-retrogamecoders-canvas-integration.md`** and **`docs/wasm-assets-loadsprite-http.md`**.

- **Documentation:** **`docs/wasm-assets-loadsprite-http.md`** — why **`LOADSPRITE`** cannot use **`https://`** URLs; **`HTTPFETCH`** to MEMFS; CORS; JS **`FS.writeFile`**; canvas vs terminal embeds. Linked from **`docs/http-vfs-assets.md`** and **`web/README.md`**.

- **WASM `HTTP$` / `HTTPFETCH`:** Before Asyncify **`fetch`**, flush **canvas** framebuffer to JS (**`wasm_gfx_refresh_js`**) or **terminal** stdout buffer (**`BEFORE_CSTDIO`**) and **`emscripten_sleep(0)`** so **`PRINT`** output (e.g. headers) is visible before the network call blocks.

- **`JSON$` object/array values:** Fixed **`json_skip_value`** so **`}`** / **`]`** after the last property/element is consumed (parser previously stopped one delimiter short for nested objects/arrays). **`JSON$(json$, path)`** returns the **raw JSON text** for object and array values (truncated to max string length). Regression: **`tests/json_test.bas`**, **`tests/json_object_value_test.bas`**.

- **`INSTR` case-insensitive option:** **`INSTR(source$, search$ [, start [, ignore_case]])`** — when **`ignore_case`** is non‑zero, matching uses **ASCII** case folding (`tolower` on each byte). Omitted or **0** preserves the previous case-sensitive behavior. Regression: **`tests/instr_case_insensitive.bas`**.

- **Documentation:** **`docs/http-vfs-assets.md`** — design notes on **HTTP fetch → MEMFS**, **binary file I/O**, and **IDE tools** (complements **`docs/ide-wasm-tools.md`**); linked from **`to-do.md`**.

- **Canvas WASM IDE tools — `basic_load_and_run_gfx_argline`:** New export parses a single **`argline`** (quoted tokens allowed); **first token** = **`.bas`** path on MEMFS; rest = **`ARG$(1)`** … for **`run_program`**. Use from the IDE to pass asset paths (e.g. PNG preview). Spec: **`docs/ide-wasm-tools.md`**.

- **Loader: `OPTION` / `INCLUDE` without `#`:** Meta lines are accepted as **`OPTION …`** / **`INCLUDE …`** (same as **`#OPTION`** / **`#INCLUDE`**) for **numbered** and **unnumbered** programs — matches the Retro Game Coders **8bitworkshop** IDE style and avoids **`Expected '='`** when using e.g. **`10 OPTION CHARSET PET-LOWER`**.

- **PET-style vs C64 character ROM (basic-gfx + canvas WASM):** **`GfxVideoState.charrom_family`** selects the built-in **C64** glyph tables (default) or alternate **8×8 bitmaps** in **`pet_uppercase.64c`** / **`pet_lowercase.64c`** (same **256 screen-code order** as the C64 font; only pixel data changes — matches the “PET feel” custom charset on **C64** in the Retro Game Coders IDE). Not the physical **PET 2001** 2K chargen. CLI / **`#OPTION`**: **`pet-upper`** / **`pet-graphics`**, **`pet-lower`** / **`pet-text`**; **`c64-upper`** / **`c64-lower`** for stock C64 ROMs. Each **`load_program`** restores charset options from the CLI baseline. **`tests/gfx_video_test`**: C64 vs PET-style glyph **0** differ when **`charrom_family`** is set.

- **HTTP fetch to file + binary I/O:** **`S = HTTPFETCH(url$, path$ [, method$ [, body$]])`** — **Emscripten**: async **`fetch`** + **`FS.writeFile`** (response body as raw bytes; **`HTTPSTATUS()`** / return value = HTTP status). **Unix native** (no Emscripten): uses **`curl -o path -w "%{http_code}"`** when **`curl`** is available (GET only; optional args ignored). **`OPEN`**: optional filename prefix **`"rb:"`**, **`"wb:"`**, **`"ab:"`** for binary **`fopen`** modes (e.g. **`OPEN 1,1,0,"rb:/data.bin"`** — use **device 1** for host files). **`PUTBYTE #lfn, expr`** writes one byte (0–255); **`GETBYTE #lfn, var`** reads one byte into a **numeric** variable (0–255, or **-1** at EOF). **`Makefile`**: **`ASYNCIFY_IMPORTS`** includes **`__asyncjs__wasm_js_http_fetch_to_file_async`**. Regression: **`tests/wasm_browser_test.py`** (MEMFS fetch of **`web/wasm_httpfetch_test.bin`**), **`tests/binary_io_roundtrip.bas`**.

- **Documentation:** **`docs/http-vfs-assets.md`** — design notes on **HTTP fetch → MEMFS**, **binary file I/O**, and **IDE tools** (complements **`docs/ide-wasm-tools.md`**); linked from **`to-do.md`**.

- **`SPRITEMODULATE` + deferred `LOADSPRITE` (canvas WASM):** On WASM, **`LOADSPRITE`** is applied when **`gfx_sprite_process_queue`** runs (often **after** the next statements). Finishing the load reset modulation to defaults, wiping **`SPRITEMODULATE`** if it ran before the decode. Slots now track **`mod_explicit`**; modulation set via **`SPRITEMODULATE`** is restored when the queued load completes (same fix in **Raylib** for consistency).

- **`SPRITEMODULATE` (basic-gfx + canvas WASM):** Per-slot draw tint and scale until **`LOADSPRITE`** / **`UNLOADSPRITE`**. Syntax: **`SPRITEMODULATE slot, alpha [, r, g, b [, scale_x [, scale_y]]]`** — **`alpha`** and **`r`/`g`/`b`** are **0–255** (**`alpha`** multiplies PNG alpha); **`scale_x`/`scale_y`** stretch the drawn quad (default **1**; one scale sets both). Implemented with Raylib **`Color`** + destination size; canvas uses bilinear-ish sampling + tint. **`gfx_sprite_set_modulate`** in **`basic_api.h`**.

- **Load normalization / identifiers containing `IF`:** **`normalize_keywords_line`** treated **`IF`** inside identifiers as **`IF …`** (e.g. **`JIFFIES_PER_FRAME`** → **`J IF FIES_PER_FRAME`**, breaking assignments). The same **`prev_ident`** guard used for **`FOR`** (avoid splitting **`PLATFORM`**) now applies to the **`IF`** insertion rule. Regression: **`tests/if_inside_ident_normalize.bas`**.

- **`gfx_peek()` keyboard vs colour RAM**: With default bases, **`GFX_KEY_BASE` (0xDC00)** lies inside the colour RAM window **(0xD800 + 2000 bytes)**. **`gfx_peek()`** must resolve **keyboard before colour** or **`PEEK(56320+n)`** reads colour bytes (e.g. **14** for light blue). **`gfx_video.c`** documents the required order (**text → keyboard → colour → charset → bitmap**). **`gfx_video_test`** asserts key wins over colour at the aliased address.

- **Browser WASM HTTP (`HTTP$` / `HTTPSTATUS`)**: **`R$ = HTTP$(url$ [, method$ [, body$]])`** performs **`fetch`** (Asyncify + **`EM_ASYNC_JS`**). **`HTTPSTATUS()`** returns the last HTTP status (**0** on failure). Response body is truncated to the current max string length. **Native / non-Emscripten**: **`HTTP$`** returns **`""`** (use **`EXEC$("curl …")`**). **`Makefile`**: **`ASYNCIFY_IMPORTS`** includes **`__asyncjs__wasm_js_http_fetch_async`**. **`starts_with_kw`**: longer identifiers no longer match shorter keywords (**`HTTP`** vs **`HTTPSTATUS`**). **`HTTP(url$)`** without **`$`** is accepted as an alias for **`HTTP$`** (avoids collision with user **`FUNCTION HTTP`**). Example: **`examples/http_time_london.bas`**.

- **`SPRITEFRAME` statement**: Dispatch lived under **`c == 'D'`** but the keyword starts with **S**, so **`SPRITEFRAME 0, 1`** fell through to **`LET`** and failed with “reserved word cannot be used as variable”. Moved handling to the **`S`** branch with **`SPRITEVISIBLE`**.

- **basic-gfx (macOS) tilemap / `DRAWSPRITETILE` crash**: `gfx_sprite_process_queue()` called `LoadTexture` from the **interpreter thread** when `gfx_sprite_tile_source_rect` ran before the main loop processed the queue — **OpenGL must run on the main thread** on macOS (crash in `glBindTexture`). **LOADSPRITE** / **UNLOADSPRITE** now **wait** until the render loop finishes the GPU work; `gfx_sprite_tile_source_rect` and related helpers no longer call `gfx_sprite_process_queue()` from the worker. One extra `gfx_sprite_process_queue()` after the render loop exits so pending loads are not left waiting.

- **Canvas WASM `CHR$(14)` / `CHR$(142)` charset switch**: **`gfx_apply_control_code`** set **`charset_lowercase`** but did not reload **`gfx_load_default_charrom`** (unlike **basic-gfx**, which refreshes ROM each Raylib frame). **`PRINT CHR$(14)`** now reloads glyph bitmaps so **colaburger** and mixed-case text match the CLI.

- **`gfx_jiffy_game_demo.bas`**: Simplified **main loop** for **canvas WASM** + **basic-gfx**: one **`SLEEP 1`** per frame, **enemy** sine from **`TI`**, **WASD** **`PEEK`** every frame (no **`TI`** bucket wait or **`PMOVE`/`ELT`** gating — those interacted badly with Asyncify / wall-clock **`TI`**). **`TEXTAT`** HUD on **rows 2–3**. Earlier fixes: unique line numbers; **`TEXTAT`** not on banner rows.

- **Examples**: **`gfx_inkey_demo.bas`** uses **`UCASE$(K$)`** before **`ASC`** so lowercase **w** matches **W** (87). **`gfx_key_demo.bas`** REMs clarify **`PEEK(56320+n)`** uses **uppercase ASCII** **`n`** (same as **`ASC("W")`**). **`README.md`** documents polling vs **`INKEY$`** case.

- **Viewport scroll (basic-gfx + canvas WASM):** **`SCROLL dx, dy`** sets pixel pan for the text/bitmap layer and sprites; **`SCROLLX()`** / **`SCROLLY()`** read offsets. `GfxVideoState.scroll_x` / `scroll_y`; Raylib and canvas compositors apply the same shift. Examples: **`examples/tutorial_gfx_scroll.bas`**, overview **`web/tutorial-gfx-features.html`**.

- **Nested block `IF` / `ELSE` / `END IF`:** Skipping to `ELSE` or `END IF` scanned for nested `IF` by incrementing nesting on every `IF … THEN`. **Inline** `IF cond THEN stmt` (no `END IF`) was counted as a block, so nesting never returned to **0** and the run ended with **"END IF expected"** (common in games with `IF … THEN PRINT` inside a block `IF`). Only **block** `IF` (nothing after `THEN`, or `THEN:` only) increments nesting now — same rule as `statement_if`. Regression: **`tests/if_skip_inline_nested.bas`**.

- **Canvas WASM keyboard polling during `SLEEP`:** `canvas.html` used `ccall('wasm_gfx_key_state_set')` from `keydown`/`keyup`. With **Asyncify**, that can fail while the interpreter is inside **`emscripten_sleep`** (e.g. **`gfx_key_demo.bas`**, **`gfx_jiffy_game_demo.bas`** loops), so **`PEEK(56320+n)`** never saw keys. **`wasm_gfx_key_state_ptr`** exports the **`key_state[]`** address; JS updates **`Module.HEAPU8`** directly (no re-entrant WASM). Run clears keys the same way.

- **Gamepad (basic-gfx + canvas WASM):** **`JOY(port, button)`**, alias **`JOYSTICK`**, and **`JOYAXIS(port, axis)`** (`gfx_gamepad.c`). **Native:** Raylib **1–15** button codes; axes **0–5** scaled **-1000..1000**. **Canvas WASM:** `canvas.html` polls **`navigator.getGamepads()`** each frame into exported buffers; Raylib codes map to **Standard Gamepad** indices. **Terminal WASM** (no `GFX_VIDEO`) still returns **0**. **`HEAP16`** + **`_wasm_gamepad_buttons_ptr`** / **`_wasm_gamepad_axes_ptr`** exports. Example **`examples/gfx_joy_demo.bas`**.

- **Tilemap sprite sheets:** **`LOADSPRITE slot, "path.png", tw, th`** defines a **tw×th** tile grid; **`SPRITETILES(slot)`**, **`DRAWSPRITETILE slot, x, y, tile_index [, z]`** (1-based tile index), **`SPRITEFRAME slot, frame`** / **`SPRITEFRAME(slot)`** (default tile for **`DRAWSPRITE`** when crop omitted), **`gfx_sprite_effective_source_rect`**, **`SPRITEW`/`SPRITEH`** return one tile size when tilemap is active. **`SPRITECOLLIDE`** uses tile size when no explicit crop.

- **Virtual memory bases (basic-gfx + canvas WASM)**: `GfxVideoState` stores per-region **`mem_*`** bases for **`POKE`/`PEEK`** (defaults unchanged: screen **`$0400`**, colour **`$D800`**, charset **`$3000`**, keyboard **`$DC00`**, bitmap **`$2000`**). **`#OPTION memory c64`** / **`pet`** / **`default`**; per-region **`#OPTION screen`**, **`colorram`**, **`charmem`**, **`keymatrix`**, **`bitmap`** (decimal, **`$hex`**, or **`0xhex`**). **`basic-gfx`**: **`-memory c64|pet|default`**. Each load resets from the CLI baseline then applies file **`#OPTION`**. **`gfx_peek()`** overlap priority: see unreleased note above (keyboard before colour at default bases). **`gfx_video_test`**: PET preset + 64K overflow rejection.

- **Runtime hints**: **`goto` / `gosub` / `return`**, **`on` … `goto`/`gosub`**, **`if`/`else`/`end if`**, **`function`/`end function`**, **`DIM` / `FOR` / `NEXT`**, **array subscripts**, **`LET`/`=`**, **`INPUT`**, **`READ`/`DATA`**, **`RESTORE`**, **`GET`**, **`LOAD`/`MEMSET`/`MEMCPY`**, **`OPEN`/`CLOSE`** and **`PRINT#`/`INPUT#`/`GET#`**, **`TEXTAT`/`LOCATE`**, **`SORT`**, **`SPLIT`/`JOIN`**, **`CURSOR`**, **`COLOR`/`BACKGROUND`**, **`SCREEN`/`PSET`/`PRESET`/`LINE`/`SCREENCODES`**, **`LOADSPRITE`/`DRAWSPRITE`/`SPRITEVISIBLE`/`UNLOADSPRITE`**, **`WHILE`/`WEND`**, **`DO`/`LOOP`/`EXIT`** — short **`Hint:`** lines for common mistakes. **Also**: **`DEF FN`**, **`EVAL`/`JSON$`/`FIELD$`**, string builtins (**`MID$`/`LEFT$`/`RIGHT$`/`INSTR`/`REPLACE`/`STRING$`**), **`INDEXOF`/`LASTINDEXOF`**, **`SPRITECOLLIDE`** and zero-arg builtins, **`SLEEP`**, expression/UDF syntax (**`Missing ')'`**, **`Too many arguments`**, **`Syntax error in expression`**), resource limits (**out of memory**, **variable table full**, **program too large**), **`INPUT`** **Stopped**, and **loader** stderr (**`#INCLUDE`/`#OPTION`**, line length, circular includes, mixed numbered/numberless lines, duplicate labels/lines, missing **END FUNCTION**). **Native** `runtime_error_hint` prints **`Hint:`** on stderr (parity with WASM). **`tutorial-embed.js`**: **Ctrl+Enter** / **Cmd+Enter** runs; **`scrollToError`** (default **on**). **`web/tutorial.html`** playground mentions keyboard run.

- **Documentation**: **`README.md`** — **Runtime errors** and **Load-time errors** bullets under *Shell scripting* describe **`Hint:`** lines on stderr (terminal) and in the WASM output panel.

- **Sprites**: **`SPRITECOLLIDE(a, b)`** — returns **1** if two loaded, visible sprites’ axis-aligned bounding boxes overlap (basic-gfx + canvas WASM; **0** otherwise). Terminal **`./basic`** errors if used (requires **basic-gfx** or canvas WASM). **Runtime errors**: optional **`Hint:`** line for **unknown function** (shows name) and **`ensure_num` / `ensure_str`** type mismatches. **`tutorial-embed.js`**: optional **`runOnEdit`** / **`runOnEditMs`** for debounced auto-run after editing; **`web/tutorial.html`** enables this on the final playground embed only (**550** ms).

- **Documentation**: **`docs/basic-to-c-transpiler-plan.md`** — design notes for a future **BASIC → C** backend (**cc65** / **z88dk**), recommended subset, and **explicit exclusions** (host I/O, `EVAL`, graphics, etc.).

- **IF conditions with parentheses**: **`IF (J=F OR A$=" ") AND SF=0 THEN`** failed with **Missing THEN** because **`eval_simple_condition`** used **`eval_expr`** inside **`(`**, which does not parse relational **`=`**. Leading **`(`** now distinguishes **`(expr) relop rhs`** (e.g. **`(1+1)=2`**) from boolean groups **`(… OR …)`** via **`eval_condition`**. Regression: **`tests/if_paren_condition_test.bas`**.

- **Canvas WASM `PEEK(56320+n)` keyboard**: **`key_state[]`** was never updated in the browser (only **basic-gfx** / Raylib did). **`canvas.html`** mirrors keys on key up/down (A–Z, 0–9, arrows, Escape, Space, Enter, Tab); prefer **`HEAPU8`** at **`wasm_gfx_key_state_ptr()`** during **`SLEEP`** (see unreleased note above). **`examples/gfx_jiffy_game_demo.bas`** / **`gfx_key_demo.bas`**-style **`PEEK(KEYBASE+…)`** works with the canvas focused.

- **Canvas WASM `TI` / `TI$`**: **`GfxVideoState.ticks60`** was only advanced in the **Raylib** main loop, so **canvas** **`TI`** / **`TI$`** stayed frozen (especially in tight **`GOTO`** loops). **Canvas** now derives 60 Hz jiffies from **`emscripten_get_now()`** since **`basic_load_and_run_gfx`** ( **`gfx_video_advance_ticks60`** still drives **basic-gfx** each frame). **Terminal WASM** (`basic.js`, no **`GFX_VIDEO`**) still uses **`time()`** for **`TI`** / **`TI$`** (seconds + wall-clock `HHMMSS`), not C64 jiffies.

- **WordPress**: New plugin **`wordpress/rgc-basic-tutorial-block`** — Gutenberg block **RGC-BASIC embed** with automatic script/style enqueue, **`copy-web-assets.sh`** to sync **`web/tutorial-embed.js`**, **`vfs-helpers.js`**, and modular WASM into **`assets/`**; optional **Settings → RGC-BASIC Tutorial** base URL.

- **Canvas WASM `TAB`**: **`FN_TAB`** used **`OUTC`** for newline/spaces, which updates **`print_col`** but not the **GFX** cursor, so **`PRINT … TAB(n) …`** misaligned on the canvas. **GFX** path now uses **`gfx_newline`** + **`print_spaces`** (same as **`SPC`**). **`wasm_gfx_screen_screencode_at`** exported for **`wasm_browser_canvas_test`** regression.

- **Canvas / basic-gfx INPUT line (`gfx_read_line`)**: Removed same-character time debounce (~80 ms) that dropped consecutive identical keys, so words like **"LOOK"** work. **Raylib `keyq_push`** no longer applies the same filter (parity with canvas).

- **WASM `run_program`**: Reset **`wasm_str_concat_budget`** each **`RUN`** (was missing; concat-yield counter could carry across runs).

- **WASM canvas string concat (`Q$=LEFT$+…`)**: **`trek.bas`** **`GOSUB 5440`** builds **`Q$`** with **`+`** ( **`eval_addsub`** ) without a **`MID$`** per assignment — no prior yield path. **Canvas WASM** now yields every **256** string concatenations (**`wasm_str_concat_budget`**, separate from **`MID$`** counter).

- **WASM canvas yields**: **`execute_statement`** / **`run_program`** yield intervals relaxed (**128** / **32** statements) so **pause → resume** keeps advancing tight **`FOR`** loops in tests; **string-builtin** yields still cover **`trek.bas`**-style **`MID$`** storms.

- **Canvas `wasm_push_key` duplicate keys**: **`wasm_push_key`** was enqueueing every byte into **both** the **GFX key queue** and **`wasm_key_ring`**. **`GET`** consumed the queue first, then **`read_single_char_nonblock`** read the **same** byte again from the ring → **double keypresses** and **skipped “press RETURN”** waits in **`trek.bas`**. **Canvas GFX** now pushes **only** to the **GFX queue** (ring used when **`gfx_vs`** is unset).

- **WASM canvas trek / string builtins**: **`trek.bas`** SRS **`PRINT`** evaluates **`MID$` / `LEFT$` / `RIGHT$`** hundreds of times **inside one** **`PRINT`** (few **`gfx_put_byte`** calls until the line ends). **Canvas WASM** now yields every **64** **`MID$`/`LEFT$`/`RIGHT$`** completions, plus periodic yields in **`INSTR`** / **`REPLACE`** scans and **`STRING$`** expansion.

- **WASM canvas trek / compound lines**: **`wasm_stmt_budget`** in **`run_program`** advances once per **`execute_statement` chain** from a source line, but **`trek.bas`** can run **hundreds** of **`:`**-separated statements (**`LET`**, **`IF`**, **`GOTO`**) without **`PRINT`** → no **`gfx_put_byte`** yield → tab **unresponsive**. **`execute_statement`** now yields every **4** statements (**pause**, **`wasm_gfx_refresh_js`**, **`emscripten_sleep(0)`**) when **`__EMSCRIPTEN__` + `GFX_VIDEO`**.

- **Loader / UTF-8 source lines**: **`fgets(..., MAX_LINE_LEN)`** split physical lines longer than **255 bytes**; the continuation had no line number → **`Line missing number`** with mojibake (common when **`trek.bas`** uses UTF-8 box-drawing inside **`PRINT`**). **`load_file_into_program`** now reads full lines up to **64KiB** via **`read_source_line`**.

- **WASM canvas long PRINT / trek.bas**: **`run_program`** only yields every N **':'**-separated statements; **`trek.bas`** packs huge loops on one line, and a single **`PRINT`** can call **`gfx_put_byte`** thousands of times without another yield — tab froze during galaxy generation. **Canvas WASM** now yields every 128 **`gfx_put_byte`** calls and yields every **8** statements (was 32). Regression: **`tests/wasm_browser_canvas_test.py`** (**`PRINT STRING$(3000,…)`**).

- **WASM GET (terminal + canvas)**: Non-blocking **`GET`** (empty string when no key) now **`emscripten_sleep(0)`** on every empty read for **all** Emscripten builds. **Terminal** **`basic.js`** had no yield, so **`IF K$="" GOTO`** loops froze the tab; **canvas** also refreshes the framebuffer on empty **`GET`**. Regression: **`tests/wasm_browser_test.py`** (**`GET`** poll + **`wasm_push_key`**).

- **WASM canvas / basic-gfx parity (glyph ROM)**: **`make basic-wasm-canvas`** now links **`gfx/gfx_charrom.c`** and **`gfx_canvas_load_default_charrom`** delegates to **`gfx_load_default_charrom`** (same bitmap data as **`basic-gfx`**). Removed duplicate **`petscii_font_*_body.inc`** tables that could drift and make canvas output differ from the native window.

- **PRINT (GFX)**: Unicode→PETSCII branch in **`print_value`** now routes through **`gfx_put_byte`** instead of writing **`petscii_to_screencode`** directly (kept **`charset_lower`** / **`CHR$`** semantics consistent; fixes stray +1 lowercase bugs when UTF-8 decode path runs).

- **Loader**: Lines like **`10 #OPTION charset lower`** in a **numberless** program (first line starts with a digit) are accepted — strip the numeric prefix so **`#OPTION` / `#INCLUDE`** apply (fixes canvas paste style where charset never switched).
- **Charset lower + CHR$**: With lowercase char ROM, non-letter bytes from **`CHR$(n)`** (and punctuation) use **raw screen code** `sc = byte`; **`petscii_to_screencode(65)`** was mapping to lowercase glyphs. **Regression**: `tests/wasm_canvas_charset_test.py`, **`make wasm-canvas-charset-test`** (includes numbered-`#OPTION` paste); CI workflow **`wasm-tests.yml`** runs full WASM Playwright suite on **push/PR to `main`**; release WASM job runs charset test too.

- **Browser canvas**: `#OPTION charset lower` (and charset from CLI before run) now applies when video state attaches — fixes PETSCII space (screen code 32) drawing as wrong glyph (e.g. `!`) because the uppercase char ROM was still active.
- **INPUT (canvas / GFX)**: When **Stop** / watchdog sets `wasmStopRequested` while waiting in `gfx_read_line`, report **"Stopped"** instead of **"Unexpected end of input"** (misleading; not EOF).

- **PETSCII + lowercase charset**: With lowercase video charset, **ASCII letters** in string literals use `gfx_ascii_to_screencode_lowcharset()`; **all other bytes** (including **`CHR$(n)`** and punctuation) use **`petscii_to_screencode()`** so `CHR$(32)` is space and `CHR$(65)` matches PETSCII semantics (was wrongly treated as ASCII, shifting output). Works with or without **`-petscii`** on the host. `wasm_browser_canvas_test` covers charset lower with and without the PETSCII checkbox.

- **Project**: Renamed to **RGC-BASIC** (Retro Game Coders BASIC). GitHub: **`omiq/rgc-basic`**. Tagline: modern cross-platform BASIC interpreter with classic syntax compatibility, written in C. WASM CI artifact: **`rgc-basic-wasm.tar.gz`**. Tutorial CSS classes: `rgc-tutorial-*` (`cbm-tutorial-*` removed). JS: prefer **`RgcBasicTutorialEmbed`** / **`RgcVfsHelpers`** (deprecated **`Cbm*`** aliases retained briefly).

- **CI / tests**: **`tests/wasm_browser_canvas_test.py`** — string-concat stress (**`LEFT$+A$+RIGHT$`** loop), **GOTO** stress, **`examples/trek.bas`** smoke (**Stop** after ~2.5s), **`SCREEN 0`** reset after bitmap test (fixes charset pixel assertions).

- **Browser / WASM (Emscripten)**
  - **Builds**: `make basic-wasm` → `web/basic.js` + `basic.wasm`; `make basic-wasm-canvas` → `basic-canvas.js` + `basic-canvas.wasm` (PETSCII + bitmap + PNG sprites via `gfx_canvas.c` / `gfx_software_sprites.c`, `GFX_VIDEO`). Asyncify for cooperative `SLEEP`, `INPUT`, `GET` / `INKEY$`.
  - **Demos**: `web/index.html` — terminal-style output, inline INPUT, `wasm_push_key` for GET/INKEY$; `web/canvas.html` — 40×25 or 80×25 canvas, shared RGBA framebuffer refreshed during loops and SLEEP.
  - **Controls**: Pause / Resume (`Module.wasmPaused`), Stop (`Module.wasmStopRequested`); terminal run sets `Module.wasmRunDone` when `basic_load_and_run` completes. FOR stack unwinds on `RETURN` from subroutines using inner `FOR` loops (e.g. GOSUB loaders).
  - **Interpreter / glue**: Terminal WASM stdout line-buffering for correct `PRINT` newlines in HTML; canvas runtime errors batched for `printErr`; `EVAL` supports `VAR = expr` assignment form in evaluated string. `canvas.html` uses matching `?cb=` on JS and WASM to avoid `ASM_CONSTS` mismatch from partial cache.
  - **CI**: GitHub Actions WASM job installs **emsdk** (`latest`) instead of distro `apt` emscripten; builds both targets; runs `tests/wasm_browser_test.py` and `tests/wasm_browser_canvas_test.py`.
  - **Optional**: `canvas.html?debug=1` — console diagnostics (`wasm_canvas_build_stamp`, stack dumps on error).
  - **Tutorial embedding**: `make basic-wasm-modular` → `web/basic-modular.js` + `basic-modular.wasm` (`MODULARIZE=1`, `createBasicModular`). `web/tutorial-embed.js` mounts multiple terminal-style interpreters per page (`RgcBasicTutorialEmbed.mount`; `CbmBasicTutorialEmbed` deprecated alias). Guide: `docs/tutorial-embedding.md`; example: `web/tutorial-example.html`. Test: `make wasm-tutorial-test`.
  - **Virtual FS upload/export**: `web/vfs-helpers.js` — `RgcVfsHelpers` (`CbmVfsHelpers` deprecated alias): `vfsUploadFiles`, `vfsExportFile`, `vfsMountUI` (browser → MEMFS and MEMFS → download). Wired into `web/index.html`, `web/canvas.html`, and tutorial embeds (`showVfsTools`). CI WASM artifacts include `vfs-helpers.js`.
  - **Canvas GFX parity with basic-gfx**: `SCREEN 1` bitmap rendering; software PNG sprites (`gfx/gfx_software_sprites.c`, vendored `gfx/stb_image.h`) replacing the old WASM sprite stubs; compositing order matches Raylib (base then z-sorted sprites). `web/canvas.html` draws `#OPTION border` padding from `Module.wasmGfxBorderPx` / `wasmGfxBorderColorIdx`. Guide: `docs/gfx-canvas-parity.md`. `tests/wasm_browser_canvas_test.py` covers bitmap + sprite smoke.
  - **Example**: `examples/gfx_canvas_demo.bas` + `gfx_canvas_demo.png` (and `web/gfx_canvas_demo.png` for Playwright fetch); canvas test runs the full demo source.
  - **Docs**: `docs/ide-retrogamecoders-canvas-integration.md` — embed canvas WASM in an online IDE (MEMFS, play/pause/stop, iframe flow); linked from `web/README.md`.

- **80-column option (terminal + basic-gfx + WASM canvas)**
  - **Terminal**: `#OPTION columns N` / `-columns N` (1–255); default 40. Comma/TAB zones scale: 10 at 40 cols, 20 at 80 cols. `#OPTION nowrap` / `-nowrap`: disable wrapping.
  - **basic-gfx**: `-columns 80` for 80×25 screen; 2000-byte buffer; window 640×200. `#OPTION columns 80` in program also supported.
  - **WASM canvas**: `#OPTION columns 80` selects 640×200 framebuffer in browser (`basic-wasm-canvas`).
- **basic-gfx — hires bitmap (Phase 3)**
  - `SCREEN 0` / `SCREEN 1` (text vs 320×200 monochrome); `PSET` / `PRESET` / `LINE x1,y1 TO x2,y2`; bitmap RAM at `GFX_BITMAP_BASE` (0x2000).
- **basic-gfx — PNG sprites**
  - `LOADSPRITE`, `UNLOADSPRITE`, `DRAWSPRITE` (persistent per-slot pose, z-order, optional source rect), `SPRITEVISIBLE`, `SPRITEW()` / `SPRITEH()`, `SPRITECOLLIDE(a,b)`; alpha blending over PETSCII/bitmap; `gfx_set_sprite_base_dir` from program path.
  - Examples: `examples/gfx_sprite_hud_demo.bas`, `examples/gfx_game_shell.bas` (+ `player.png`, `enemy.png`, `hud_panel.png`).

### 1.5.0 – 2026-03-20

- **String length limit**
  - `#OPTION maxstr N` / `-maxstr N` (1–4096); default 4096. Use `maxstr 255` for C64 compatibility.
- **String utilities**
  - `INSTR(source$, search$ [, start])` — optional 1-based start position.
  - `REPLACE(str$, find$, repl$)` — replace all occurrences.
  - `TRIM$(s$)`, `LTRIM$(s$)`, `RTRIM$(s$)` — strip whitespace.
  - `FIELD$(str$, delim$, n)` — extract Nth field from delimited string.
- **Array utilities**
  - `SORT arr [, mode]` — in-place sort (asc/desc, alpha/numeric).
  - `SPLIT str$, delim$ INTO arr$` / `JOIN arr$, delim$ INTO result$ [, count]`.
  - `INDEXOF(arr, value)` / `LASTINDEXOF(arr, value)` — 1-based index, 0 if not found.
- **RESTORE [line]** — reset DATA pointer to first DATA at or after the given line.
- **LOAD INTO** (basic-gfx) — `LOAD "path" INTO addr` or `LOAD @label INTO addr`; load raw bytes from file or DATA block.
- **MEMSET / MEMCPY** (basic-gfx) — fill or copy bytes in virtual memory.
- **ENV$(name$)** — environment variable lookup.
- **PLATFORM$()** — returns `"linux-terminal"`, `"windows-gfx"`, `"mac-terminal"`, etc.
- **JSON$(json$, path$)** — path-based extraction from JSON (e.g. `"users[0].name"`).
- **EVAL(expr$)** — evaluate a string as a BASIC expression at runtime.
- **DO … LOOP [UNTIL cond]** and **EXIT**
  - `DO` … `LOOP` — infinite loop (until `EXIT`).
  - `DO` … `LOOP UNTIL cond` — post-test loop.
  - `EXIT` — leaves the innermost DO loop. Nested DO/LOOP supported.
- **CI**
  - Skip pty GET test when `script -c` unavailable (macOS BSD).
  - Skip GET tests on Windows (console input only; piped stdin would hang).

### 1.4.0 – 2026-03-18

- **User-defined FUNCTIONS** (implemented)
  - Multi-line, multi-parameter: `FUNCTION name [(params)]` … `RETURN [expr]` … `END FUNCTION`.
  - Call from expressions: `x = add(3, 5)`; as statement for side effects: `sayhi()`.
  - Brackets always required; optional params; `RETURN` with no expr or `END FUNCTION` yields 0/`""`.
  - Coexists with `DEF FN` (different arity). See `docs/user-functions-plan.md`.
- **Graphical interpreter (basic-gfx)** — full raylib-based 40×25 PETSCII window
  - Complete graphical version of the interpreter: `basic-gfx` alongside terminal `basic`.
  - `POKE`/`PEEK` screen/colour/char RAM, `INKEY$`, `TI`/`TI$`, `.seq` art viewers.
  - PETSCII→screen code conversion when `SCREENCODES ON`; reverse-video fixed.
  - Window closes on `END`. Build with `make basic-gfx` (requires Raylib).
- **Meta directives** (`#` prefix, load-time)
  - Shebang: `#!/usr/bin/env basic` on first line ignored.
  - `#OPTION petscii|petscii-plain|charset upper|lower|palette ansi|c64` — file overrides CLI.
  - `#INCLUDE "path"` — splice file at that point; relative to current file; duplicate line numbers and labels error.
- **WHILE … WEND**
  - Pre-test loop: `WHILE cond` … `WEND`. Nested WHILE/WEND supported.
- **IF ELSE END IF**
  - Multi-line blocks: `IF cond THEN` … `ELSE` … `END IF`. Nested blocks supported.
  - Backward compatible: `IF X THEN 100` and `IF X THEN PRINT "Y"` unchanged.
- **Variable naming**
  - Full variable names (up to 31 chars) are now significant; `SALE` and `SAFE` are distinct.
  - Underscores (`_`) allowed in identifiers (e.g. `is_prime`, `my_var`).
  - Reserved-word check: keywords cannot be used as variables; clear error on misuse. Labels may match keywords (e.g. `CLR:`).
- **basic-gfx PETSCII / .seq viewer**
  - PETSCII→screen code conversion when `SCREENCODES ON`; `.seq` streams display correctly.
  - Reverse-video rendering fixed (W, P, etc. in “Welcome”, “Press”) via renderer fg/bg swap.
  - Window closes automatically when program reaches `END`.
  - `examples/gfx_colaburger_viewer.bas` with `-petscii -charset lower`.
- **GFX charset toggle**
  - `CHR$(14)` switches to lowercase, `CHR$(142)` switches back.
  - `-charset lower|upper` sets initial charset in `basic-gfx`.
- **Documentation**
  - Sprite features planning doc (`docs/sprite-features-plan.md`).
  - Meta directives plan (`docs/meta-directives-plan.md`) — shebang, #OPTION, #INCLUDE.
  - User-defined functions plan (`docs/user-functions-plan.md`).
  - Tutorial examples: `examples/tutorial_functions.bas`, `examples/tutorial_lib.bas`, `examples/tutorial_menu.bas` — FUNCTIONS, #INCLUDE, WHILE, IF ELSE END IF.
  - README, to-do, and `docs/bitmap-graphics-plan.md` updated for merged GFX.
  - Removed colaburger test PNG/MD artifacts.

### 1.0.0 – 2026-03-09

Baseline “version 1” tag capturing the current feature set.

- **Core interpreter**
  - CBM BASIC v2–style: `PRINT`, `INPUT`, `IF/THEN`, `FOR/NEXT`, `GOTO`, `GOSUB`, `DIM`, `DEF FN`, `READ`/`DATA` + `RESTORE`, `CLR`, multi-dimensional arrays, string functions (`MID$`, `LEFT$`, `RIGHT$`, `INSTR`, `UCASE$`, `LCASE$`), and numeric functions (`SIN`, `COS`, `TAN`, `RND`, etc.).
  - File I/O (`OPEN`, `PRINT#`, `INPUT#`, `GET#`, `CLOSE`, `ST`) and the built‑in examples (`trek.bas`, `adventure.bas`, `fileio_basics.bas`, etc.).
- **PETSCII and screen control**
  - `-petscii` and `-petscii-plain` modes with a faithful PETSCII→Unicode table (C64 graphics, card suits, £, ↑, ←, block elements) and ANSI control mapping (`CHR$(147)` clear screen, cursor movement, colours, reverse video).
  - PETSCII token expansion inside strings via `{TOKENS}` (colour names, control keys, numeric codes).
  - Column‑accurate PETSCII `.seq` viewer (`examples/colaburger_viewer.bas`) with proper wrapping at 40 visible columns and DEL (`CHR$(20)`) treated as a real backspace (cursor left + delete char).
- **Terminal/UI helpers**
  - `SLEEP` (60 Hz ticks), `LOCATE`, `TEXTAT`, `CURSOR ON/OFF`, `COLOR` / `COLOUR`, and `BACKGROUND` with a C64‑style palette mapped to ANSI.
- **Shell scripting support**
  - Command‑line arguments via `ARGC()` and `ARG$(n)` (`ARG$(0)` = script path; `ARG$(1)…ARG$(ARGC())` = arguments).
  - Standard I/O suitable for pipes and redirection: `INPUT` from stdin, `PRINT` to stdout, diagnostics to stderr.
  - Shell integration: `SYSTEM(cmd$)` runs a command and returns its exit status; `EXEC$(cmd$)` runs a command and returns its stdout as a string (trailing newline trimmed).
  - Example `examples/scripting.bas` showing argument handling and simple shell‑style tasks.

Future changes should be added above this entry with a new version and date.

