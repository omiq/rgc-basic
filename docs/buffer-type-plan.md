# BUFFER type — large-data companion to strings

## Problem

BASIC strings are capped at `MAX_STR_LEN` (4096 bytes, compile-time constant in
`basic.c`). Every `struct value` carries an inline `char str[MAX_STR_LEN]`, so
the cap is not just a convention — it is load-bearing for the evaluator's
pass-by-value semantics and for keeping stack frames cheap. Raising the cap
universally would grow every local, every array slot, and every `struct value`
on the interpreter's stack proportionally; at 64 KB that is a memory budget
non-starter on canvas WASM.

The user-visible symptom is that `HTTP$(url)` silently truncates any response
over 4 KB. `FN_HTTP` writes into a local `char outbuf[MAX_STR_LEN]` (see
`basic.c` around line 5238) and returns `make_str(outbuf)`. A JSON feed with
~80 entries fills the buffer to byte 4095 mid-token; subsequent `INSTR` /
`JSON$` calls against the returned string either miss data past the boundary or
parse malformed JSON.

## Non-goals

- **Do not raise `MAX_STR_LEN`.** String semantics stay 4 KB, cheap, inline.
- **Do not introduce a new typed variable syntax** (e.g. `DIM B AS BUFFER`).
  RGC BASIC does not have `AS TYPE` today; adding it just for buffers is a
  parser detour. Buffers are tracked in a slot table, like sprites.
- **Do not duplicate every string intrinsic** (`BUFFERMID$`, `BUFFERFIND`,
  `BUFFERBYTE` — all rejected). Users already know `GET #`, `INPUT #`,
  `LINE INPUT #`, `SEEK`, `EOF`; buffers reuse those verbs.
- **Do not add a file-backend abstraction** to `open_files[]`. That is the
  "right" design in the abstract but costs ~300 lines of conditional dispatch
  across 6+ statement handlers. MEMFS gives us the same behaviour for free.

## Design: a BUFFER is a RAM-disk file

Key observation: **the Emscripten build has `FORCE_FILESYSTEM=1` and already
uses MEMFS.** `HTTPFETCH` writes bytes to a MEMFS path, and the existing
`OPEN` / `INPUT #` / `GET #` verbs read from MEMFS paths unchanged. The native
build has a real `/tmp`.

So a BUFFER is literally a file that happens to live under `/tmp`. The slot
table stores the auto-generated path. Users get the handle from `BUFFERNEW`,
pass it to `BUFFERFETCH` to populate, and read with existing file-I/O verbs.

```
BUFFERNEW B            ' slot 0..15; path auto-generated (/tmp/rgcbuf_0000)
BUFFERFETCH B, URL$    ' HTTPFETCH into that path; HTTP status set as usual
PRINT BUFFERLEN(B)     ' bytes written

OPEN 1, 0, 0, BUFFERPATH$(B)  ' read-mode open against the buffer's path
DO WHILE NOT EOF(1)
    LINE INPUT #1, L$
    ' process chunk-by-chunk; each L$ bounded by MAX_STR_LEN
LOOP
CLOSE 1

BUFFERFREE B           ' optional; auto-cleaned at program end
```

No changes to `struct value`, `open_files[]`, `statement_open`,
`statement_input_hash`, `statement_get_hash`, or `statement_close`. Zero risk
of breaking the existing file I/O; buffers ride on top of it.

## API surface (v1)

Four statements + two functions. All live under `B` in the dispatcher.

| Keyword                  | Form                                         | Semantics                                                                            |
| ------------------------ | -------------------------------------------- | ------------------------------------------------------------------------------------ |
| `BUFFERNEW slot`         | statement                                    | Allocate slot (0..`MAX_BUFFERS-1`); auto-generate path; create zero-byte file.       |
| `BUFFERFETCH slot, url$` | statement (WASM/native)                      | HTTP GET into the slot's path. Sets `HTTPSTATUS()`. Returns via error hint on 4xx/5xx path only if explicitly checked by user. Optional 3rd/4th args mirror `HTTPFETCH`: `BUFFERFETCH slot, url$, method$, body$`. |
| `BUFFERFREE slot`        | statement                                    | Unlink the path; mark slot free. Idempotent on already-free slots.                   |
| `BUFFERLEN(slot)`        | function → number                            | Bytes in the buffer (result of `stat(path).st_size`; 0 if free).                     |
| `BUFFERPATH$(slot)`      | function → string                            | The MEMFS/`/tmp` path; usable with `OPEN`, `HTTPFETCH`, or any file-path intrinsic.  |

**Not in v1** (deliberate — adds complexity, not value):

- `BUFFERLOAD slot, path$` / `BUFFERSAVE slot, path$` — today you can
  `BUFFERFETCH` a `file://` URL or just `OPEN` directly on the real file.
  Add these later if the `file://` URL path proves awkward.
- `BUFFERAPPEND`, byte-level mutation — users can `OPEN 1, 0, 1, BUFFERPATH$(B)`
  in append mode and `PRINT #1` to write.
- `RESTORE BUFFER slot` — the DATA/READ integration is a separate, larger
  feature covered in step 3 of the rollout plan. Ship BUFFER first.
- `JSONFILE$(path$, jpath$)` — step 2 of the rollout; adds file-aware JSON
  extraction so users don't have to slurp buffers into 4 KB strings just to
  pluck fields.

## Slot table (mirrors sprite allocation)

```c
#define MAX_BUFFERS 16
#define BUFFER_PATH_MAX 64  /* "/tmp/rgcbuf_NNNN" + null = plenty */

typedef struct {
    int  in_use;
    char path[BUFFER_PATH_MAX];
} rgc_buffer_slot;

static rgc_buffer_slot g_buffers[MAX_BUFFERS];
static int g_buffer_next_id = 0;  /* monotonic; wraps after UINT16_MAX */
```

Path format: `/tmp/rgcbuf_NNNN` where `NNNN` is a zero-padded 4-digit counter
that increments on every `BUFFERNEW`. Monotonic (not slot-index) so reusing
slot 0 repeatedly doesn't collide with a prior not-yet-cleaned path in the
rare edge case.

`BUFFERNEW` behaviour:

1. Validate `0 <= slot < MAX_BUFFERS`; runtime error otherwise.
2. If `g_buffers[slot].in_use`, delete the old file first (idempotent replace).
3. Generate path `/tmp/rgcbuf_NNNN`, store in slot, mark in_use.
4. `fopen(path, "wb")` + `fclose` to create an empty file (so `BUFFERLEN`
   returns 0 instead of -1 for brand-new buffers that haven't been
   `BUFFERFETCH`'d yet).

`BUFFERFREE` behaviour: `unlink(path)`; clear slot; idempotent on free slots.

**Program-end cleanup.** Add a loop at interpreter exit that unlinks every
`in_use` buffer's path. Leaks are otherwise harmless in MEMFS (wiped at page
reload) but untidy on native.

## Error handling

- `BUFFERNEW slot` out of range: `runtime_error_hint("BUFFERNEW slot out of range", "Valid slots are 0..15.")`
- `BUFFERFETCH` on non-allocated slot: `runtime_error_hint("BUFFERFETCH: slot not allocated", "Use BUFFERNEW slot before BUFFERFETCH.")`
- `BUFFERFETCH` HTTP failure: sets `HTTPSTATUS()` like `HTTPFETCH` does; no exception thrown. User checks `IF HTTPSTATUS() >= 400 THEN ...`.
- `BUFFERLEN` / `BUFFERPATH$` on unallocated slot: return `0` / `""`, no error — consistent with how `SPRITEW`/`SPRITEH` handle unloaded sprites.
- `BUFFERFREE` on already-free slot: no-op, no error.

## Implementation map

All in `basic.c`. Numbers are best-guess line regions — confirm at edit time.

1. **Forward declarations** (near `statement_bitmapclear` forward decl, ~line 2481):
   - `static void statement_buffernew(char **p);`
   - `static void statement_bufferfetch(char **p);`
   - `static void statement_bufferfree(char **p);`
2. **Slot table** (near other static tables, ~line 1286 after `open_files`):
   - `#define MAX_BUFFERS 16`
   - `#define BUFFER_PATH_MAX 64`
   - struct + static array + `g_buffer_next_id`.
3. **FN enum additions** (~line 2570):
   - `FN_BUFFERLEN = 63`
   - `FN_BUFFERPATH = 64`
4. **Name lookup** in `lookup_function_name` 'B' case (~line 3650 area):
   - `BUFFERLEN` → `FN_BUFFERLEN`
   - `BUFFERPATH$` → `FN_BUFFERPATH`
5. **`eval_factor` dispatch** (near FN_GETMOUSEX handler, ~line 5519):
   - Handler for `FN_BUFFERLEN`: one-arg slot, `stat(path, &st)`, return `st.st_size`.
   - Handler for `FN_BUFFERPATH`: one-arg slot, return `make_str(g_buffers[slot].path)`.
6. **`starts_with_kw` allow-list** (~line 7017): add `BUFFERLEN`, `BUFFERPATH`.
7. **Statement dispatcher** ('B' case, next to `BITMAPCLEAR`, ~line 10288):
   - `BUFFERNEW` → `statement_buffernew`
   - `BUFFERFETCH` → `statement_bufferfetch`
   - `BUFFERFREE` → `statement_bufferfree`
8. **Reserved words table** (~line 2801): add `BUFFERNEW`, `BUFFERFETCH`, `BUFFERFREE`, `BUFFERLEN`, `BUFFERPATH`.
9. **Statement bodies** — place together near `statement_bitmapclear`:
   - `statement_buffernew`: parse slot num, allocate.
   - `statement_bufferfetch`: parse slot, url, optional method/body; call existing `http_fetch_to_file_impl(url, g_buffers[slot].path, method, body)`.
   - `statement_bufferfree`: parse slot, unlink + clear.
10. **Program-end cleanup** — hook into wherever END/program-reset lives
    (`reset_program_state` or equivalent). Loop `for i in MAX_BUFFERS: if in_use: unlink; clear`.

## Testing

Two test files, added under `tests/`:

1. **`tests/buffer_basic_test.bas`** — terminal-safe (no HTTP, no GFX).
   - `BUFFERNEW 0`
   - Open slot 0's path for write, `PRINT #1, "HELLO"` / `PRINT #1, "WORLD"`, close
   - Re-open for read, `LINE INPUT #1` twice, `PRINT` the two lines.
   - `PRINT BUFFERLEN(0)` — expect 12 (HELLO\nWORLD\n).
   - `PRINT BUFFERPATH$(0)` — starts with `/tmp/rgcbuf_`.
   - `BUFFERFREE 0`.
   - `PRINT BUFFERLEN(0)` — expect 0.
   - Expected-output file: `tests/buffer_basic_test.out`.
2. **`tests/buffer_slots_test.bas`** — exercises multiple concurrent slots.
   - `BUFFERNEW 0`, `BUFFERNEW 5`, `BUFFERNEW 15`.
   - Write different content to each via `OPEN`/`PRINT #`.
   - Read back, assert distinct.
   - `BUFFERFREE` all three.

No HTTP test in the automated suite — network would make CI flaky. The WASM
canvas browser test can exercise `BUFFERFETCH` against a local-served fixture
if needed, but v1 ships without that.

Both tests added to `tests/run_bas_suite.sh`.

## Rollout plan (reminder; kept in to-do.md)

- **Step 1 (this spec): BUFFER slots + `BUFFERNEW`/`BUFFERFETCH`/`BUFFERFREE`/`BUFFERLEN`/`BUFFERPATH$`.** Users fetch big blobs, open them by path, read with existing verbs. Teaches streaming pattern.
- **Step 2: `JSONFILE$(path$, jpath$)`.** One function. Runs `json_extract_path` against mmap'd/read file bytes. Eliminates the "slurp 50 KB into a 4 KB string" anti-pattern.
- **Step 3: `RESTORE FILE path$` / `RESTORE BUFFER slot`.** Retargets DATA/READ to scan a file/buffer. Bigger change — adds a second `data_items` source or a streaming tokenizer. Not urgent; unlocks "fetch a CSV, walk it with READ" once users actually ask for it.

## Open questions

1. **Native `/tmp` on Windows.** Windows terminal builds don't have `/tmp`. Use
   `GetTempPathA` via a shim, or accept that BUFFER is Unix/WASM for now and
   document. Suggested: probe `TMP` / `TEMP` env var, fall back to `.` + prefix.
2. **MAX_BUFFERS ceiling.** 16 feels right for v1. If it proves tight,
   raising to 64 costs 64 × 68 bytes = 4 KB of BSS. No runtime cost.
3. **Should `BUFFERFETCH` accept a `file://` URL so `BUFFERLOAD` isn't
   needed?** HTTPFETCH already handles `file://`? Confirm at implementation
   time; if not, a small addition to the fetch impl pays off.
