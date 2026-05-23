# Runtime error source-line proposal

**Wishlist item:** §3d from `docs/haversack-wishlist.md` — "Source line in runtime error messages". Promoted by Haversack triage 2026-05-23 as highest-value next-up item.

**Status:** proposal, not yet implementing. Lands in two phases; Phase 1 is the minimum-viable ship and matches the wishlist ask, Phase 2 is the opt-in follow-up for breadcrumb-style diagnostics.

## What we have today

`runtime_error_hint(msg, hint)` (`basic.c:3871`) already emits a rich four-line block whenever it's called from a runtime context:

```
Error on line N: <msg>
  Hint: <hint>
  <full source line text>
       ^
```

It pulls `line_no` and `line_text` from `program_lines[current_line]`, and the caret column from `statement_pos`. So when a runtime error site routes through this helper, the user gets the call site for free.

`struct line` (`basic.c:1928`) is two fields — `number` and `text`. **It does not track which source file the line came from.** After `#INCLUDE` flattening, every line lives in the same `program_lines[]` array with no provenance.

## What's missing

Three concrete gaps surfaced by Haversack triage and verified empirically against `/Users/chrisg/github/rgc-basic/basic` HEAD on 2026-05-23:

### Gap 1 — Direct `fprintf(stderr, ...)` sites that bypass `runtime_error_hint`

Audit of `grep -n "fprintf(stderr" basic.c` produces ~30 hits. Categorise:

- **Load-time / include errors** (lines 19658, 19739, 19772-19796, 19921-19967, 19982) — already include the offending file path via `"in %s"` since they fire before `current_line` is meaningful. Acceptable. No change.
- **Runtime soft errors that DO emit a stderr line but skip the line context** — `OPEN` (16851), `DOWNLOAD no-op warning` (9785). These should migrate to `runtime_error_hint` (or a non-halting variant — see *§ A non-halting variant* below) so they pick up line info.
- **Already routed correctly** — `runtime_error_hint`'s own internals (3955+), parser duplicate-label (4501), FUNCTION/END FUNCTION mismatch (4701). No change.

### Gap 2 — Silent soft failures (status code only, no diagnostic)

Empirically demonstrated:

```basic
10 R$ = HTTP$("http://nonexistent.example.invalid/")
20 PRINT "status="; HTTPSTATUS()
```

Produces only `status=0` — no breadcrumb that anything went wrong. Same shape for:

- HTTP$ / HTTPFETCH / BUFFERFETCH network failures → `http_last_status = 0` and empty/missing payload
- JSON read in non-strict mode → `json_last_status = 1` and sentinel return
- DICTLOAD on malformed JSON (the function form, not the statement form) → returns `-1`, `json_last_status = 1`

Tool authors are forced to check `JSONSTATUS()` / `HTTPSTATUS()` after every call — easy to forget, hides bugs in tests.

### Gap 3 — Line number alone insufficient with `#INCLUDE`

`Error on line 17` is ambiguous when the program is a main file plus four `#INCLUDE`d helpers. The user needs `Error at lib/json_helpers.bas:17` to localise without re-reading the include order.

## Proposed shape

### Phase 1 — audit + cleanup (minimum viable)

The wishlist core ask. Ships in one diff.

1. **Migrate the runtime-context fprintf(stderr) sites to `runtime_error_hint`** (Gap 1). Specific sites — see *§ Call site audit* below. Each migration is a one-line swap; no behaviour change beyond gaining the line-context block.
2. **Audit each existing `runtime_error_hint` call for accurate `current_line`.** Most evaluate-time errors fire while `current_line` is set by the dispatch loop; verify by inspection. Specific concern is helper functions called from `load_program` before `current_line` is meaningful — those should pass an explicit `at_line` parameter if they want runtime-style reporting (rare).
3. **No directive, no new builtin, no struct change.** Just ensure every runtime-fired error message goes through the helper that already prints line context.

Verification: a tiny `tests/runtime_errors/` corpus with one `.bas` per failure shape, asserting (via grep + exit code) that stderr contains `Error on line N` with the expected `N`.

### Phase 2 — file-path provenance + opt-in breadcrumbs (follow-up)

Ships separately. Each part is independent — pick any subset later.

**2a. Track per-line source file.** Extend `struct line`:

```c
struct line {
    int number;
    char *text;
    const char *src_file;   /* interned path; NULL = main program */
};
```

`#INCLUDE` populates `src_file` for the lines it adds. `runtime_error_hint` switches to `"Error at %s:%d"` when `src_file` is non-NULL, falls back to `"Error on line %d"` otherwise. Tests need updating; otherwise low-risk.

Memory cost: one pointer per line × MAX_LINES. Paths interned in a global table so duplicates share storage.

**2b. `LASTERROR$()` builtin + ccall export.** Returns a structured string of the last error in the form `"at <file>:<line>: <msg>"` (empty if none). Companion to `JSONSTATUS()` / `HTTPSTATUS()`. Tool authors use it in scripts; JS hosts get a ccall export `basic_get_lasterror()`. Cheap — one global `char[]` written by `runtime_error_hint` and the status-code sites.

**2c. `#OPTION DIAGNOSTICS`.** When set, emit a one-line stderr breadcrumb at every status-code soft-failure site (HTTP network fail, JSON parse fail in non-strict mode, DICTLOAD parse fail, etc.) so test runs are noisy-but-locatable. Default off — no behaviour change for existing scripts.

The three pieces compose: `#OPTION DIAGNOSTICS` ON gives push-mode breadcrumbs during dev; `LASTERROR$()` gives pull-mode access for production logic; Phase 2a makes both useful for `#INCLUDE`d programs.

## Call site audit (Phase 1 target list)

Sites that should migrate from direct `fprintf(stderr, ...)` to `runtime_error_hint` (or a new non-halting `runtime_warning_hint` if the call site is fail-soft):

| Site | Current behaviour | Phase 1 action |
|------|-------------------|----------------|
| `basic.c:9785` — DOWNLOAD on native | One-time stderr "DOWNLOAD is a no-op on native builds" | Migrate to `runtime_warning_hint` (non-halting) — gains line context |
| `basic.c:16851` — OPEN fail | `fprintf(stderr, "OPEN: cannot open …");` + sets ST=1 | Migrate to `runtime_warning_hint` — gains line context, keeps ST=1 contract |

Sites that ALREADY use `runtime_error_hint` and should be verified-only (no code change):

- DICTLOAD statement form (lines 8820, 8829, 8835, 8845, 8856)
- DICTLOAD function form (lines 13670, 13680)
- All JSON write/path helper errors when `#OPTION JSON STRICT` (line 10913+)
- Numeric/string type-error sites (lines 4215, 4231)
- DEF FN / READ parser-runtime sites (lines 4266+, 4363+)

## A non-halting variant

`runtime_error_hint` calls `halted = 1` at the end. The OPEN / DOWNLOAD cases need the same line-context block but must NOT halt — they set a status code and continue. Introduce:

```c
/* Same output shape as runtime_error_hint but does not set halted.
 * For soft-failure sites that report-and-continue (OPEN ST=1,
 * DOWNLOAD on native, future HTTP/JSON #OPTION DIAGNOSTICS sites). */
static void runtime_warning_hint(const char *msg, const char *hint);
```

Implementation: factor the existing body of `runtime_error_hint` into a static helper taking a `halt_after` flag, and call it twice from the two public entry points. ~20 lines of refactor, zero behaviour change for the existing `runtime_error_hint` callers.

## Out of scope for this proposal

- Catch/try-style error handling — separate proposal, much bigger surface
- Restructuring HTTP/JSON to halt-by-default on failure — backwards-incompatible, not what Haversack actually wants (they want detection + structured exit, not panic-mode)
- Cross-tool error code taxonomy — Haversack-side concern, separate doc

## Verification plan

`tests/runtime_errors/` (new directory) — one `.bas` per failure shape, each with a `# expect:` comment giving the substring that must appear in stderr and the expected exit code. A small shell driver greps stderr for the expected line and asserts exit. Runs in both native CLI and `basic-wasm` node harness. Ships as part of the Phase 1 diff.

Sample test:

```basic
# expect-stderr: Error on line 20: DICTLOAD: cannot open file
# expect-exit: 1
10 PRINT "before"
20 DICTLOAD "/nonexistent.json", H
30 PRINT "after — should not print"
```

## Estimate

Phase 1: 1 day. Three code changes (`runtime_warning_hint` helper + two migrations), small test corpus, CHANGELOG + retrodocs entry.

Phase 2a: 1 day. `struct line` field + #INCLUDE plumbing + interning. Test corpus updates.

Phase 2b: half day. `LASTERROR$()` + ccall export + retrodocs entry.

Phase 2c: half day. `#OPTION DIAGNOSTICS` plumbing + the 4-6 status-code sites that should emit.

Total if all four phases ship: ~3 days. Phase 1 alone is the wishlist core ask and unblocks Haversack's biggest debugging pain.
