## Changelog

### Unreleased

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

