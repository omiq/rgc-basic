# RGC-BASIC: sample sound playback (design spec)

**Status:** **shipped.** WAV single-voice (`LOADSOUND` / `PLAYSOUND` /
`STOPSOUND` / `UNLOADSOUND` / `SOUNDPLAYING()`) and tracker-module
streaming (`LOADMUSIC` / `PLAYMUSIC` / `STOPMUSIC` / `PAUSEMUSIC` /
`RESUMEMUSIC` / `MUSICVOLUME` / `MUSICLOOP` / `UNLOADMUSIC` /
`MUSICPLAYING` / `MUSICLENGTH` / `MUSICTIME` / `MUSICPEAK`) now live
in `gfx/gfx_sound.c` on **basic-gfx** and **basic-wasm-raylib**. Canvas
WASM is frozen and still raises a runtime error. The spec below is the
original MVP design; section 15 and the CHANGELOG cover what finally
shipped, including the Windows `jar_mod_max_samples` mitigation and
the MOD length parser we wrote to replace it.
**Scope:** **basic-gfx** (native + Raylib) and **canvas WASM** only. The terminal / non-`GFX_VIDEO` build is **out of scope** unless explicitly added later.

---

## 1. Goals

- Play **short samples** (SFX, short jingles) **without blocking** the interpreter: **`PLAYSOUND`** returns immediately while audio continues.
- **Single active voice** for the MVP: starting a new **`PLAYSOUND`** stops whatever was playing (unless documented otherwise).
- **Parity** between **basic-gfx** and **canvas WASM** for load/play/stop/pause and polling.
- **Familiar API** alongside existing **`LOADSPRITE`**: numbered **slots**, paths relative to the program file (and **VFS** on WASM), same mental model for authors.

## 2. Non-goals (MVP)

- **Terminal / CLI** audio (no dependency decision for Linux/macOS/Windows without a window).
- **Music streaming**, **sequencing**, or **MOD** files.
- **Simultaneous** overlapping samples (second voice, mixing) — deferred.
- **3D spatial audio**, **recording**, **MIDI**.

---

## 3. MVP — BASIC surface

### 3.1 Statements

| Statement | Behaviour |
|-----------|-----------|
| **`LOADSOUND slot, "path.wav"`** | Decode and keep PCM in **slot** (1-based or 0-based — match **`LOADSPRITE`** convention). Replace previous data in that slot. |
| **`UNLOADSOUND slot`** | Free sample in **slot**. |
| **`PLAYSOUND slot`** | If another sample was playing, **stop** it, then **play** this slot from the start. Non-blocking. |
| **`STOPSOUND`** | Stop the current playback and reset read position (no slot arg — single voice). |
| **`PAUSESOUND`** | Pause current playback. |
| **`RESUMESOUND`** | Resume after **`PAUSESOUND`**. |
| **`SOUNDVOL n`** | Master gain for the one voice: **`n`** in **0–100** or **0–255** (pick one and document; prefer **0–255** for consistency with **`SPRITEMODULATE`**). |

### 3.2 Functions

| Function | Returns |
|----------|---------|
| **`SOUNDPLAYING()`** | **1** if a sample is actively playing, **0** if idle or paused (define whether **paused** counts as playing — recommend **0** when paused). |

### 3.3 Optional one-liners (phase 1.1)

- **`PLAYSOUND slot, gain`** — same as **`PLAYSOUND`** + temporary gain for this cue (still one voice).
- **`SOUNDLOOP slot, on`** or **`PLAYSOUND slot` with loop flag** — loop until **`STOPSOUND`** (useful for title music).

### 3.4 Deferred (phase 2+)

- **Cue ranges** inside one file: **`PLAYSOUND slot, startMs, lengthMs`** (sprite-sheet style audio).
- **Playlist index** / **SKIP** — only if multiple cues in one asset; not needed for one-shot SFX.
- **Second voice** / mixing — requires a small mixer and more WASM/native code.

---

## 4. Behavioural rules

1. **Non-blocking:** decoding may happen asynchronously on WASM; **`PLAYSOUND`** must not **`SLEEP`** the program. If decode is not ready, either **queue** play until ready or return silently with a **status** (prefer **`SOUNDSTATUS()`** later; MVP can document “load before play”).
2. **Single voice:** **`PLAYSOUND`** implicitly **stops** the previous sound unless implementation offers an explicit **“mix”** mode later.
3. **Threading (native):** Raylib audio is typically driven from the **main thread** with the window. The interpreter runs in a **worker thread** (same as sprites). Use a **lock-free queue** or **command queue** processed each frame in the **render loop** (mirror **`gfx_sprite_process_queue`** pattern).
4. **Lifecycle:** **`UNLOADSOUND`** on a playing slot should **stop** playback first.

---

## 5. Native implementation notes (basic-gfx + Raylib)

- Prefer **Raylib** `Sound` / `LoadSound` / `PlaySound` / `StopSound` / `SetSoundVolume` if they fit **single-voice** and thread constraints.
- **Validate** Raylib docs for **which thread** may call **`UpdateSound`** / **`PlaySound`**. If only main thread: **enqueue** `{LOAD, PLAY, STOP, …}` from BASIC; **drain** in **`main()`** before **`EndDrawing`** (or audio update hook).
- **Formats:** **WAV (PCM)** first — simplest decode path; avoid **mp3** in MVP to limit dependencies.

---

## 6. WASM / browser implementation notes

- **Web Audio API:** create **`AudioContext`**, decode with **`decodeAudioData`**, schedule with **`AudioBufferSourceNode`** (or **worklet** later).
- **Autoplay policy:** browsers may **suspend** audio until a **user gesture**. Document that the embed should call **`AudioContext.resume()`** on first **click/tap** on the canvas (same panel as “click to run” if applicable).
- **Files:** reuse **`Module.FS`** / **`WORKING_DIRECTORY`** patterns from **`LOADSPRITE`**; paths relative to uploaded `.bas` or **`fetch`** from same origin.
- **Async:** decoding must not block **Asyncify** indefinitely; use **existing** async patterns if decode runs in JS and resumes WASM.

---

## 7. Errors

- Missing file / bad format: **runtime error** with **`Hint:`** (match existing style).
- **`PLAYSOUND`** on empty slot: runtime error or silent no-op — **recommend runtime error** for teachability.

---

## 8. Testing

- **Headless CI:** optional **native** unit test that only **loads** a tiny embedded WAV byte array (no speaker).
- **WASM:** **Playwright** smoke: load program with **`LOADSOUND`/`PLAYSOUND`**, assert no throw; **optional** **Web Audio** mock if feasible.
- **Manual:** **basic-gfx** on desktop with speakers/headphones.

---

## 9. Difficulty estimate

| Layer | Effort |
|--------|--------|
| **C API + queue + Raylib** (single voice, WAV) | **Moderate** (main wrinkle: **thread** boundary). |
| **WASM + Web Audio + VFS** | **Moderate–high** (browser policies + async). |
| **BASIC parser + docs + one example** | **Low–moderate**. |
| **Second voice / mixing / streaming** | **High** (later). |

Overall MVP (gfx + WASM, one voice, WAV, commands above): **moderate to moderate–high** end-to-end.

---

## 10. Related

- Sprite queue / main-thread GPU work: **`gfx_raylib.c`**, **`gfx_software_sprites.c`** (pattern for **enqueue** + **drain**).
- **`docs/browser-wasm-plan.md`**, **`web/README.md`** — embedding and VFS.
