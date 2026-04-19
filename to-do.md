# Features to add/to-do

## Future: textured polygons

`TEXTUREPOLY slot, n, vx(), vy(), ux(), uy()` — draw a polygon with a
sheet-slot texture mapped across its surface. Per-vertex UV coordinates
(0..1 or 0..sheet_w / 0..sheet_h, TBD) drive a scanline fill that
samples the source texture instead of using a flat pen. Convex case
only for v1 (fan-triangulate, per-triangle affine UV interpolation);
concave + perspective-correct mapping deferred.

Useful for:
- Rotated/sheared sprite blits without pre-rendered frame sheets
- Pseudo-3D floor/ceiling mode-7 style effects
- Heightmap terrain triangles
- Stretched health-bar / progress-bar fills using a single texture

Constraints worth thinking through:
- 1bpp blitter surfaces only carry on/off — textured poly probably
  wants RGBA source too (ties into Blitter Phase 2).
- Per-pixel UV interpolation is much heavier than flat fill; document
  vertex-count / pixel-count budget.
- Raylib path can use `rlPushMatrix` + `DrawTexturePoly` for the fast
  case; canvas/WASM software path needs a full scanline rasteriser.

Reference precedent: AMOS `Polyline` + `Polygon` with pattern brushes;
QuickBASIC `PAINT` with tile brush; modern raylib `DrawTexturePoly`.

## Naming convention for new commands

**Two-word verb/noun style for new graphics commands** (AMOS/STOS precedent):

- `SPRITE LOAD`, `SPRITE DRAW`, `SPRITE FRAME`, `SPRITE FREE`, `SPRITE FRAMES(...)`
- `TILE DRAW`, `TILE COUNT(...)`
- `TILEMAP DRAW`
- `SHEET COLS(...)`, `SHEET ROWS(...)`, `SHEET WIDTH(...)`, `SHEET HEIGHT(...)`
- `IMAGE NEW`, `IMAGE FREE`, `IMAGE COPY`, `IMAGE GRAB`, `IMAGE SAVE`
  (shipped). `IMAGE GRAB` from the visible framebuffer captures the
  fully-composited frame as RGBA — bitmap + text + sprites + tilemap
  cells, full palette and alpha. Desktop basic-gfx reads back the
  raylib RenderTexture on the render thread (interpreter cond_waits).
  Canvas WASM composites CPU-side via `gfx_canvas_render_full_frame`.
  WASM-raylib does an inline `LoadImageFromTexture` on `g_wasm_target`
  — no cond_wait (asyncify is single-threaded, cond_wait would deadlock).
  `IMAGE SAVE` auto-routes on extension: `.png` = 32-bit RGBA (prefers
  the RGBA buffer from GRAB if present; otherwise slot 0 resolves via
  current `COLOR`/`BACKGROUND`, slots 1..31 become a transparent-off
  mask); anything else = 24-bit BMP (RGBA slots are alpha-premultiplied
  on write since BMP has no alpha channel).
- `FILEEXISTS(path$)` intrinsic (shipped): 1 if the path is openable
  for reading, 0 otherwise. Works against MEMFS in browser WASM and the
  host filesystem natively — idiomatic post-save verification:
  `IMAGE SAVE 1, P$ : IF FILEEXISTS(P$) THEN PRINT "SAVED"; DOWNLOAD P$`.
- `DOWNLOAD path$` statement (shipped): in browser WASM, reads MEMFS
  and triggers an `<a download>` click with a guessed MIME type so the
  file actually lands on the user's disk. On native builds it's a
  no-op (prints a one-shot hint on stderr) — real files are already
  on the host filesystem.

## Directory listing (proposed, 2026-04-19)

Companion to `FILEEXISTS` / `IMAGE SAVE` / `DOWNLOAD`. Programs need to
enumerate the current working directory (or an arbitrary path) to:

- present a file-picker UI inside a BASIC program
- iterate saved screenshots for a slideshow / upload loop
- auto-discover level packs, sound samples, tutorial chapters
- build a viewer that lists PNGs in MEMFS so the IDE's "click thumbnail"
  path has something to show even if the sidebar and MEMFS drift.

### Options

| Shape | Call | Pro | Con |
|-------|------|-----|-----|
| **A. String returned** | `DIR$(path$ [, delim$])` returns `"a.bas|b.bas|c.png"` | Tiny API. Reuses `SPLIT … INTO arr$` for indexed access. One intrinsic. | Length-capped by `MAXSTR` (default 4096). A bigger `MEMFS` / `examples/` blows the limit. Delimiter collides with filenames if not chosen carefully. |
| **B. Into array** | `DIR path$ INTO arr$ [, count]` like `SPLIT` | No string-size ceiling — array grows as needed (or caller pre-DIMs). Clean for iteration: `FOR I = 0 TO count - 1 : PRINT arr$(I) : NEXT I`. | New statement keyword. Two-signature form (count optional). |
| **C. JSON returned** | `DIR$(path$)` returns `["a.bas","b.bas"]` | Self-describes; user indexes with `JSON$(DIR$(p$), "[0]")`. Extensible: later add `[{"name":"a.bas","size":123,"dir":0}]`. | Overkill for a pure-filename listing. Still bounded by `MAXSTR`. |
| **D. `READ`-like iterator** | `DIR OPEN path$` then `DIR NEXT name$` until empty, `DIR CLOSE` | Streams — zero ceiling, minimal memory. | Three statements instead of one; stateful interpretation (easy to leak the handle). |

### Recommendation

Ship **A + B together**:

```basic
REM quick: comma-string + SPLIT
F$ = DIR$(".", ",")
SPLIT F$, "," INTO NAMES$

REM ergonomic: direct-into-array
DIR "/tmp" INTO FILES$, N
FOR I = 0 TO N - 1
  PRINT I; ": "; FILES$(I)
NEXT I
```

- `DIR$(path$)` (no delim) defaults to newline-separated so it survives
  filenames that contain commas.
- Entries are **names only**, no path prefix, no `.`/`..`.
- Hidden files (leading `.`) are excluded by default; add a second
  arg `DIR$(path, delim$, include_hidden)` if/when needed.
- `DIR … INTO arr$ [, count]` mirrors `SPLIT … INTO arr$ [, count]`
  so the `count` output var is familiar.
- Backed by `opendir` / `readdir` natively; MEMFS via `FS.readdir`
  in `EM_JS` on browser WASM (same pattern as `rgc_wasm_trigger_download`).

### Deferred

- File metadata (size, mtime, is-dir): later `FILESIZE(path$)`,
  `FILEMTIME(path$)`, `ISDIR(path$)` intrinsics — or the JSON form
  above if we want one call to carry everything.
- Glob patterns (`DIR$("*.png")`): keep the API path-based; user can
  filter in BASIC with `INSTR` / `RIGHT$`.
- Recursive walk: out of scope for v1.

## Working directory (proposed, 2026-04-19)

Needed alongside `DIR$` so programs can anchor paths relative to a
chosen root and walk between them (e.g. switch between `/assets`,
`/tmp`, a user's project folder). Two primitives:

- **`CWD$()`** — returns the current working directory as a string.
  Native: `getcwd`. Browser WASM: emscripten tracks cwd per module;
  fall through to `FS.cwd()` via `EM_JS`.
- **`CHDIR path$`** — change the cwd. Native: `chdir` (returns error
  on missing path; raise `runtime_error_hint`). WASM: `FS.chdir(p)`
  in `EM_JS`.

Idiomatic use:

```basic
OLD$ = CWD$()
CHDIR "/tmp"
IMAGE SAVE 1, "shot.png"      : REM writes /tmp/shot.png
CHDIR OLD$                    : REM restore
```

**Deferred**: `MKDIR path$`, `RMDIR path$`, `DELETE path$`, `RENAME
old$ TO new$`. Not needed for the current screenshot / tutorial
workflow but a natural follow-up to `DIR$` + `CWD$`.

## JSON by index + length (proposed, 2026-04-19)

`JSON$(json$, path$)` already handles array indices inside a path
(`"items[0].name"`, `"[2]"`), but it can't answer "how many entries"
or "give me the Nth key of this object without knowing its name".
Two new intrinsics cover iteration:

- **`JSONLEN(json$, path$)`** — number of entries at `path$` if it
  resolves to an array or object; `0` for scalars / missing paths.
  Pairs with a `FOR I = 0 TO JSONLEN(j$, "items") - 1` loop.
- **`JSONKEY$(json$, path$, n)`** — 0-based Nth key at `path$` when
  it resolves to an object; `""` for arrays or scalars. Lets a
  program enumerate a record without hard-coding field names.

Index form of the existing getter is already covered:
`JSON$(j$, "items[" + STR$(I) + "]")` works today; the new length and
key-by-index helpers complete the iteration story.

Example — iterate an array of records:

```basic
J$ = HTTP$("https://api.example.com/users")
N = JSONLEN(J$, "users")
FOR I = 0 TO N - 1
  P$ = "users[" + STR$(I) + "]"
  PRINT JSON$(J$, P$ + ".name"); " "; JSON$(J$, P$ + ".age")
NEXT I
```

Example — iterate keys of an unknown-shape object:

```basic
N = JSONLEN(J$, "config")
FOR I = 0 TO N - 1
  K$ = JSONKEY$(J$, "config", I)
  V$ = JSON$(J$, "config." + K$)
  PRINT K$; " = "; V$
NEXT I
```

**Deferred**: `JSONTYPE$(json$, path$)` returning `"string"` / `"num"` /
`"bool"` / `"array"` / `"object"` / `"null"`. Only worth adding when a
real example needs to branch on type; for now `VAL()` + string prefix
checks are enough.

## JSON payloads larger than `MAXSTR` (2026-04-19)

`JSON$` input and output are both `struct value` strings — hard-capped
at `MAX_STR_LEN` = 4096 bytes (the `#OPTION maxstr N` knob only reduces
this; `basic.c:2476` rejects anything above 4096). Any JSON body above
~4 KB gets silently truncated on the way in, breaking the parse.

Impact hits the common case: `HTTP$` → `JSON$` for real-world APIs
regularly exceeds 4 KB; `HTTPFETCH` streams bigger payloads to MEMFS,
but no current intrinsic reads JSON from a file path.

### Options

| Shape | Notes |
|-------|-------|
| **A. `JSONLOAD slot, path$`** — parse a JSON file on disk into a buffer slot, then `JSON$(BUFFERPATH$(slot), "path")` via a re-entrant form that reads from the buffer. | Reuses the buffer mechanism already built for binary data. Needs a `JSON$(slot_or_string, path)` overload that detects a slot number vs. inline string. |
| **B. New intrinsic `JSONFILE$(path$, path_expr$)`** — like `JSON$` but the first arg is a filesystem path, streamed in chunks by the parser so only the extracted value has to fit in `MAX_STR_LEN`. | Cleanest call site. Parser needs to handle streaming (fgetc-driven) which is more work than the in-memory path. |
| **C. Bump `MAX_STR_LEN` to e.g. 65536 globally** | Trivial to implement. Memory cost per `struct value` is real — `value`s live on C stack in eval paths, 64 KB stack frames are a risk under recursion. Would need moving `.str` to heap with a length field. |

### Recommendation

Ship **B** (`JSONFILE$`) as the new entrypoint; keep `JSON$` semantics
unchanged. Internally the existing `json_parse_value` already walks a
`const char **` — swap to a file-buffered iterator that reads a small
window at a time. Only the final extracted leaf has to fit in 4 KB,
which matches most real-world "get me this one field" flows.

Pair it with `HTTPFETCH` cleanly:

```basic
HTTPFETCH 1, "https://api.example.com/huge-response", "/tmp/resp.json"
PRINT JSONFILE$("/tmp/resp.json", "users[0].name")
```

**Deferred** (tied to the JSON iteration task above): `JSONLEN` and
`JSONKEY$` should grow file-backed variants (`JSONFILELEN`, etc.) at
the same time so the iteration pattern works on big files too.

## DateTime primitives (proposed, 2026-04-19)

Today: `TI` / `TI$` give a 60 Hz jiffy counter and an `HHMMSS` wall-
clock string. Nothing handles dates or timezones. Programs that fetch
real time via `HTTP$` (see `examples/http_time_london.bas`) can parse
the response but can't push it back into the interpreter as a
persistent "current datetime" — every `TI$` read still comes from the
local wall clock.

Goal: one canonical datetime register that programs can read, format,
set from HTTP, and use as the basis for world-clock / countdown /
scheduling demos.

### Model

Store one **internal epoch** (64-bit seconds since 1970-01-01 UTC)
plus a **timezone offset in minutes** from UTC. Both settable. `TI`
stays as-is (jiffy counter); the new register is independent.

```c
static int64_t g_datetime_epoch_s = 0;   /* UTC seconds */
static int32_t g_datetime_tz_min  = 0;   /* minutes east of UTC */
```

On interpreter init: seed `g_datetime_epoch_s` from `time(NULL)` and
`g_datetime_tz_min` from `localtime`'s `tm_gmtoff`. Browser WASM does
the same via `Date.now()` + `getTimezoneOffset()` in an `EM_JS`.

### Intrinsics

| Call | Returns | Notes |
|------|---------|-------|
| **`NOW()`** | epoch seconds (number) | Current epoch after any `DATETIME SET` override. |
| **`DATE$()`** | `"YYYY-MM-DD"` | In current TZ. |
| **`TIME$()`** | `"HH:MM:SS"` | In current TZ. Named so it does NOT collide with `TI$` (jiffy-derived). |
| **`DATETIME$()`** | `"YYYY-MM-DD HH:MM:SS"` | ISO-like, no `T`, current TZ. |
| **`DATETIMEUTC$()`** | `"YYYY-MM-DDTHH:MM:SSZ"` | Canonical ISO-8601 UTC. |
| **`DAY()`** / **`MONTH()`** / **`YEAR()`** | number | Components in current TZ. |
| **`HOUR()`** / **`MINUTE()`** / **`SECOND()`** | number | Components in current TZ. |
| **`DAYOFWEEK()`** | 0 = Sunday … 6 = Saturday | In current TZ. |
| **`FORMATDATE$(fmt$)`** | formatted string | strftime-style tokens: `%Y %m %d %H %M %S %A %a %B %b %Z`, plus literal text. |
| **`PARSEDATE(s$)`** | epoch seconds | Accept `"YYYY-MM-DD HH:MM:SS"`, `"YYYY-MM-DDTHH:MM:SSZ"`, and a short `"HH:MM"` fallback. `0` on parse failure. |

### Statements

| Statement | Effect |
|-----------|--------|
| **`DATETIME SET epoch`** | Override `g_datetime_epoch_s` — `NOW() / DATE$ / TIME$` read from this value plus elapsed monotonic time since the set. |
| **`DATETIME SET s$`** | Convenience: same as `DATETIME SET PARSEDATE(s$)`. |
| **`DATETIME TZ minutes`** | Set timezone offset in minutes east of UTC (e.g. `0` UTC, `60` CET, `-300` EST). Affects every component accessor. |
| **`DATETIME RESET`** | Restore epoch + TZ to host defaults (re-read host clock). |

### Drift model

After `DATETIME SET`, we want subsequent reads to advance in real time
— we're not freezing the clock, just offsetting it. Track:

```c
static double g_datetime_set_monotonic_s = 0.0;  /* host time at SET */
static int    g_datetime_is_overridden   = 0;
```

Each `NOW()` returns `g_datetime_epoch_s + (host_now - g_datetime_set_monotonic_s)`
when overridden, else host epoch.

### Example: `examples/world_clock.bas`

```basic
' Sync to authoritative source
J$ = HTTP$("http://worldtimeapi.org/api/timezone/Europe/London")
EPOCH = VAL(JSON$(J$, "unixtime"))
OFFSET_MIN = VAL(JSON$(J$, "raw_offset")) / 60
DATETIME SET EPOCH
DATETIME TZ OFFSET_MIN

' World-clock UI, one row per zone
DIM ZONES$(5)
DIM OFFSETS(5)
ZONES$(0) = "UTC"      : OFFSETS(0) = 0
ZONES$(1) = "London"   : OFFSETS(1) = OFFSET_MIN
ZONES$(2) = "New York" : OFFSETS(2) = -240       ' DST
ZONES$(3) = "Tokyo"    : OFFSETS(3) = 540
ZONES$(4) = "Sydney"   : OFFSETS(4) = 600
ZONES$(5) = "Auckland" : OFFSETS(5) = 780

DO
  CLS
  FOR I = 0 TO 5
    DATETIME TZ OFFSETS(I)
    LOCATE 0, I * 2
    PRINT ZONES$(I); ": "; DATETIME$()
  NEXT I
  VSYNC
LOOP
```

### Deferred

- **Durations / arithmetic:** `ADDSECONDS(epoch, n)`, `ADDDAYS(...)`,
  `DIFFSECONDS(a, b)`. Implementable in BASIC on top of `NOW()` but
  intrinsics would read better.
- **Locale-aware month / weekday names:** English-only for v1.
- **`TIMER` integration:** currently interval-based; a `TIMER AT
  epoch, FnName` form would fire once at a specific datetime —
  useful for alarms / schedulers.
- **Calendar helpers:** `DAYSINMONTH`, `ISLEAPYEAR`, etc. — cheap
  to add once the component accessors ship.

## FOREACH loop (proposed, 2026-04-19)

Iterate an array element-by-element without an explicit index:

```basic
FOREACH V IN ARR()
  PRINT V
NEXT V

FOREACH S$ IN NAMES$()
  PRINT S$
NEXT S$
```

### Implementation sketch

- Single keyword `FOREACH` (not two-word `FOR EACH`) to sidestep the
  normaliser's `FOR`-follows-letter splitter.
- Reuse the existing `for_stack`:
  ```c
  enum for_kind { FOR_COUNT, FOR_EACH };
  struct for_frame {
      enum for_kind kind;
      char var[VAR_NAME_MAX];
      /* COUNT fields (stop, step) OR EACH fields (array_ref, idx, bound) */
  };
  ```
- `statement_foreach` parses `var IN arrname()`, resolves the array via
  `get_var_reference`, reads `dim_sizes[0] + 1` as the upper bound
  (rgc-basic is 0-based with inclusive upper, so `DIM A(10)` gives 11
  slots), seeds idx = 0, assigns `arr(0)` into `var`.
- `NEXT var`: look up frame by name; if `FOR_EACH`, increment idx; if
  `idx > bound` pop + fall through; else assign `arr(idx)` into var
  and jump back to the body.
- `EXIT` path: same as `EXIT FOR` — pop the innermost frame regardless
  of kind.

### Edge cases

- **Empty array** (`DIM A(-1)` or not yet DIM'd): run zero iterations
  (bound < 0 → immediate pop).
- **Multi-dim array**: raise "FOREACH requires a 1-D array" in v1.
  Two-word `FOREACH V IN ARR(ROW)` to walk a single row is a possible
  v2 extension.
- **Mutation during iteration**: document as undefined; matches FOR.
- **Label-only block with no NEXT**: existing FOR "unclosed loop"
  diagnostic catches this.

### Normaliser guard

Add one condition to the existing `FORI=1TO9 -> FOR I=1TO9` splitter
in `normalize_keywords_line`: don't split if the 4th character is
another letter, so `FOREACH` stays intact. One-line diff.

### Reserved-word table

Append `FOREACH` to `reserved_words[]` in `basic.c`. Programs using
`FOREACH` as a variable name break at load — low likelihood.

### Tests

- `tests/foreach_numeric.bas`
- `tests/foreach_string.bas`
- `tests/foreach_empty.bas`
- `tests/foreach_nested.bas`
- `tests/foreach_multidim_error.bas` (expects runtime error)

## Performance measurement primitives (proposed, 2026-04-19)

Context: user wants to prototype new intrinsics as BASIC library functions
first, then measure to decide whether the performance win justifies
promoting them to C. Today:

- **`TI`** — 60 Hz jiffy counter. 16.67 ms granularity. Useless for
  tight loops where a whole function might take <1 ms.
- **`EXEC$("date +%s%N")`** — works on desktop Linux but not macOS or
  WASM. Not portable.

### Primitive

- **`TICKUS()`** — monotonic microseconds since program start (or
  host epoch start; unspecified origin, but differences are meaningful).
  Returns a 64-bit float (holds ~285 years of µs without precision
  loss in the mantissa).
  - Native: `clock_gettime(CLOCK_MONOTONIC, ...)` → µs.
  - Browser WASM: `performance.now()` × 1000 via `EM_JS`.
- **`TICKMS()`** — same but milliseconds, for larger spans where µs is
  noise.

### Idiom

```basic
FUNCTION FastHypot(x, y)
  RETURN SQR(x * x + y * y)
END FUNCTION

N = 100000
T0 = TICKUS()
FOR I = 1 TO N
  D = FastHypot(I, I * 2)
NEXT I
ELAPSED = TICKUS() - T0
PRINT N; " calls in "; ELAPSED; " us  ("; ELAPSED / N; " us/call)"
```

Same pattern runs against a C-implemented `HYPOT(x, y)` intrinsic to
compare. If BASIC-version overhead is dominated by FOR loop dispatch
rather than the function body, promotion to C probably won't help.
If the body itself is the cost centre, promote.

### Decision heuristics (to add to docs)

- **<100 ns/call in C vs >10 µs in BASIC:** clear promotion candidate.
- **Pure arithmetic on existing intrinsics:** stay in BASIC — user can
  always read the source and verify.
- **Called in tight per-frame loops (60 Hz × N objects):** promote if
  the BASIC cost × N exceeds a frame budget at the expected N.
- **String-manipulation helpers:** watch `MAX_STR_LEN` — C intrinsics
  can stream through larger buffers, BASIC is capped at 4096.

### Optional: block-timer statement

Further sugar if plain `TICKUS()` bookkeeping gets verbose:

```basic
BENCHMARK "hypot BASIC" 100000
  D = FastHypot(I, I * 2)
END BENCHMARK
```

Prints `hypot BASIC: 1234567 us (12.3 us/call)` automatically. Can
wait until we actually need it — plain `TICKUS()` diffs cover the
common case with three lines of BASIC.

### Related to-do

- **Per-statement profiler:** count dispatches per statement type
  across a program run. Expose via `PROFILE START` / `PROFILE DUMP`.
  Heavier work (per-statement bookkeeping in `execute_statement`);
  log but don't ship until a concrete use case appears.

## Dictionary intrinsics — Tier 2 record storage (proposed, 2026-04-19)

Unlock hash tables, config blobs, linked lists, small databases
without committing to full `TYPE`/`END TYPE` struct grammar. Slot-based
API mirrors the existing sprite / image / buffer conventions.

### Capacity — no 256-entry cap

- **Slots:** 64 concurrent dicts (namespace, not capacity).
- **Keys per slot:** **unbounded in practice** — backed by a
  heap-grown chained hash map. Grows until the process runs out of
  memory. Browser WASM already has `-s ALLOW_MEMORY_GROWTH=1`
  (`Makefile:122`), so the linear heap expands to browser limits
  (modern Chrome/Firefox: ~2 GB per tab). Target ≥1M entries at small
  key/value sizes.
- **Value per entry (normal API):** up to `MAX_STR_LEN` (4096 default;
  `#OPTION maxstr` only reduces this — deliberate).
- **Value per entry (buffer-backed API):** up to the size of the
  referenced BUFFER slot — lets you stash HTTP payloads, images, big
  JSON blobs keyed against a short string without the 4 KB ceiling.
- **Key length:** up to `MAX_STR_LEN` when set from BASIC.

### Statements

| Statement | Effect |
|-----------|--------|
| **`DICT NEW slot`** | Allocate an empty dict in `slot` (0..63). Replaces any existing dict in the same slot. |
| **`DICT FREE slot`** | Release all entries + free the slot. |
| **`DICT SET slot, key$, value$`** | Insert or replace the string value at `key`. Overwrites silently. |
| **`DICT SETBUFFER slot, key$, buffer_slot`** | Insert/replace a buffer-backed value — the dict stores a reference to the BUFFER slot. |
| **`DICT DELETE slot, key$`** | Remove the entry for `key` if present. No-op if missing. |
| **`DICT CLEAR slot`** | Remove every entry but keep the slot allocated. |
| **`DICT SAVE slot, "path"`** | Serialize slot to disk as JSON (`{"key":"value",...}`). Buffer-backed values write their bytes inline (base64 optional, decide in impl). |
| **`DICT LOAD slot, "path"`** | Replace slot contents by parsing a JSON object from `path`. |
| **`DICT ITER slot`** | Rewind an iterator cursor on the slot. |

### Functions

| Function | Returns | Notes |
|----------|---------|-------|
| **`DICT$(slot, key$)`** | string | Value at `key`, or `""` if missing. String-typed API (`VAL` to numeric as needed). |
| **`DICTGETBUFFER(slot, key$)`** | number | BUFFER slot number referenced by `key`, or `-1` if not buffer-backed / missing. |
| **`DICTHAS(slot, key$)`** | number | `1` if the key exists, `0` otherwise. Distinguishes "missing" from "set to empty string". |
| **`DICTLEN(slot)`** | number | Current entry count. |
| **`DICT NEXT(slot, keyvar$, valvar$)`** | number | Iterator step. Advances the cursor set by `DICT ITER`, writes the next key/value into the supplied string vars, returns `1` if an entry was written, `0` when exhausted. O(1) memory — no snapshot. |

### Iteration patterns

Single-entry iterator (large-dict safe):

```basic
DICT ITER 1
DO WHILE DICT NEXT(1, K$, V$)
  PRINT K$; " = "; V$
LOOP
```

Key-array snapshot (when you need random access by index; costs
O(N) memory for the key list):

```basic
' Available once FOREACH + DICTKEYS$ land
FOREACH K$ IN DICTKEYS$(1)
  PRINT K$; " = "; DICT$(1, K$)
NEXT K$
```

The snapshot path is optional extra API; the single-entry iterator
is mandatory and the scaling-safe default.

### Linked list via chained slots

Pattern for user-built linked lists (no native list type needed):

```basic
' Each node lives in its own dict slot. "next" holds the slot
' number of the following node, or -1 at the tail.
FUNCTION NewNode(value$)
  SLOT = FindFreeSlot()              ' scan DICTLEN(s) style
  DICT NEW SLOT
  DICT SET SLOT, "value", value$
  DICT SET SLOT, "next",  "-1"
  RETURN SLOT
END FUNCTION
```

Fragile (relies on user-level slot bookkeeping) but workable for
tutorial-grade linked lists. A future Tier 3 `TYPE` with pointer-
style references would make this cleaner — revisit if demand shows up.

### Implementation sketch

- `GfxDictSlot`:
  ```c
  typedef struct DictEntry {
      char *key;                  /* heap; free on delete */
      char *value;                /* heap; NULL if buffer-backed */
      int   buffer_slot;          /* -1 unless buffer-backed */
      struct DictEntry *next;     /* bucket chain */
  } DictEntry;

  typedef struct {
      int loaded;
      size_t nbuckets;            /* grow by 2x when load factor > 0.75 */
      size_t nentries;
      DictEntry **buckets;
      /* iterator cursor */
      size_t it_bucket;
      DictEntry *it_node;
  } GfxDictSlot;
  ```
- Hash: FNV-1a on key bytes (simple, fast, good enough for our scale).
- Grow: resize-in-place at load factor 0.75, rehash all.
- File format for `DICT SAVE`: JSON object, one key per line for
  diff-friendliness; values are quoted strings, buffer-backed entries
  emit a conventional wrapper like `{"$buf": <length>, "$data": "..."}`.
- New file: `gfx/rgc_dict.c` + `.h`. Does NOT depend on GFX — linked
  into terminal `basic` too so dicts work everywhere.

### Tests

- `tests/dict_basic.bas` — NEW / SET / GET / DELETE / HAS / LEN
- `tests/dict_iter.bas` — ITER + NEXT across an empty, 1-entry, and
  10k-entry dict (timed via `TICKUS()` once that lands)
- `tests/dict_collision.bas` — force many keys to same bucket
- `tests/dict_saveload.bas` — round-trip via DICT SAVE / DICT LOAD
- `tests/dict_buffer.bas` — SETBUFFER + GETBUFFER with a real buffer

### Dicts ARE pseudo-structs (why Tier 3 is deferred)

rgc-basic has no strict typing — `VAL` / `STR$` bridge numeric and
string freely — and `SPLIT` already converts delimited strings into
arrays. Stack that with Tier 2 dicts and the "struct" shape falls out
naturally:

**A single instance** — dict-as-record:

```basic
DICT NEW 1
DICT SET 1, "name", "Alice"
DICT SET 1, "hp",   "100"
DICT SET 1, "x",    "50"
DICT SET 1, "y",    "50"

' Read back — dict values are strings, VAL() for numerics.
HP = VAL(DICT$(1, "hp"))
```

**An array of records** — compound keys in one slot, or a slot per
instance:

```basic
' Compound keys ("<index>.<field>") in slot 1 = single-dict form.
' Works cleanly with FOREACH over a fixed index range.
DICT NEW 1
FOR I = 0 TO N - 1
  DICT SET 1, STR$(I) + ".name", "Player " + STR$(I)
  DICT SET 1, STR$(I) + ".hp",   "100"
NEXT I

' Or: slot-per-instance, links via "next" key = linked list / tree.
' See the NewNode() sketch above.
```

**Packed record via `SPLIT`** — saves N `DICT SET` calls if you
already have a CSV-shaped string:

```basic
DICT SET 1, "player0", "Alice,100,50,50"
SPLIT DICT$(1, "player0"), "," INTO F$
PRINT F$(0); " HP="; VAL(F$(1))
```

The three patterns cover field access, arrays-of-records, and
serialisation without adding grammar. Tier 3 (`TYPE` / dotted fields /
by-ref args) remains worth it only when a concrete example shows the
dict/SPLIT idiom becomes materially harder to read or too slow in a
per-frame loop. Until then, Tier 2 plus the existing SPLIT/JOIN +
VAL/STR$ bridge IS the struct system.

### Deferred (Tier 3 trigger)

If any of these actually come up:

- **Dotted-field syntax** (`p.hp`, `p.name$`) — the moment readable
  code demands it.
- **By-ref FUNCTION arguments** — needed for non-trivial mutation
  patterns inside helpers.
- **Arrays of records** (`DIM party(10) AS Player`) — when iteration
  over N homogeneous records of M fields becomes too awkward with
  parallel arrays or compound-keyed dicts.

Revisit full `TYPE` / `END TYPE` at that point. Until then, Tier 2
dicts + existing parallel arrays cover the space.

Dropped from the original proposal:
- ~~`SCREEN OFFSET`, `SCREEN ZONE`, `SCREEN SCROLL`~~ — `IMAGE COPY`
  already covers scrolling and parallax; see
  `docs/tilemap-sheet-plan.md` "Scrolling — covered by IMAGE COPY".

**Existing concat names stay as permanent aliases** — not deprecated,
no warnings, no removal date:

| New (canonical) | Concat alias (permanent) |
|---|---|
| `SPRITE LOAD` | `LOADSPRITE` |
| `SPRITE DRAW` | `DRAWSPRITE` |
| `SPRITE FRAME` | `SPRITEFRAME` |
| `SPRITE FREE` | `FREESPRITE` |
| `TILE DRAW` | `DRAWTILE` / `DRAWSPRITETILE` |
| `TILE COUNT(...)` | `SPRITETILES(...)` |
| `TILEMAP DRAW` | `DRAWTILEMAP` |

Both spellings tokenise to the same opcode. Pick per taste; docs lead
with two-word form for new material. Applies to **new** commands only;
don't retroactively rewrite working code.

Rationale: two-word grammar groups features visually (`SPRITE *`,
`TILE *`, `SHEET *`, `IMAGE *`, `SCROLL *`), reads closer to English,
matches AMOS/STOS precedent. Concat aliases preserve backward
compatibility for every tutorial, WordPress embed, and shared program.

---

## Phase status: "Bash replacement" + "Full PETSCII" — mostly complete ✓

**Bash replacement:** ARGC/ARG$, stdin/stdout, pipes, SYSTEM, EXEC$ — done.  
**PETSCII experience:** basic-gfx (40×25 window, POKE/PEEK, INKEY$, TI, .seq), {TOKENS}, Unicode→PETSCII, COLORS/BACKGROUND, GET fix, {RESET}/{DEFAULT} — done.

---

* ~INSTR~

* ~**String length limit**~ — Implemented: default 4096; `#OPTION maxstr 255` or `-maxstr 255` for C64 compatibility.

* Flexible DATA read
  * ~RESTORE [line number]~ — implemented; RESTORE resets to first DATA; RESTORE 50 to first DATA at or after line 50.

* ~Decimal ↔ hexadecimal conversion: DEC(),HEX$()~
* ~MOD, <<, >>, AND, OR, XOR (bitwise operators)~

* ~IF THEN ELSE END IF~
  * ~Multi-line IF/ELSE/END IF blocks with nesting; backward compatible with IF X THEN 100~

* ~Structured loops: DO,LOOP,UNTIL,EXIT~
  * ~WHILE … WEND~ implemented.
  * ~DO … LOOP [UNTIL cond]~ and ~EXIT~ implemented. Nested DO/LOOP supported.

* ~Colour without pokes~
  * ~background command for setting screen colour~
  * ~colour/color for text colour~

* ~Cursor On/Off~

* ~**#OPTION memory addresses** (basic-gfx / canvas WASM)~ — Implemented:
  * `#OPTION memory c64` / `pet` / `default`; per-region `#OPTION screen` / `colorram` / `charmem` / `keymatrix` / `bitmap` with decimal or `$hex` / `0xhex`.
  * CLI: `-memory c64|pet|default` (basic-gfx). Overlapping 16-bit addresses use fixed priority: text → colour → charset → keyboard → bitmap.

* ~**MEMSET, MEMCPY**~ (basic-gfx; see `docs/memory-commands-plan.md`) — **done** (overlap-safe MEMCPY).

* ~**LOAD INTO memory**~ (basic-gfx; see `docs/load-into-memory-plan.md`) — implemented:
  * `LOAD "path" INTO addr [, length]` — load raw binary from file.
  * `LOAD @label INTO addr [, length]` — load from DATA block at label.
  * Terminal build: runtime error "LOAD INTO requires basic-gfx".

* ~**80-column option**~ (terminal, basic-gfx, **WASM canvas**)
  * `#OPTION columns 80` / `-columns 80`; default 40.
  * ~**Terminal**~: `print_width`, wrap, TAB, comma zones; `#OPTION nowrap` / `-nowrap`. Done.
  * ~**basic-gfx**~: 80×25; 640×200 window. Done.
  * ~**basic-wasm-canvas**~: `#OPTION columns 80` selects 640×200 RGBA framebuffer in browser. Done.

* **Configurable text row count (`#OPTION rows N` / `OPTION ROWS N`)** — *idea; not started.*  
  Today **basic-gfx** and **canvas WASM** use a fixed **25** text rows (`GFX_ROWS` / `SCREEN_ROWS`); screen/colour buffers are **2000** bytes (`GFX_TEXT_SIZE`), i.e. **40×25** or **80×25** layout.
  - **Easier subset:** **40 columns × 50 rows = 2000** cells — same total size as **80×25**, so the existing buffer could suffice **if** wide mode is constrained (e.g. cap rows when `columns=80`, or only allow 50 rows in 40-column mode until buffers grow).
  - **Harder:** **80×50** needs **4000** bytes (or dynamic allocation) and touches `GfxVideoState`, `gfx_peek`/`gfx_poke`, and anything assuming **2000** bytes.
  - **Front-ends:** window / framebuffer height becomes **rows×8** (50 rows → **400** px tall vs today’s **200**); WASM RGBA size and any hard-coded **200** in `canvas.html` / JS must track **rows**.
  - **Difficulty:** **moderate** — dozens of touch points across the interpreter and both renderers, but **bounded**; implementing **40×50** first is **materially simpler** than fully general **rows × columns** with a larger RAM model.

* **VGA-style 640×480 addressable pixels** — *idea; not started.* Goal: a **screen** / mode where the composited output is a **true 640×480** pixel surface (late-80s / early-90s **IBM PC VGA** feel), not merely **upscaling** the current **640×200** (80×25×8) framebuffer in the window.
  - **Distinct from:** “640×480 window” that **stretches or letterboxes** existing **640×200** content — that would be **low–moderate** effort (presentation only).
  - **This idea:** **every pixel** in **640×480** is a first-class drawing target — implies rethinking **text grid** (e.g. **80×60** at **8×8** cells, or non-8×8 metrics), **hires bitmap** (today **`GFX_BITMAP_*`** is **320×200** 1bpp), **sprites** (positioning, clipping, z-order), **`SCROLL`**, borders, and **WASM RGBA** buffer size (**640×480×4 ≈ 1.2 MiB** per full frame vs today’s **640×200×4**).
  - **Overlaps:** configurable **`rows`** / larger **`GFX_TEXT_SIZE`**, possible **separate “VGA mode”** vs **C64-compat** mode so existing programs stay predictable.
  - **Difficulty:** **high** — cross-cutting; comparable to a **new display preset** plus buffer growth and renderer work in **basic-gfx**, **canvas WASM**, and any **POKE/PEEK** semantics if video memory is exposed.

* **Sample sound playback (basic-gfx + canvas WASM only)** — *idea; not started.* Design: **`docs/rgc-sound-sample-spec.md`**. MVP: **single voice** (new **`PLAYSOUND`** stops previous), **`LOADSOUND` / `UNLOADSOUND` / `PLAYSOUND` / `STOPSOUND` / `PAUSESOUND` / `RESUMESOUND` / `SOUNDVOL`**, **`SOUNDPLAYING()`**; **non-blocking** gameplay; **WAV (PCM)** first; native **Raylib** with **command queue** from interpreter thread to main loop; **Web Audio** on WASM + **VFS** paths. **Difficulty:** **moderate** (native) to **moderate–high** (+ WASM); terminal build out of scope.

* PETSCII symbols & graphics
  * ~Unicode stand-ins~
  * ~Bitmap rendering of 40×25 characters (raylib)~ — **basic-gfx** merged to main.
  * ~Memory-mapped screen/colour/char RAM, POKE/PEEK, PETSCII, `.seq` viewer with SCREENCODES ON~

* **Bitmap graphics & sprites** (incremental; see `docs/bitmap-graphics-plan.md`, `docs/sprite-features-plan.md`)
  1. ~**Bitmap mode**~ — `SCREEN 0`/`SCREEN 1` (320×200 hires at `GFX_BITMAP_BASE`), monochrome raylib renderer; `COLOR`/`BACKGROUND` as pen/paper. ~`PSET`/`PRESET`/`LINE`~; POKE still works.
  2. ~**Sprites (minimal)**~ — `LOADSPRITE` / `UNLOADSPRITE` / `DRAWSPRITE` (persistent pose, z-order, optional `sx,sy,sw,sh` crop) / `SPRITEVISIBLE` / `SPRITEW`/`SPRITEH` / `SPRITECOLLIDE` in basic-gfx + canvas WASM; PNG alpha over text/bitmap; paths relative to `.bas` directory. ~Worked example: `examples/gfx_game_shell.bas` (PETSCII map + PNG player/enemy/HUD), `examples/gfx_sprite_hud_demo.bas`, `examples/player.png`, `examples/enemy.png`, `examples/hud_panel.png`.~ ~Tilemap **`LOADSPRITE`** with **`tw, th`** + **`DRAWSPRITETILE`** / **`SPRITETILES`** / **`SPRITEFRAME`** — done.~
  3. ~**Joystick / joypad / controller input**~ — **`JOY(port, button)`** / **`JOYSTICK`** / **`JOYAXIS(port, axis)`** — **basic-gfx** (Raylib) + **canvas WASM** (browser gamepad buffers). See `examples/gfx_joy_demo.bas`.
  4. **Graphic layers and scrolling** — ~**Viewport `SCROLL dx, dy`** + **`SCROLLX()`/`SCROLLY()`** (single shared offset for text/bitmap + sprites) — done.~ ~**Double-buffered cell list + `VSYNC`** — atomic frame-commit + 60Hz wait so per-frame `TILEMAP DRAW` / `SPRITE STAMP` rebuilds don't flicker — done (2026-04-18).~ Full **per-layer** stack (independent background vs tiles vs HUD scroll offsets) still open.
  5. ~**Tilemap handling (sheet)**~ — **`LOADSPRITE slot, "path.png", tw, th`** + **`DRAWSPRITETILE slot, x, y, tile_index [, z]`** + **`SPRITETILES(slot)`**. ~**Batched `TILEMAP DRAW slot, x0, y0, cols, rows, map()`** — array-driven whole-grid stamp in one interpreter dispatch — done (2026-04-17). `SHEET COLS/ROWS/WIDTH/HEIGHT`, `SPRITE FRAMES`, `TILE COUNT` accessors — done.~ Full world tile *grid* storage as BASIC-native data structure still manual.
  6. **Sprite animation** — ~Per-slot frame via **`SPRITEFRAME`** + tile-aware **`DRAWSPRITE`** — done.~ ~Optional frame rate / timing helpers — `ANIMFRAME(first, last, jiffies_per_frame)` intrinsic — done (2026-04-18).~ ~Per-call rotation via `SPRITE STAMP slot, x, y, frame, z, rot_deg` — done.~
  7. ~**Blitter-style ops, off-screen buffers, grab-to-sprite, export — Phase 1 complete (2026-04-17/18).**~ Shipped: `IMAGE NEW` / `IMAGE FREE` / `IMAGE COPY` (1bpp off-screen surfaces, visible ↔ slot blits, overlap-safe same-slot), `IMAGE LOAD` (PNG/BMP/JPG/TGA → 1bpp via stbi + luminance threshold), `IMAGE GRAB` (visible region → new slot), `IMAGE SAVE` (24-bit BMP export). Spec: **`docs/rgc-blitter-surface-spec.md`**. **Phase 2** (RGBA surfaces, colour blit, alpha-aware `IMAGE COPY`) and **Phase 3** (`TOSPRITE` — grab a bitmap region straight into a sprite slot for runtime tile extraction) still open. Scrolling + parallax covered by `IMAGE COPY` (examples: `gfx_scroll_demo.bas`, `gfx_parallax_demo.bas`).
  8. ~**Periodic timers (“IRQ-light”)** — `TIMER id, ms, FuncName` / `TIMER STOP|ON|CLEAR id`; 12 max timers, 16 ms min interval, cooperative dispatch between statements, skip-not-queue re-entrancy guard. Works in terminal, basic-gfx, and WASM. Designed as AMAL alternative (see `docs/rgc-blitter-surface-spec.md` §6). **Done.**~

* **Browser / WASM** (see `docs/browser-wasm-plan.md`, `web/README.md`, `README.md`)
  * ~**Emscripten builds**~ — `make basic-wasm` → `web/basic.js` + `basic.wasm`; `make basic-wasm-canvas` → `basic-canvas.js` + `basic-canvas.wasm` (GFX_VIDEO: PETSCII + `SCREEN 1` bitmap + PNG sprites via `gfx_software_sprites.c` / stb_image, parity with basic-gfx). Asyncify for `SLEEP`, `INPUT`, `GET` / `INKEY$`.
  * ~**Demos**~ — `web/index.html` (terminal output div, inline INPUT, `wasm_push_key`); `web/canvas.html` (40×25 / 80×25 PETSCII canvas, shared RGBA buffer + `requestAnimationFrame` refresh during loops/SLEEP).
  * ~**Controls**~ — **Pause** / **Resume** (`Module.wasmPaused`), **Stop** (`Module.wasmStopRequested`); terminal sets `Module.wasmRunDone` when `basic_load_and_run` finishes. Cooperative pause at statement boundaries and yield points (canvas also refreshes while paused).
  * ~**Interpreter fixes for browser**~ — e.g. FOR stack unwind on `RETURN` from `GOSUB` into loops; `EVAL` assignment form; terminal stdout line-buffering for `Module.print`; runtime errors batched for `printErr` on canvas.
  * ~**CI**~ — GitHub Actions WASM job uses **emsdk** (`install latest`), builds both targets, runs Playwright: `tests/wasm_browser_test.py`, `tests/wasm_browser_canvas_test.py`.
  * ~**Deploy hygiene**~ — `canvas.html` pairs cache-bust query on `basic-canvas.js` and `basic-canvas.wasm`; optional `?debug=1` for console diagnostics (`wasm_canvas_build_stamp`, stack dumps).
  * ~**Tutorial embedding**~ — `make basic-wasm-modular`; `web/tutorial-embed.js` + `RgcBasicTutorialEmbed.mount()` for **multiple** terminal instances per page. Guide: **`docs/tutorial-embedding.md`**. Example: `web/tutorial-example.html`. CI: `tests/wasm_tutorial_embed_test.py`, `make wasm-tutorial-test`.
  * ~**IDE tool host (canvas WASM)**~ — **`basic_load_and_run_gfx_argline`** exported; **`ARG$(1)`** … for bundled **`.bas`** tools (e.g. PNG preview). Spec: **`docs/ide-wasm-tools.md`**. Host IDE still needs UI wiring (click `.png` → write MEMFS → call export).
  * ~**WASM `EXEC$` / `SYSTEM` → host JS**~ — **`Module.rgcHostExec`** hook for IDE tools (uppercase selection, etc.). Spec + checklist: **`docs/wasm-host-exec.md`**.
  * ~**HTTP → MEMFS / binary I/O (for IDE tools & portable assets)**~ — **`HTTPFETCH url$, path$`** (WASM + Unix/`curl`), **`OPEN`** with **`"rb:"`/`"wb:"`/`"ab:"`**, **`PUTBYTE`/`GETBYTE`**. IDE can still **`FS.writeFile`** without interpreter changes. Notes: **`docs/http-vfs-assets.md`**.
  * **Still open — richer tutorial UX**: step-through debugging or synchronized markdown blocks (beyond Run button + static program text). ~Optional **`runOnEdit`** in `tutorial-embed.js`~ for debounced auto-run after edits.

* ~~Subroutines and Functions~~
  * **User-defined FUNCTIONS** implemented — `FUNCTION name[(params)]` … `RETURN [expr]` … `END FUNCTION`; call with `name()` or `name(a,b)`; recursion supported. See `docs/user-functions-plan.md`.

* Program text preprocessor
  * Replace current ad-hoc whitespace tweaks with a small lexer-like pass for keywords and operators
  * Normalize compact CBM forms while preserving semantics, e.g.:
    * `IFX<0THEN` → `IF X<0 THEN`
    * `FORI=1TO9` → `FOR I=1 TO 9`
    * `GOTO410` / `GOSUB5400` → `GOTO 410` / `GOSUB 5400`
    * `IF Q1<1ORQ1>8ORQ2<1ORQ2>8 THEN` → proper spacing around `OR` and `AND`
  * Ensure keywords are only recognized when not inside identifiers (e.g. avoid splitting `ORD(7)` or `FOR`), and never mangling string literals
  * Validate behavior against reference interpreter (`cbmbasic`) with a regression suite of tricky lines

* ~Include files / libraries~
  * ~#INCLUDE "path" implemented; relative to current file; duplicate line/label errors; circular include detection~
* ~Shebang-aware loader~
  * ~First line `#!...` ignored; #OPTION mirrors CLI (file overrides)~

* ~Reserved-word / identifier hygiene (variables)~
  * ~Reserved words cannot be used as variables; error "Reserved word cannot be used as variable"~
  * Labels may match keywords (e.g. `CLR:` in trek.bas); context distinguishes.
  * ~Underscores in identifiers~ — `is_prime`, `my_var` etc. now allowed.
  * Improve error messages where possible

* ~**String & array utilities**~ (see `docs/string-array-utils-plan.md`) — SPLIT, REPLACE, INSTR start, INDEXOF, SORT, TRIM$, JOIN, FIELD$, ENV$, JSON$, EVAL — all done. Key-value emulation via SPLIT+FIELD$; no dedicated DICT type for now.
  * ~**SPLIT**~ — `arr$ = SPLIT(csv$, ",")` — split string by delimiter into array.
  * ~**REPLACE**~ — `result$ = REPLACE(original$, "yes", "no")`.
  * ~**INSTR start**~ — `INSTR(str$, find$, start)` — optional start position for find-next loops.
  * ~**INDEXOF / LASTINDEXOF**~ — `INDEXOF(arr, value)` — 1-based index in array, 0 if not found.
  * ~**SORT**~ — `SORT arr [, mode]` — in-place sort; asc/desc, alpha/numeric.
  * ~**TRIM$**~ — strip leading/trailing whitespace (CSV, input).
  * ~**JOIN**~ — inverse of SPLIT: `JOIN(arr$, ",")`.
  * ~**FIELD$**~ — `FIELD$(str$, delim$, n)` — get Nth field (awk-like).
  * ~**ENV$**~ — `ENV$(name$)` — environment variable.
  * ~**PLATFORM$**~ — `PLATFORM$()` — returns `"linux-terminal"`, `"linux-gfx"`, `"windows-terminal"`, `"windows-gfx"`, `"mac-terminal"`, `"mac-gfx"`. Enables conditional code for paths/behavior.
  * ~**JSON$**~ — `JSON$(json$, path$)` — path-based extraction from JSON string (no new types); e.g. `JSON$(j$, "users[0].name")`.
  * ~**EVAL**~ — `EVAL(expr$)` — evaluate string as BASIC expression at runtime; useful for interactive testing.

* **Optional debug logging**
  * **Load logging** (`-debug load`): at each stage of `load_file_into_program` — raw line, after trim, directive handling (#OPTION/#INCLUDE), line number, after transform, after normalize. Helps debug parsing, include order, keyword expansion.
  * **Execution logging** (`-debug exec`): at each statement — line number, statement text, control flow (GOTO/GOSUB/RETURN), optionally expression results and variable writes. High volume; useful for stepping through tricky logic.

* **Future: IL/compilation**
  * Shelved for now: optional caching of processed program. Revisit when moving beyond pure interpretation to some form of IL or bytecode compilation — cache would then be meaningful (skip parse at load and potentially at exec).

---

## Potential priorities & sequence (post bash/PETSCII)

| Order | Item | Rationale |
|-------|------|------------|
| ~**1**~ | ~String length limit~ | Done. |
| ~**2**~ | ~String utils batch 1: INSTR start, REPLACE, TRIM$~ | Done. |
| ~**3**~ | ~RESTORE [line]~ | Done. |
| ~**4**~ | ~LOAD INTO memory~ | Done. |
| ~**5**~ | ~String utils batch 2: SORT, SPLIT, JOIN, FIELD$~ | Done. |
| ~**6**~ | ~INDEXOF, LASTINDEXOF~ | Done. |
| ~**7**~ | ~MEMSET, MEMCPY~ | Done. |
| ~**8**~ | ~ENV$, PLATFORM$, JSON$, EVAL~ | Done. |
| ~**9**~ | ~80-column option (terminal + basic-gfx + WASM canvas)~ | Done. |
| ~**10**~ | ~Browser/WASM (terminal + canvas demos, CI, pause/stop)~ | **Done** (see bullet list above). |
| ~**11**~ | ~Graphics 1.0 batch — primitives, sprites, tilemap, blitter, frame pipeline, input intrinsics~ | **Done (2026-04-18).** Shipped in the April 2026 unreleased batch: RECT/FILLRECT, CIRCLE/FILLCIRCLE, ELLIPSE/FILLELLIPSE, TRIANGLE/FILLTRIANGLE, POLYGON/FILLPOLYGON, FLOODFILL, DRAWTEXT, SPRITE STAMP (+ rotation), TILEMAP DRAW, SHEET/SPRITE-FRAMES/TILE-COUNT accessors, IMAGE NEW/FREE/COPY/LOAD/GRAB/SAVE, KEYDOWN/KEYUP/KEYPRESS, VSYNC, ANIMFRAME, ANTIALIAS, two-word command family + permanent concat aliases. Release notes: `docs/release-graphics-1.0.html`. |
| **12** | **Sound 1.0** — next milestone | `LOADSOUND / PLAYSOUND / STOPSOUND / PAUSESOUND / RESUMESOUND / SOUNDVOL / SOUNDPLAYING()` per `docs/rgc-sound-sample-spec.md`. MVP: single voice, WAV, native + canvas WASM. |
| **13** | **Typography / Font system** | `LOADFONT`, `DRAWTEXT` full args (fg/bg/font/scale), `.rgcfont` format, `pngfont2rgc` offline converter. Steps 4–6 of `docs/bitmap-text-plan.md`. |
| **14** | **Blitter Phase 2 / 3** | RGBA surfaces (colour blit, alpha blend), `TOSPRITE` grab-to-sprite. Unblocks `TEXTUREPOLY` + coloured `DRAWTEXT`. |
| **Later** | Optional debug logging (load + exec) | `-debug load`, `-debug exec`; verbose but useful for diagnostics. |
| **Later** | Program preprocessor | Polish; niche. |
| **Later** | WASM tutorial UX extras | Auto-run, stepping, deep IDE integration (embed API exists). |

---

**Completed (removed from list):**

* **Shell scripting update** — Full support for using the interpreter as a script runner: **command-line arguments** (`ARGC()`, `ARG$(0)`…`ARG$(n)`), **standard I/O** (INPUT from stdin, PRINT to stdout, errors to stderr; pipes and redirection work), and **system commands** (`SYSTEM("ls -l")` for exit code, `EXEC$("whoami")` to capture output). Example: `examples/scripting.bas`. See README “Shell scripting: standard I/O and arguments”.

- **Command-line arguments** — `ARGC()` and `ARG$(n)` (ARG$(0)=script path, ARG$(1)…=args). Run: `./basic script.bas arg1 arg2`.
- **Standard in/out** — `INPUT` reads stdin, `PRINT` writes stdout; errors/usage to stderr. Pipes work (e.g. `echo 42 | ./basic prog.bas`).
- **Execute system commands** — `SYSTEM("cmd")` runs a command and returns exit code; `EXEC$("cmd")` runs and returns stdout as a string (see README and `examples/scripting.bas`).
- Multi-dimensional arrays — `DIM A(x,y)` (and up to 3 dimensions) in `basic.c`.
- **CLR statement** — Resets all variables (scalar and array elements) to 0/empty, clears GOSUB and FOR stacks, resets DATA pointer; DEF FN definitions are kept.
- **String case utilities** — `UCASE$(s)` and `LCASE$(s)` implemented (ASCII `toupper`/`tolower`); use in expressions and PRINT.
- **File I/O** — `OPEN lfn, device, secondary, "filename"` (device 1: file; secondary 0=read, 1=write, 2=append), `PRINT# lfn, ...`, `INPUT# lfn, var,...`, `GET# lfn, stringvar`, `CLOSE [lfn]`. `ST` (status) set after INPUT#/GET# (0=ok, 64=EOF, 1=error). Tests: `tests/fileio.bas`, `tests/fileeof.bas`, `tests/test_get_hash.bas`.
- **RESTORE** — resets DATA pointer so next READ uses the first DATA value again (C64-style).

- **INSTR** — `INSTR(source$, search$)` returns the 1-based position of `search$` in `source$`, or 0 if not found.

- **Decimal ↔ hexadecimal conversion** — `DEC(s$)` parses a hexadecimal string to a numeric value (invalid strings yield 0); `HEX$(n)` formats a number as an uppercase hexadecimal string.

- **Colour without pokes** — `COLOR n` / `COLOUR n` set the foreground colour using a C64-style palette index (0–15), and `BACKGROUND n` sets the background colour, all mapped to ANSI SGR.

- **Cursor On/Off** — `CURSOR ON` / `CURSOR OFF` show or hide the blinking cursor using ANSI escape codes; tested with simple smoke programs.

- **basic-gfx (raylib PETSCII graphics)** — Windowed 40×25 PETSCII text screen, POKE/PEEK screen/colour/char RAM, INKEY$, TI/TI$, SCREENCODES ON (PETSCII→screen conversion for .seq viewers), `.seq` colaburger viewer with correct rendering, window closes on END.

- **Variable names** — Full names (up to 31 chars) significant; SALE and SAFE distinct. Reserved words rejected for variables/labels.

- **IF ELSE END IF** — Multi-line `IF cond THEN` … `ELSE` … `END IF` blocks; nested blocks supported.
- **WHILE WEND** — Pre-test loop `WHILE cond` … `WEND`; nested loops supported.
- **DO LOOP UNTIL EXIT** — `DO` … `LOOP [UNTIL cond]`; `EXIT` leaves the innermost DO; nested loops supported.
- **Meta directives** — Shebang, #OPTION (petscii, charset, palette), #INCLUDE; duplicate line/label errors; circular include detection. See `docs/meta-directives-plan.md`.

- **Browser / WASM** — `make basic-wasm` / `make basic-wasm-canvas`; `web/index.html` and `web/canvas.html`; Asyncify; virtual FS; Playwright smoke tests; CI via emsdk; Pause/Resume/Stop; paired JS+WASM cache-bust on canvas page. See `README.md`, `web/README.md`, `AGENTS.md`.

---

## Engineering / tooling follow-ups (optional)

Low-urgency cleanups noted during the April 2026 parser/CI hardening pass. None block features; bank them for a quiet afternoon.

* **Broader non-gfx statement fallback audit.** Only `statement_poke`'s terminal-build fallback was buggy (eating `: stmt` via `*p += strlen(*p)`); fixed in the commit adding `tests/then_compound_test.bas`. PSET/SCREEN/etc. raise runtime errors instead, which is the correct shape. Worth a second pass over every `#ifdef GFX_VIDEO` … `#else` block in `basic.c` to confirm none of the gfx-only statements *silently* swallow the rest of the line on terminal builds — the pattern is easy to miss and only bites with `IF cond THEN <stmt> : <stmt>`.

* **Sprite / sound statement body audit.** Separate from the `*p += N` keyword-skip audit (all 68 sites passed). Statements like `LOADSPRITE`, `DRAWSPRITE`, `SPRITEVISIBLE`, `SPRITEFRAME`, `LOADSOUND`, `PLAYSOUND` etc. have non-gfx-build fallbacks that should also parse-and-discard their args (same fix shape as POKE) so they compose cleanly inside `IF … THEN … : …`. Low risk but easy to forget until a user hits it.

* **Mouse-demo Step 3 revisit.** `examples/gfx_mouse_demo.bas` line 300 / 350 were rewritten to use GOSUB while the THEN+comma-args bug was still live. Now that it's fixed, those could fold back to inline form:
  * `300 IF ISMOUSEBUTTONDOWN(0) AND ISMOUSEBUTTONDOWN(1) THEN MOUSESET 160, 100 : WARPSHOW = 6`
  * `350 IF ZONE <> LASTZONE THEN SETMOUSECURSOR ZONE : LASTZONE = ZONE`
  Verify with the native demo (raylib) before landing — line 300 also touches WARPSHOW which was a later addition.

---

## BUFFER type — large-data companion to strings

Full design in **`docs/buffer-type-plan.md`**. `HTTP$` / `JSON$` silently cap at `MAX_STR_LEN` (4 KB) because every `struct value` carries an inline `char str[MAX_STR_LEN]`. Raising the cap grows every stack frame — non-starter. Instead: a BUFFER is a RAM-disk file. `BUFFERNEW B` allocates a slot and creates `/tmp/rgcbuf_NNNN`; `BUFFERFETCH B, url$` HTTPs into it; `BUFFERPATH$(B)` returns the path so programs use existing `OPEN`/`LINE INPUT #`/`GET #`/`CLOSE` verbs to stream through it. Canvas WASM gets this for free via Emscripten's MEMFS (already on; `HTTPFETCH` already writes there). Native uses real `/tmp`. Zero changes to `open_files[]`, `struct value`, or any existing file-I/O verb — BUFFER rides on top.

**Rollout:**

* **Step 1 — core slot table + `BUFFERNEW`/`BUFFERFETCH`/`BUFFERFREE`/`BUFFERLEN`/`BUFFERPATH$`.** Users fetch big blobs, read chunk-by-chunk with existing verbs. Unblocks `bins.bas` style demos. Regression tests: `tests/buffer_basic_test.bas`, `tests/buffer_slots_test.bas`.

* **Step 2 — `JSONFILE$(path$, jpath$)`.** One function; reuses existing `json_extract_path` against file bytes. Eliminates the "slurp 50 KB into a 4 KB string" anti-pattern.

* **Step 3 — `RESTORE FILE path$` / `RESTORE BUFFER slot`.** Retargets DATA/READ to scan a file/buffer. Bigger change — second `data_items` source or streaming tokenizer. Not urgent.

**Open questions in the doc:** Windows `/tmp` path, MAX_BUFFERS ceiling (16 vs 64), whether `BUFFERFETCH` should accept `file://` URLs to subsume a future `BUFFERLOAD`.

---

## Mouse-over-sprite hit test + `SPRITEAT` + drag-and-drop

Full design in **`docs/mouse-over-sprite-plan.md`**. Summary: today a BASIC-level `MOUSEOVER(sx, sy, sw, sh)` helper (documented in the README) covers the bounding-box case using `GETMOUSEX/Y` + `SPRITEW/H`. An engine-level API earns its keep for three cases BASIC can't do cleanly:

* **`ISMOUSEOVERSPRITE(slot)`** — hit-test against the slot's last-drawn rect; engine remembers the position so programs don't have to. Optional `ISMOUSEOVERSPRITE(slot, 1)` samples the PNG's alpha channel for pixel-perfect round-button / irregular-shape hit testing.
* **`SPRITEAT(x, y)`** — returns the topmost visible slot whose rect contains the point, or `-1`. Useful for "click to select from a pile" in RTS unit stacks or inventory.
* **Consistency with `SCROLL` and `SPRITECOLLIDE`** — hit test respects `SCROLLX()/SCROLLY()` so sprite positions stay in world space while mouse coords are screen space, matching how `SPRITECOLLIDE` already works.

Implementation sequence in the plan doc: (1) per-slot `last_x/y/w/h` cache updated at `DRAWSPRITE`/`DRAWSPRITETILE` enqueue time, (2) `ISMOUSEOVERSPRITE` bounding-rect mode + keyword wiring + RTS-button demo, (3) pixel-perfect mode, (4) `SPRITEAT` iteration with z-sort, (5) drag-and-drop example (pure BASIC on top of the new API), (6) canvas WASM parity.

**Shipped (unreleased):**

* ~**Steps 1 + 2 + 6 — per-slot position cache + `ISMOUSEOVERSPRITE(slot)` bounding-rect hit test, native and canvas WASM.**~ `g_sprite_draw_pos[]` written on the interpreter thread inside `gfx_sprite_enqueue_draw` (so it doesn't race the worker-thread consumer); sw/sh ≤ 0 resolved via `gfx_sprite_effective_source_rect` for SPRITEFRAME / tilemap slots; `UNLOADSPRITE` clears the entry. `basic.c`: `FN_ISMOUSEOVERSPRITE = 62`, name lookup, `eval_factor` dispatch, `starts_with_kw` allow-list. Example: `examples/ismouseoversprite_demo.bas`.

**Still outstanding:** pixel-perfect mode (step 3), `SPRITEAT` (step 4), drag-and-drop example (step 5), SCROLL-space consistency, rotation/scale pivot handling.

Open questions in the doc: alpha cutoff threshold, source-rect vs destination-rect sampling for scaled sprites, last-draw persistence across non-drawn frames, rotation/transform future-proofing.

## Text in bitmap mode + pixel-space `DRAWTEXT`

Full design in **`docs/bitmap-text-plan.md`**. Split into two halves: character-set rendering in bitmap mode (done), and the new Font / `DRAWTEXT` system (outstanding).

**Shipped (post-1.6.3, unreleased):**

* ~**Step 1 — `gfx_video_bitmap_clear` + `gfx_video_bitmap_stamp_glyph` helpers; `CHR$(147)` routes on `screen_mode`.**~
* ~**Step 2 — `PRINT` / `TEXTAT` render into `bitmap[]` via the active chargen when `screen_mode == GFX_SCREEN_BITMAP`.** Solid paper so over-prints overwrite cleanly; text plane untouched in bitmap mode per spec.~
* ~**Step 3 — Bitmap-mode scroll on PRINT overflow.** `gfx_video_bitmap_scroll_up_cell` shifts the plane up 8 pixel rows via `memmove` and zeros the bottom cell; text-mode `gfx_scroll_up` unchanged.~

Result so far: programs that `PRINT` a HUD, score, or status line in `SCREEN 1` now render exactly as they would in `SCREEN 0`, using the same chargen. Good for tutorial examples before Fonts arrive.

**Outstanding:**

* **Step 4 — `DRAWTEXT x, y, text$` minimal form shipped (2026-04-17):** pixel-space stamp using the active character-set glyphs, transparent OR blend, current pen, 8×8 only. Bytes go through `petscii_to_screencode`. Extended form with `[, fg [, bg [, font_slot [, scale]]]]` still open — needs the Font system (step 5) for `font_slot` to mean anything and RGBA blitter Phase 2 for per-call `fg`/`bg`. Integer `scale` (render-time pixel-doubling) is cheap and could ship standalone against the 8×8 chargen before Fonts land.

* **Step 5 — `LOADFONT slot, "path.rgcfont"` / `UNLOADFONT slot`.** Reads the 8-byte `RGCF` magic header (width, height, glyph count) and the bitmap payload that follows. Fonts live in a separate `Font fonts[N]` array on `GfxVideoState` — entirely distinct from the active character set, which keeps its existing storage and layout. Slot 0 is the built-in default Font (a Font-copy of the 8×8 PET artwork); swapping the active character set does not touch it.

* **Step 6 — Canvas WASM Playwright parity.** One Playwright case for `SCREEN 1 : PRINT "HI"`, one for `SCREEN 1 : DRAWTEXT 100, 50, "HI", 7`.

* **Intermediate: offline converter tool `tools/pngfont2rgc`.** Turns a bitmap-font PNG into the `.rgcfont` format `LOADFONT` consumes. Keeps the interpreter's Font loader to a header-read plus one `fread`; lets users edit in Aseprite/GIMP/Photoshop, export PNG, convert, load. Uses `stb_image.h` already in `gfx/`. Optional `.py` companion for single-script edit+convert. Examples in `examples/fonts/` (8×8 default, 8×16 slim, 16×16 chunky, 16×16 bold).

* **Terminology reminder (locked in the spec):** **character set** (lowercase, 8×8×256, PETSCII-indexed, drives `PRINT`/`LOCATE`/`TEXTAT`/`CHR$(147)` — already wired for bitmap mode); **Font** (capital F, arbitrary dimensions, PETSCII-free, `DRAWTEXT`-only, loaded via `LOADFONT`). The two concepts don't share storage, structs, or loaders. Sizing: per-slot native dimensions (different sizes = different Fonts) vs render-time integer scale (pixel-doubling at draw time). Weights ship as separate Fonts with their own artwork — no algorithmic fake-bold.

* **Resolved open questions** (from the spec): PETSCII normalisation applies only to the character-set path (inherits from PRINT's existing flow); `DRAWTEXT` never normalises. Cursor in bitmap mode is a no-op for now — character-set-scope only, trivial XOR-stamp revival if anyone asks. 80-col is text-mode only; bitmap character-set path is forever 40×25.

## Modernisation-pass syntax gaps (2026-04-19)

Surfaced while rewriting old-style `examples/*.bas` into modern form (labels, `FUNCTION`, `DO/LOOP`, `COLOR`/`BACKGROUND`/`CLS`). Not blockers — noted so future examples can be even cleaner.

- **No standalone `REVERSE ON`/`REVERSE OFF` statement.** Programs still emit reverse video via `PRINT CHR$(18)`/`CHR$(146)` or the `{RVS ON}`/`{RVS OFF}` string tokens. A first-class statement would match the `COLOR`/`BACKGROUND`/`CLS` ergonomics.
- **`COLOR`/`BACKGROUND` take only numeric index (0–15).** No named form (e.g. `COLOR RED`). The `{RED}` token works inside strings, but a bare `COLOR RED` would read better in modernised examples.
- **`FUNCTION` has no `LOCAL` vars, no `EXIT FUNCTION`, no optional params** (documented non-goals for v1 in `docs/user-functions-plan.md`). Examples that want early-return from a helper still need an `IF/END IF` wrap.
- **`POKE` is a no-op in terminal `basic`** (functional only in `basic-gfx`). Terminal demos that illustrated screen RAM pokes can't be directly modernised without a `basic-gfx` dependency — the `gfx_poke_demo.bas` remains `basic-gfx`-only.
- **`CLS` clears screen but not colour state.** Modernised files that set `COLOR`/`BACKGROUND` once at the top then `CLS` mid-program keep the previous palette, which is usually what's wanted; flag if that ever surprises.

## Bitmap plane double-buffer — SHIPPED 1.9.5 (2026-04-19)

`DOUBLEBUFFER ON` / `DOUBLEBUFFER OFF` now exposes a bitmap-plane
back-buffer. BASIC writes to `bitmap[]` as before; the renderer reads
`bitmap_show[]` when the mode is on, and `VSYNC` atomically flips
(memcpys build → show). Default OFF keeps CBM-era programs working
unchanged. Combined with the always-double-buffered cell list, the
canonical per-frame pattern no longer flickers. Example:
`examples/gfx_doublebuffer_demo.bas`. See 1.9.5 CHANGELOG entry.

Remaining gaps moved to follow-up work below.

## Multiple screen buffers (proposed, next 2026-04-19)

Now that the bitmap plane has one back-buffer, the natural extension
is user-selectable buffers: draw into one while another displays,
flip, draw in a third, etc. Use cases:

- AMOS-style **dual playfield**: static world pre-rendered into one
  buffer, dynamic overlays drawn into another each frame.
- **Flipbook animation**: pre-render N keyframes, cycle which one
  is shown.
- **Triple-buffer** for expensive composites that can't finish in one
  jiffy — draw in buffer 2 over several frames while 0 displays.

### API sketch

```basic
SCREEN BUFFER n            ' allocate bitmap buffer slot `n` (0..7)
SCREEN DRAW   n            ' subsequent bitmap writes target buffer `n`
SCREEN SHOW   n            ' display buffer `n` (flip target)
SCREEN FREE   n            ' release buffer `n`
SCREEN SWAP   a, b         ' atomic swap DRAW and SHOW indices
```

- Buffer 0 is the current `bitmap` (always present).
- Buffer 1 is the existing `bitmap_show` back-buffer (auto-allocated
  when `DOUBLEBUFFER ON`).
- Buffers 2..7 are caller-allocated `SCREEN BUFFER n` — each is a
  `GFX_BITMAP_BYTES` block on heap.
- Write path: every BASIC bitmap statement (`PSET`, `LINE`, `RECT`,
  `CLS`, `DRAWTEXT`, ...) indexes the draw buffer instead of the
  fixed `bitmap[]`. Single indirection.
- Display path: renderer reads the show buffer.
- `DOUBLEBUFFER ON` reinterpreted as `SCREEN BUFFER 1 : SCREEN DRAW 0 : SCREEN SHOW 1`
  plus auto-flip on VSYNC. Keeps source backwards compatible.

### Implementation cost

Medium. Changes: one pointer indirection for every bitmap statement
(already localised in `gfx_bitmap_get_pixel` / `gfx_bitmap_set_pixel`
in `gfx_video.c`), a small `uint8_t *screen_buffers[MAX_SB]` table
on `GfxVideoState`, and the new `SCREEN BUFFER/DRAW/SHOW/FREE/SWAP`
dispatch in `basic.c`. Tests per spawn/swap/free scenario. Plan to
ship alongside or just after music/sound work.

## Bitmap plane not double-buffered — historical note (2026-04-19, shipped)

`VSYNC` (`gfx_raylib.c:578 gfx_cells_flip`) only flips the cell list used by `SPRITE STAMP` and `TILEMAP DRAW`. The bitmap plane — everything written by `CLS`, `RECT`, `FILLRECT`, `FILLCIRCLE`, `CIRCLE`, `LINE`, `PSET`, `ELLIPSE`, `TRIANGLE`, `FILLTRIANGLE`, `POLYGON`, `DRAWTEXT` — writes direct to the single displayed texture, so the renderer can sample mid-update. Programs that `CLS` + redraw the whole scene each tick flicker; `gfx_ball_demo.bas` (2026-04-19) is the canonical repro.

Options:

1. **Double-buffer the bitmap plane** (proper fix). Matches the cell-list model: BASIC writes to `bitmap_build`, renderer reads from `bitmap_show`, `gfx_cells_flip` (or a parallel `gfx_bitmap_flip`) copies build→show under the sprite mutex. Lets the existing `CLS` + full-redraw pattern work without flicker.
2. **Document the "partial erase" idiom** (interim workaround, already in `gfx_hud_demo` / `gfx_showcase`): avoid full `CLS` inside the loop, `FILLRECT` only the changed regions. Readable for small HUDs, awkward for anything bigger.

### Proposed: `CLS` with optional clear-rectangle

Extend `CLS` to accept an optional pixel region so partial erase is as ergonomic as a full clear, using the current paper colour:

```basic
CLS                                 ' full-screen clear (unchanged)
CLS x, y TO x2, y2                  ' clear rectangle in current PAPER/BACKGROUND
```

Implementation sketch:

- `statement_cls` already takes `(char **p)` but currently ignores it; parse optional `x, y TO x2, y2` after the keyword.
- Delegate to `gfx_video_fill_rect_bg` (or equivalent) so the existing paper colour logic is reused — no new colour arg needed.
- Terminal build: fall back to clearing just that many character cells via ANSI, or ignore the region and clear-screen as today.
- Reads naturally alongside `FILLRECT`: `CLS` = paper colour; `FILLRECT` = pen colour.

