# WASM frame pacing — deferred

Status: **TODO, not blocking.** Browser builds run at the host monitor's
refresh rate via `requestAnimationFrame`; native locks to 60 Hz via
raylib's `SetTargetFPS(60)`. Game logic ticks once per frame, so a
120 Hz monitor runs RPG / shooter twice as fast. Fine for the MVPs;
revisit when the difference bothers a real user or we ship a game
that's timing-sensitive.

## Symptoms today

- Same `.bas` feels markedly snappier in `basic-gfx` (native, 60 Hz)
  than in `basic-wasm-raylib` (browser, RAF-bound).
- Tab in background → RAF throttled to 1 Hz → game crawls.
- 120 Hz / 144 Hz monitors → game runs ~2× / 2.4× speed.
- Heavy frames overshoot one VSYNC tick; light frames undershoot.
  Net drift between input and motion.

## Causes

1. **RAF binding.** `emscripten_set_main_loop` (and raylib's emscripten
   shim) drives the loop from `requestAnimationFrame`. RAF fires at
   the monitor's refresh rate, not 60 Hz.
2. **Asyncify cost.** Every `VSYNC` save/restores the BASIC stack via
   Asyncify so JS can yield. Adds a few ms per frame at our program
   sizes; not catastrophic but noticeable on slower devices.
3. **Interpreter overhead.** Each BASIC opcode dispatches through the
   interpreter loop; native + raylib batches to GPU faster than WASM
   per-statement work.

## Fix options (pick when revisiting)

### A. Fixed-step sim, render every RAF (recommended)

Run game logic at 60 sim ticks/sec independent of RAF rate:

```basic
SIM_DT_MS = 1000 \ 60
ACC_MS = 0
LAST_MS = TICKMS
DO
  NOW = TICKMS
  ACC_MS = ACC_MS + (NOW - LAST_MS)
  LAST_MS = NOW
  WHILE ACC_MS >= SIM_DT_MS
    Tick()                ' input + move + collide
    ACC_MS = ACC_MS - SIM_DT_MS
  WEND
  RenderFrame()
  VSYNC
LOOP
```

- Collision logic stays integer-step.
- 120 Hz browser still runs 60 sim/sec — game speed identical to
  native.
- Tab-unfreeze: clamp `ACC_MS` so we don't run 1000 ticks at once.

### B. Per-axis delta-time scaling

Multiply movement by ms-since-last-frame. Simpler, but variable step
risks AABB tunneling through walls if `dt > tile_size / speed`. Cap
step size to `MAP_TILE_W - 1`. Fractional accumulator needed for
sub-pixel speeds.

### C. Cap RAF to 60 Hz at the interpreter

`emscripten_set_main_loop_timing(EM_TIMING_SETTIMEOUT, 16)` instead
of RAF. Loses VSYNC alignment (visible tearing) and ignores the
host refresh; users on 60 Hz monitors gain nothing.

### D. Compile interpreter hotspot to WAT/intrinsics

Profile-guided. Tilemap composite, sprite cell sort, BASIC main
dispatch. Defer until profiling shows where time actually goes —
WebGL2 raylib's GPU path may already be the bottleneck-free part.

## Pre-work to consider

- Add `TIME$` / `TICKMS` examples to docs so users discover the
  primitive without reading basic.c.
- Wire a debug HUD overlay (already have OVERLAY plane) showing
  `fps = 1000 / DT_MS` and sim ticks per RAF — tells us where time
  goes without external tools.
- Audit Asyncify imports list to confirm only the real awaits are
  flagged. Each entry costs Asyncify save/restore.

## Why deferring is fine

MVP-1 (shooter) is auto-scroll, MVP-2 (RPG) is exploration — neither
exercises tight reaction timing. The map editor doesn't care. Real
users haven't complained yet. Pick this up when:

- A timing-sensitive game ships (rhythm, action platformer, parry
  combat).
- Telemetry shows users on 120 Hz / 144 Hz panels reporting
  "everything moves too fast".
- We add network multiplayer or replays where lockstep becomes
  load-bearing.
