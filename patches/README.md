# patches/

Unified-diff patches applied automatically by `scripts/build-raylib-web.sh`
against the third-party raylib source tree pinned by that script.

## Why patches live here

`third_party/` is `.gitignore`d. `scripts/build-raylib-web.sh` fetches
raylib fresh on demand and performs a clean `git checkout -f
tags/$RAYLIB_VERSION` whenever the tag mismatches. Any edit made
in-place under `third_party/raylib-src/` is therefore ephemeral. Fixes
we need to maintain ourselves must live here, under version control.

## How patches are applied

Step 2b of `build-raylib-web.sh` loops over `patches/*.patch` in
alphabetical order and runs:

```
git -C third_party/raylib-src apply <patch>
```

Idempotency is provided by `git apply --reverse --check` — an
already-applied patch is detected and skipped. A patch that no longer
applies (because `RAYLIB_VERSION` was bumped) fails the build with a
clear error rather than silently corrupting the tree.

## Current patches

### `jar_mod_max_samples.patch` (added 2026-04-20)

Chunked-decode patch for `jar_mod_max_samples`. Upstream simulates the
full song one stereo sample at a time to count frames; this patch
decodes 4096 samples per call, ~4000× fewer outer iterations. Still
useful for the **native** `basic-gfx` target and the canvas/terminal
WASM builds that don't link raylib audio — they still call
`jar_mod_max_samples` and benefit from the speedup.

Originally intended as the browser-freeze fix for `basic-wasm-raylib`,
but the chunking alone wasn't enough (see the **MOD load freeze fix**
entry in `CHANGELOG.md` for why — the per-sample inner loop is the
real cost). The actual browser fix is
`raudio_mod_skip_max_samples.patch` below.

Upstream status: not fixed in `jar_mod.h` as of raylib 5.5. Check
again when bumping `RAYLIB_VERSION` in `scripts/build-raylib-web.sh`.

### `raudio_mod_skip_max_samples.patch` (added 2026-04-20)

Actual browser-freeze fix. Patches `raylib/src/raudio.c`'s
`LoadMusicStream` MOD branch so that under `#ifdef __EMSCRIPTEN__` it
skips the `jar_mod_max_samples` call entirely and sets
`music.frameCount = 0xFFFFFFFFu`. Rationale: `UpdateMusicStream` only
uses `frameCount` to modulo `framesProcessed` and to decide end-of-
stream; with `UINT_MAX` the modulo never wraps, and looping MOD
playback works perfectly because jar_mod tracks its own `loopcount`
internally. See `CHANGELOG.md` **MOD load freeze fix (2026-04-20)**.

Behaviour tradeoff: non-looping MOD on the web plays through the final
pattern into silence rather than stopping precisely at the last frame.
Acceptable — the alternative was a hard browser freeze. Native builds
unaffected (the `#else` branch still uses the accurate count).

Upstream status: not fixed. The pattern applies to any Emscripten
build that needs to play MOD files through raylib's raudio.

## Adding a new patch

1. Edit the file in `third_party/raylib-src/` directly.
2. Run `git -C third_party/raylib-src diff > patches/my_fix.patch`.
3. Reset the tree (`git -C third_party/raylib-src checkout --`).
4. Run `scripts/build-raylib-web.sh` and confirm the patch re-applies
   cleanly and `make` still produces `libraylib.a`.
5. Add a section to this README describing the bug, the fix, and the
   upstream status.
6. Add a CHANGELOG.md entry describing what the patch fixes at the
   BASIC-program level (user-facing symptom + workaround if any).

## Removing a patch

Delete the patch file, delete its entry from this README, and update
CHANGELOG.md to note that upstream now carries the fix (or that the
behaviour has changed). Do NOT delete a patch just to silence a
rebase failure during a `RAYLIB_VERSION` bump — verify upstream first.
