This project is my (Chris Garrett) browser-based retro coding IDE and my basic interpreter rgc-basic for browsers/WASM, linux+mac+windows

/Users/chrisg/github/8bitworkshop -> https://github.com/omiq/8bitworkshop-rgc

/Users/chrisg/github/rgc-basic -> 
https://github.com/omiq/rgc-basic
 
8bitworkshop uses RGC-BASIC as a submodule

Please when giving me instructions give one action/bash command/etc step at a time

keep chat concise unless I ask to expand

## Third-party patches (IMPORTANT — read before touching raylib/wasm audio)

`third_party/` is gitignored. raylib is fetched fresh by
`scripts/build-raylib-web.sh`. Any fix we maintain against upstream
lives in `patches/*.patch` and is re-applied on every build by step 2b
of that script. `patches/README.md` explains the mechanism.

**Current active patches:**

- `patches/raudio_mod_skip_max_samples.patch` — the actual fix for
  LOADMUSIC browser freeze on `.mod` files in `basic-wasm-raylib`.
  Skips `jar_mod_max_samples` on Emscripten and hard-codes
  `frameCount = UINT_MAX`.
- `patches/jar_mod_max_samples.patch` — chunked-decode optimisation
  for the native + non-raylib WASM builds. Not load-bearing for the
  web freeze fix (see CHANGELOG.md **MOD load freeze fix (2026-04-20)**
  for why chunking alone wasn't enough).

**Rules for agents:**

1. Do NOT commit a modified file under `third_party/raylib-src/` to
   this repo. The tree is gitignored and gets clobbered on rebuild.
   Put the fix in `patches/` instead.
2. If `scripts/build-raylib-web.sh` fails at step 2b with "patch no
   longer applies", read the error, then rebase the patch against the
   current raylib tag. Do NOT delete the patch to make the build pass
   without first verifying upstream has merged an equivalent fix.
3. Same freeze pattern may exist in `jar_xm.h` (XM module format). If
   XM support is added later, test a long track on the web build
   before shipping.
4. `scripts/build-raylib-web.sh` auto-rebuilds `libraylib.a` when any
   `patches/*.patch` is newer (mtime check in step 2b). You do NOT
   need to pass `RAYLIB_FORCE=1` after editing a patch file.
5. `scripts/pullmake.sh` calls `build-raylib-web.sh` unconditionally
   before `make basic-wasm-raylib`. Fresh clones bootstrap raylib
   automatically; `./rebuild-run.sh` (which calls pullmake) picks up
   patch edits without extra flags.

## Debugging the browser WASM build

The terminal CLI (Claude Code running in Terminal) cannot see the
canvas or drive a running WASM program. Use Claude Desktop with the
Chrome extension instead when debugging anything that only manifests
in the browser (freezes, audio issues, render glitches, input
handling, GL errors). The Chrome extension can dispatch real user
gestures (needed for autoplay unlock), capture CDP timeouts when the
renderer hangs, and read console/network across iframes.

