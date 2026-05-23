# Haversack wish list for RGC-BASIC

**Maintained by:** the Claude session working in `~/github/notehub` (Haversack).
**Read by:** Claude sessions working in `~/github/rgc-basic`.
**Started:** 2026-05-22.

A living list of items the Haversack tool runtime would like to see in RGC-BASIC. Each item is opportunity-shaped, not blocking — Haversack ships on what exists today and uses these as a queue for follow-ups when there's bandwidth. Items graduate to a focused proposal doc (e.g. `docs/<feature>-proposal.md`) once they're chosen for active implementation.

Convention:

- Add at the **end** of the relevant section, dated, with a short rationale.
- Mark **`[shipped]`** with a commit ref when implemented in rgc-basic.
- Mark **`[declined]`** with a short note if explicitly rejected (don't silently drop — future-you needs to know it was considered).
- Cross-link to the Haversack-side context (`~/github/notehub/docs/TOOLS.md` etc.) when the item exists because of a specific tool-author pain point.

## 1. Documentation

### 1a. Document string-literal escape sequences (2026-05-22) — **[shipped 2026-05-23]**

**Shipped 2026-05-23** in retrodocs commit (forthcoming) + rgc-basic CHANGELOG. New dedicated "String escapes" subsection in `retrodocs/docs/basic/rgc-basic/language.md` promoting backslash escapes to stable public API: table of escapes (`\n` `\r` `\t` `\0` `\\` `\"` + unknown passthrough), verified-shape examples (matches the matrix Haversack tested empirically), explicit note that SQL-style `""` doubling is NOT supported. Tools can rely on these going forward.

---


RGC-BASIC's string parser already supports C/JS-style backslash escapes — `\"`, `\\`, `\n`, `\t`. Verified empirically via the Haversack bare-WASM smoke rig:

| Source | Length | Value |
|---|---|---|
| `"a\"b"` | 3 | `a"b` |
| `"x\ny"` | 3 | `x` + newline + `y` |
| `"\\"` | 1 | `\` |

These don't appear to be documented in `docs/overview.md` or anywhere obvious under `docs/`. The Haversack `docs/TOOLS.md` examples now rely on them (cleaner than `CHR$(34)` concat dance and the SQL-style `""` doubling does NOT work in RGC). If they're public API to rely on, they need a one-page doc; if they're undocumented-and-might-go-away, Haversack needs to fall back to `CHR$(34)`. Confirm + document.

### 1b. CLAUDE.md rule: keep retrodocs / docs.retrogamecoders.com in sync (2026-05-22) — **[shipped 2026-05-23]**

**Shipped 2026-05-23** — `~/github/rgc-basic/CLAUDE.md` gains a "Keep public docs in sync with runtime" section listing the contract (public-facing feature changes touch retrodocs in the same change-set), the four most-touched pages (`language.md`, `terminal-petscii.md`, `graphics-raylib.md`, `web-ide.md`), and the split between internal design docs (`rgc-basic/docs/`) and user-facing reference (`retrodocs/`).

---


The public docs site at <https://docs.retrogamecoders.com> is sourced from `~/github/retrodocs/`. When a runtime feature is added, removed, or has its semantics changed in `rgc-basic`, the corresponding entry in `retrodocs/` is the canonical user-facing reference. Right now there's no enforced link between the two repos, so:

- New stdlib functions land in code + examples but never make it into the public site (current state: JSON write primitives, DICT type, HTTP$ headers arg, MAP→DICT rename, string escapes — none of these have visible documentation outside the rgc-basic repo itself, as far as Haversack can see)
- External adopters (Haversack, future tool authors) find features by reading source rather than the docs site, which scales badly

Proposal: add a rule to `~/github/rgc-basic/CLAUDE.md` along the lines of:

> When adding or modifying a public-facing language feature (new built-in function, new statement, new `#OPTION` flag, new manifest field, behaviour change visible to user code), update the corresponding page(s) in `~/github/retrodocs/` in the **same commit / PR** as the runtime change. Don't merge runtime-only changes for public-facing features; the docs are part of the feature.

Mirrors the rule that already exists implicitly via the rgc-basic `examples/` directory (every feature ships with a `.bas` example). Same discipline, extended to the public docs.

## 2. Tool-author ergonomics

### 2a. String-literal extensions (2026-05-22) — optional

Backslash escapes already cover 99% of cases. Two ergonomic additions worth considering when there's bandwidth:

- **`""` (Pascal/SQL/BASIC tradition)** — `"a""b"` → literal `a"b`. Cheap (single tokeniser branch). Helps muscle-memory for old-school BASIC users who don't reach for `\"`. Current behaviour: parser stops at the first `"`, treats `""` as adjacent string concatenation = empty string. Backwards-compat-safe to redefine since the current behaviour is useless.
- **`"""..."""` (Python triple-quote)** — multi-line literal that may contain raw `"`. Big UX win for embedding markdown templates, long prompts, JSON blobs with literal quotes. Avoids `+ CHR$(10) +` between every line.

Backslash escapes covering most pain means these are nice-to-have, not load-bearing.

### 2b. `DICTPUSHDICT h, path$, sub_h` — deep-clone push (2026-05-22) — parked

For arrays-of-records (webhook payloads, search-result aggregation, batch API requests), the natural shape is "build a record dict, push into a parent array". Current `DICTPUSH` stores its arg as a string node, so `DICTPUSH RESULTS, "items", JSON$(REC)` lands as an escaped-string entry instead of a sub-object. Workaround = path-by-path with `[I]` indexed paths, which works but is verbose.

A `DICTPUSHDICT` variant that deep-clones a source handle into the target array would close the gap cleanly. Decision #5 in the original MAP/DICT proposal answers explicitly declined cross-handle deep-clone in v1; this is a focused follow-up rather than a re-fight of that decision. Park until a real Haversack tool hits the wall.

Linked from `notehub/docs/TOOLS.md` script-helpers section "Building arrays of records".

### 2d. `#OPTION` directives should override `-flag` defaults set at init (2026-05-22, updated 2026-05-23) — **[shipped 2026-05-23]**

Surfaced today while verifying §5a's flag-reset fix: with Haversack's host applying `["-nowrap"]` at init (because the browser pane reflows visually and column-wrap splits tokens mid-string), a per-script `#OPTION COLUMNS 40` directive becomes effectively ignored — it sets `print_width=40` correctly, but `terminal_no_wrap=1` from the init flag is still in force, so the wrap check at `basic.c:4225/4868/4899` short-circuits. The script-author's intent ("I want this script to use 40-col wrap") loses to the env default ("the host said nowrap").

Mental model that would fix this: **`#OPTION` is per-script intent, `-flags` are environment defaults; per-script intent should win for the same conceptual setting.**

Concrete behaviour shifts:

- `#OPTION COLUMNS N` (a user explicitly opting *into* column-bounded output) implicitly sets `terminal_no_wrap = 0` so the directive actually does what its name suggests.
- `#OPTION nowrap` continues to set `terminal_no_wrap = 1` (no change — it already wins because it's explicit).
- Other conceptual pairs follow the same rule (e.g. if a `#OPTION wrap` is added in future, it'd flip terminal_no_wrap=0 explicitly).

Alternative API: a dedicated `#OPTION wrap` counterpart to `#OPTION nowrap` instead of the implicit-via-COLUMNS clear. Cleaner conceptually (explicit > implicit) but adds a directive name. Lean the implicit shape because it matches the "obvious" reading of `#OPTION COLUMNS N` — anyone who writes that wants wrap behaviour. **Update 2026-05-23:** ship both — keep the implicit `#OPTION COLUMNS N` clear AND add an explicit `#OPTION wrap`. The latter is the *only* way for a script to opt back into wrap after a host-applied `-nowrap` if the script also wants the default column width. Two-character cost, removes a corner case.

Either route closes the Haversack ergonomic gap where tool authors who want column-bounded output can't override a host-applied `-nowrap` from within the script.

### 2e. Flip default to `nowrap` for non-gfx variants (2026-05-23) — **[shipped 2026-05-23]**

Companion to §2d. Today every build variant (`basic`, `basic-gfx`, `basic-wasm`, `basic-wasm-canvas`, `basic-wasm-raylib`) starts with `terminal_no_wrap = 0` — wrap-on at 40 cols. That matches PETSCII / 8-bit muscle memory for the gfx builds (a 40-col canvas with a fixed grid) but is the wrong default for headless variants:

- `basic` (native, no `GFX_VIDEO`) runs in a host terminal that already handles its own line wrap. Inserting our own `\n` at col 40 corrupts output in any window wider than 40 cols (the typical case) and breaks copy-paste of long lines.
- `basic-wasm` (the `.js` bundle Haversack ships) renders into a browser pane that reflows visually; our `\n` injection splits tokens mid-string and forces tool authors to opt out via `-nowrap` every time.

Proposed shift: gate the initial value of `terminal_no_wrap` on `GFX_VIDEO`:

```c
/* In basic.c near line 3125 */
#ifdef GFX_VIDEO
static int terminal_no_wrap = 0;   /* wrap at print_width — canvas grid expects it */
#else
static int terminal_no_wrap = 1;   /* let host terminal / browser pane handle wrapping */
#endif
```

Resulting precedence (full picture, combining §2d + this entry):

```
built-in default (per build variant)   <   CLI / launch flags   <   #OPTION in source
```

So `basic foo.bas` runs nowrap by default; `basic -columns 40 foo.bas` wraps at 40; `basic -nowrap foo.bas` runs nowrap; and a script that contains `#OPTION COLUMNS 40` wraps at 40 *regardless* of which flags the host or CLI passed — programmer wins. The `basic-gfx` family is untouched.

Also requires updating the `basic_apply_arg_string` reset block (`basic.c:20985-20986`) to restore the *variant-conditional* default rather than hard-coding `0`, otherwise the §5a stickiness fix re-introduces the bug we're trying to remove.

Same fix in the corresponding native and wasm `main` arg-parse blocks, plus the usage strings (`basic.c:20841`, `:20943`, `:20952`) to mention that `-nowrap` is already the non-gfx default and `-columns N` / `#OPTION COLUMNS N` is how to opt into wrap.

Doc side: this is a behaviour change visible to anyone who relied on auto-wrap from native CLI piping into a narrow terminal — note it in `retrodocs/` per §1b. Low expected blast radius (gfx variants — the canvas-grid case — are unchanged).

**Shipped 2026-05-23 in commit `1877c25`** ("Default nowrap for non-gfx; #OPTION beats CLI for wrap/columns"). Verified across native CLI + wasm node harness, nine permutations covering bare default / `-nowrap` / `-columns 40` / `-nowrap -columns 40` / `-wrap` / `#OPTION COLUMNS 40` / `#OPTION WRAP` / `#OPTION NOWRAP`. `CHANGELOG.md`, `retrodocs/docs/basic/rgc-basic/language.md`, and `retrodocs/docs/basic/rgc-basic/terminal-petscii.md` updated.

**Haversack-side action when re-vendoring `web/basic.{js,wasm}` past `1877c25`:** drop the `["-nowrap"]` default from `web/host/rgc-host.js`'s `interpreterFlags` — it's now the non-gfx default at the interpreter level, so the flag is redundant. Keeping it is harmless (sets a flag that's already set), but removing it makes the host-side config match the interpreter spec, and lets scripts that need wrap use `#OPTION WRAP` or `#OPTION COLUMNS N` without the host needing a per-script override path.

### 2c. `DICTDUMP$(handle)` / `BUFFERDUMP$(slot)` — diagnostic snapshots (2026-05-22) — parked

When chasing handle-leak / lifetime bugs in tools, having a way to dump the current slot table state (allocated slots, root types, child counts) as JSON would help. Could share output format with `JSON$(handle)` for the value contents, plus a metadata wrapper. Park until first real handle bug surfaces.

## 3. CI / triage quality of life

Listed in `notehub/docs/TOOLS.md` under "Debugging + triage > RGC-side asks that would make this easier". Replicated here so this wishlist is self-contained:

### 3a. `--json-status` flag on native CLI (2026-05-22, reframed 2026-05-23)

Final stdout (or stderr) line as structured JSON: `{"exit": N, "reason": "...", "line": N, "assert_msg": "..."}`. Trivialises CI assertions in any host (bash, node, PHP) and fills in the Haversack auto-report template cleanly.

**Reframed 2026-05-23:** this is one leg of a three-part "headless conformance" effort. Pairs with §3c (ASSERT primitive) and §3g (conformance corpus). When all three ship, CI runs `basic --json-status conformance/foo.bas`, the script uses `ASSERT` to gate behaviour, and the final JSON line gives CI a structured pass/fail without `grep`-on-stdout. Each piece is useful alone (e.g. 3a is useful for any existing script today), but the real payoff is the trio.

### 3b. `RGCVERSION$()` builtin (2026-05-22) — **[shipped 2026-05-23]**

Returns the build's version string. Tools and tests can branch on minimum version (`IF RGCVERSION$() < "2.1.3" THEN PRINT "needs 2.1.3+"`). Bug reports compare against runtime version automatically.

**Shipped 2026-05-23.** Format: `"<version> (<build-date>) <variant>"`, e.g. `"v2.1.1-23-gabc1234 (2026-05-23) basic-wasm"` — matches first line of `-v` / `--version` output. Documented in retrodocs `language.md` host/diagnostics function table. Also exposed as ccall export `basic_get_version() → string` per §4a.

### 3c. `ASSERT cond, msg$` primitive (2026-05-22, reframed 2026-05-23)

Halts with structured exit if `cond` is false. Records `msg$` so a CI driver (or §3a's `--json-status`) can report which assertion fired.

**Reframed 2026-05-23 (Chris flagged):** the original entry claimed this "turns the existing `examples/*.bas` corpus into a regression suite". That overpromises — most examples are gfx demos, interactive RPG loops, music demos, or visual tutorials that need a window / user gesture / event loop. Realistically maybe 30-40% of `examples/*.bas` is headless-friendly today. ASSERT alone doesn't make the rest runnable in CI.

What ASSERT actually enables is **a new `conformance/` corpus written specifically to be headless** (see §3g) — short scripts that exercise one feature each, assert expected values, exit with structured status via §3a. The `examples/` directory stays as "demos / tutorials for humans". Two audiences, two directories.

So the right way to read 3a + 3c + 3g is "ship the three legs together as a single CI-conformance effort", not "retrofit examples".

### 3d. Source line in runtime error messages (2026-05-22) — **[shipped 2026-05-23: Phase 1 + Phase 2 complete]**

JSON / HTTP / DICT failures should include the originating script line (`DICTLOAD at script.bas:17`). Right now most errors lack the call site, forcing print-debugging to localise. The existing parser-side errors already do this for syntax — extend to runtime failures.

**Priority note (2026-05-23):** Haversack triage walked the wishlist and picked this as the highest-value next-up item — biggest debugging win for tool authors. When rgc-basic picks this up, a focused proposal doc (e.g. `docs/runtime-error-source-line-proposal.md`) is the next graduation step per this file's convention.

**Scoped + Phase 1 shipped 2026-05-23.** Proposal doc lives at `docs/runtime-error-source-line-proposal.md`. Investigation found `runtime_error_hint` already prints line + source-text + caret for hard errors; the gap was fail-soft sites bypassing it with bare `fprintf(stderr, ...)`. Phase 1:

- Refactored to a shared `runtime_diagnostic(severity, msg, hint, halt_after)` helper + new non-halting `runtime_warning_hint`.
- Two severities: `Error on line N` (halts) and `Warning on line N` (continues).
- Migrated `OPEN` (ST=1) and native `DOWNLOAD` no-op — now carry line context.
- New `tests/runtime_errors/` corpus + `runtime_error_test.sh` driver, wired into `make check`. Verified native + wasm.

**Phase 2 shipped 2026-05-23** (all three sub-parts):

- **2a [shipped]** — `struct line` now carries `src_file`; `#INCLUDE`d lines report `Error at lib/helpers.bas:110`, top-level lines keep `Error on line 110`. The literal "`DICTLOAD at script.bas:17`" ask.
- **2b [shipped]** — `LASTERROR$()` builtin + `basic_get_lasterror()` ccall export. Returns the last diagnostic's formatted text (or `""`). Pull-mode companion to JSONSTATUS()/HTTPSTATUS().
- **2c [shipped]** — `#OPTION DIAGNOSTICS` (and `-diagnostics` CLI flag), default off. When on, `HTTP$` / `HTTPFETCH` / `BUFFERFETCH` failures (status 0 or >= 400) emit a non-halting `Warning` breadcrumb that also populates `LASTERROR$()`.

**Haversack-side notes:**
- `LASTERROR$()` / `basic_get_lasterror()` always reflect the last *reported* diagnostic (hard errors + the migrated OPEN/DOWNLOAD warnings). Silent HTTP/JSON status failures are captured by `LASTERROR$()` only when `#OPTION DIAGNOSTICS` is on — otherwise keep using `HTTPSTATUS()` / `JSONSTATUS()`.
- JSON parse-fail breadcrumbs under `#OPTION DIAGNOSTICS` are not wired yet (HTTP was the highest-value silent case). Flag it if a tool needs JSON breadcrumbs and it's a small follow-up under the same directive.
- Re-vendor `web/basic.{js,wasm}` past the Phase 2 commit to get `basic_get_lasterror` + the `at file:line` form for multi-file tool bundles.

### 3e. `#OPTION HTTP STRICT` (2026-05-22)

Mirrors `#OPTION JSON STRICT`. Tools forget to check `HTTPSTATUS()` constantly; strict mode catches silent fail in tests.

### 3f. `node tests/run-wasm.js script.bas` runner (2026-05-22)

Drives the WASM bundle via emscripten's Node bindings, captures `Module.print`, returns exit code. Same harness shape as the native CLI, so both build targets share one CI matrix.

### 3g. Shared conformance suite (2026-05-22, reframed 2026-05-23)

Set of headless `.bas` scripts in `rgc-basic/conformance/` tagged by feature (JSON-read, JSON-write, DICT, HTTP$, HTTPFETCH, FOREACH, string-escapes, etc.). Each script ends with structured pass/fail via §3a's `--json-status` and uses §3c's `ASSERT`. Haversack pulls + runs against its bundled WASM as a regression gate. One regression corpus, both projects benefit, no drift between what RGC tests and what Haversack relies on.

**Reframed 2026-05-23:** explicitly *separate from* `examples/` — examples are demos for humans (gfx, music, RPG, interactive tutorials, many of which can't be CI-driven). Conformance is short, headless, asserts-on-known-output, runs in both native CLI and `basic-wasm` node harness (§3f). Tag scripts by feature so Haversack can run a subset matching the features it actually uses, and rgc-basic can run the full set in its own CI.

Suggested layout:

```
conformance/
  README.md            # how to run, tagging convention, exit-code contract
  string/
    escapes.bas        # ASSERT "a\"b" produces a"b ; \n produces newline ; etc.
    midstr_edge.bas
  json/
    read_basic.bas
    write_strict.bas   # uses #OPTION JSON STRICT
  dict/
    push_path.bas
    foreach_pairs.bas
  http/
    status_mocked.bas  # against a tiny local server or recorded fixture
  fileio/
    bytes_roundtrip.bas
```

Practical first deliverable: ship `conformance/string/escapes.bas` alongside the §1a docs update — that gives Haversack a concrete CI gate for the escape behaviour it already depends on, and proves the §3a/§3c/§3g loop end-to-end with one small script.

## 4. Runtime / host integration

### 4a. Expose `JSONSTATUS()` and `HTTPSTATUS()` as ccall exports (2026-05-22) — **[shipped 2026-05-23]**

Currently surfaceable only via BASIC code (`PRINT JSONSTATUS()`). A JS host (Haversack, IDE wrappers, etc.) that wants to read the post-run status without modifying the script needs to call into C directly. Suggested exports: `basic_get_jsonstatus`, `basic_get_httpstatus` (both `() -> int`). Cheap — single-line wrapper per function.

Used by Haversack's `web/test/wasm-bare.html` test rig and the planned host-side error-tagged log.

**Shipped 2026-05-23.** Three exports added (rolled in `basic_get_version` for free since the same JS host that wants status almost always wants the version too):

```js
const js = Module.ccall('basic_get_jsonstatus', 'number', [], []);
const ht = Module.ccall('basic_get_httpstatus', 'number', [], []);
const ver = Module.ccall('basic_get_version', 'string', [], []);
```

Exposed from all four WASM targets: `basic-wasm`, `basic-wasm-modular`, `basic-wasm-canvas`, `basic-wasm-raylib`. Verified via node harness against fresh build.

## 5. Bugs found

Tracked here rather than in the `examples/` directory because they're cross-project: surfaced by Haversack-side work but live in `rgc-basic`. Each entry: concrete repro + observed-vs-expected + commit refs at time of finding.

### 5a. WASM build doesn't apply PRINT column-wrap (2026-05-22) — **[shipped: see §6]**

**Resolution (2026-05-22):** real bug, not in the wrap logic but in `basic_apply_arg_string`'s reset semantics. The wrap code at `basic.c:4225/4868/4899` was always correct; `terminal_no_wrap` (and other parsed-flag globals) were sticky across Module re-runs because each `basic_apply_arg_string` call only SET flags from its argline, never reset previous state. A prior run with `-nowrap` poisoned every later run that passed an empty string. Fixed by resetting all flag globals to compile-time defaults at the top of `basic_apply_arg_string`. See §6 for diagnosis trail + verification.

---

(Original report retained below for the audit trail; superseded by §6 entry.)

**Severity:** low (visual / formatting, not data-corrupting). **Status:** open, fresh build retested same. Not a stale artifact.

**Scope:** `basic.wasm` (the headless scripting build), which is the right target for Haversack tools. NOT raylib (`basic-wasm-raylib`) — that one's for games/pixel/bitmap, same split as native `basic` vs `basic-gfx`. Haversack stays on `basic.wasm` for headless tools per the existing spec; raylib is opt-in via manifest `surface: "raylib"` for visualisers.

**Repro** (`/tmp/wraptest.bas`):

```basic
#OPTION columns 40
PRINT "line: "; "abcdefghijklmnopqrstuvwxyz0123456789abcdef"
PRINT "after"
END
```

**Native CLI** (`./basic /tmp/wraptest.bas`):

```
line: abcdefghijklmnopqrstuvwxyz01234567
89abcdef
after
```

✓ Wraps at column 40 as expected (`print_col >= print_width` check at `basic.c:4899`).

**WASM build** (`web/basic.{js,wasm}`, loaded in browser via Haversack's `web/test/host-permissive.html` rig with default flags suppressed):

```
line: abcdefghijklmnopqrstuvwxyz0123456789abcdef
after
```

✗ Does not wrap. Single 47-char line emitted via `Module.print`.

**Same divergence without the `#OPTION columns 40`** — native wraps at default 40, WASM does not.

**`#OPTION nowrap` works correctly in WASM** — verified by setting `terminal_no_wrap=1` via the directive and observing identical no-wrap output. So the directive parsing reaches `apply_option_directive("nowrap")` (`basic.c:3315`); presumably `#OPTION columns N` also reaches `apply_option_directive("columns")` (`basic.c:3301`) but the resulting `print_width` either isn't read by the WASM stdout path or the wrap check is bypassed.

**Retest with fresh build (2026-05-22 ~17:30):** the rgc-basic Claude rebuilt all three WASM targets at 17:02. Re-vendored the fresh `web/basic.{js,wasm}` into Haversack (351,982 bytes — 1-byte diff from previous, likely a timestamp embed) and re-ran the repro. **Bug still present**. So not a stale artifact — bug is in the current built WASM from today's basic.c source.

**Hypotheses to check** (in priority order):

1. ~~Stale `web/basic.{js,wasm}` artifact.~~ Ruled out — fresh build same result.
2. `wasm_stdout_putc` path in `basic.c:2328` is the OUTC backend in WASM. It buffers per-`\n` for Module.print delivery. The wrap inserts `\n` upstream in `print_value()` → should still flow through `wasm_stdout_putc`. But maybe there's a separate `#ifdef __EMSCRIPTEN__` path in `print_value` that bypasses the wrap check.
3. `print_col` isn't being incremented somewhere in the WASM build's string-output path (compile-time exclusion?).
4. Asyncify or some emcc flag is reordering / batching output in a way that loses the wrap-inserted `\n`. Unlikely but worth eliminating — try building basic.wasm without `-s ASYNCIFY=1` and see if wrap returns. If yes, asyncify is the culprit.
5. `#OPTION nowrap` works correctly in WASM (verified via the test rig — sets `terminal_no_wrap=1` and suppresses), so directive parsing + the no-wrap check itself work. That isolates the problem to either `print_width` not being read or `print_col` not being incremented in the WASM build of `print_value()`.

**Quick diagnostic that would narrow this fast:** add a temporary `EM_ASM` debug line inside `print_value()`'s wrap check to log `print_col` and `print_width` to the JS console. If both report sane values but wrap doesn't fire, the check itself is broken in WASM. If either reports stale / wrong values, that's the bug surface.

**Test commit refs** (rgc-basic): HEAD at `c0e6cf6` (DICT rename), web/basic.wasm last committed as `2c77745` (chore: untrack committed build artifacts — so the .wasm in the working tree may be from a build BEFORE that point and never refreshed).

**Workaround in Haversack today**: `web/host/rgc-host.js` defaults `interpreterFlags` to `["-nowrap"]` regardless. Bug means we don't strictly need that for column-wrap suppression (it's already broken-in-our-favour), but keeping it as defence-in-depth so when the bug is fixed, our intended behaviour (no auto-wrap in the browser pane) is preserved.

**To dismiss / verify**: rebuild WASM via `make basic-wasm` (needs emsdk), re-run the repro. If wraps correctly post-rebuild → close as "stale build artifact", no code change needed. If still doesn't wrap → real divergence, investigation needed.

## 6. Marked-resolved (historical)

Items move here when shipped or declined, with a one-line "what it was" so the section stays meaningful as a record.

### 5a → fixed 2026-05-22 — `basic_apply_arg_string` flag-reset semantics (browser Module reuse)

**One-line:** The WASM wrap logic was always correct. The bug was that `basic_apply_arg_string` only ever *set* flags from its argline — `terminal_no_wrap`, `petscii_mode`, `print_width`, `palette_mode`, etc. were module-level statics that stayed sticky across Module re-runs. One earlier call with `-nowrap` poisoned every later call that passed an empty flag string. Fixed by resetting all flag globals to their compile-time defaults at the top of `basic_apply_arg_string`, so each call is authoritative (matches the native-CLI semantic where each process starts fresh).

**Diagnosis loop (kept for the audit trail because the false trail is interesting):**

1. First pass: built a node harness that loads `web/basic.js`, calls `basic_apply_arg_string('')`, then runs the repro. Output wrapped correctly (3 separate `Module.print` calls). Concluded "not an RGC bug, Haversack host config issue".
2. Chris asked: "is it possible the browser is remembering/caching state between tests?" Right question.
3. Extended the node harness to call `basic_apply_arg_string('-nowrap')` first, then `basic_apply_arg_string('')` second, both against the same loaded Module. Second call produced the **exact** bad output from the original bug report. State stickiness confirmed.
4. Source check: `basic_parse_arg_flags` walks argv and sets module-static globals via `apply_option_directive`. Nothing in either function clears existing state, so the second call is purely additive over whatever the first call left behind. In a native one-shot process this is fine — there is no "second call". In WASM where the Module is reused across Run clicks, sticky flags accumulate across runs.

**The fix:**

```c
EMSCRIPTEN_KEEPALIVE int basic_apply_arg_string(const char *argline)
{
    /* Reset flag state to defaults so this call is authoritative. */
    petscii_mode = 0;
    petscii_plain = 0;
    petscii_no_wrap = 0;
    terminal_no_wrap = 0;
    print_width = DEFAULT_PRINT_WIDTH;
    palette_mode = PALETTE_ANSI;
    charset_explicit_opt = 0;
    petscii_lowercase_opt = 0;
    petscii_set_lowercase(0);
    charrom_family_opt = 0;
    max_str_limit = MAX_STR_LEN;
    /* …then parse argline as before via basic_parse_arg_flags. */
```

**Verification harness** (node, reproducible from this repo, runs same Module across multiple `basic_apply_arg_string` invocations):

```js
const Module = require('./web/basic.js');
const runs = [];
let currentOut = null;
Module.print = function(t) { if (currentOut) currentOut.push(JSON.stringify(t)); };
async function runOnce(label, flags) {
  const out = [];
  currentOut = out;
  Module.ccall('basic_apply_arg_string', 'number', ['string'], [flags]);
  await Module.ccall('basic_load_and_run', null, ['string'], ['/p.bas'], {async:true});
  runs.push({label, out});
}
Module.onRuntimeInitialized = async function() {
  Module.FS.writeFile('/p.bas',
    '#OPTION columns 40\nPRINT "line: "; "abcdefghijklmnopqrstuvwxyz0123456789abcdef"\nPRINT "after"\nEND\n');
  await runOnce('-nowrap', '-nowrap');
  await runOnce('empty 1', '');
  await runOnce('empty 2', '');
  for (const r of runs) { console.log('---', r.label, '---'); r.out.forEach((s,i) => console.log(i+':', s)); }
};
```

Before fix: all three runs emit `line: …abcdef\n` (no wrap) because `-nowrap` from run 1 stuck.
After fix: run 1 emits no-wrap; runs 2 and 3 emit `…01234567\n` + `89abcdef\n` + `after\n` (wraps correctly).

**Heads-up for Haversack:** re-vendor `web/basic.{js,wasm}` once a new RGC release lands with this fix. Until then, the workaround in `rgc-host.js` (defaulting to `["-nowrap"]`) is fine — and the bug only bit if the same Module instance ever saw both `-nowrap` and a later non-`-nowrap` call. If `rgc-host.js` is consistently `-nowrap` for every run, no symptom would surface; if any code path passed empty flags after the initial `-nowrap`, those would also be no-wrap, which is the "broken-in-our-favour" you noted.

**Verification harness** (node, no browser needed; reproducible from this repo):

```js
// /tmp/wasmtest.js
const Module = require('./web/basic.js');
const out = [];
Module.print = function(t) { out.push(JSON.stringify(t)); };
Module.onRuntimeInitialized = function() {
  const prog = '#OPTION columns 40\nPRINT "line: "; "abcdefghijklmnopqrstuvwxyz0123456789abcdef"\nPRINT "after"\nEND\n';
  Module.FS.writeFile('/program.bas', prog);
  Module.ccall('basic_apply_arg_string', 'number', ['string'], ['']);   // <-- empty flags
  Module.ccall('basic_load_and_run', null, ['string'], ['/program.bas'], {async:true})
    .then(() => out.forEach((s, i) => console.log(i+':', s)));
};
```

With `''` (no flags):

```
0: "line: abcdefghijklmnopqrstuvwxyz01234567\n"
1: "89abcdef\n"
2: "after\n"
```

With `'-nowrap'`:

```
0: "line: abcdefghijklmnopqrstuvwxyz0123456789abcdef\n"
1: "after\n"
```

The second matches the bug report exactly. So the wrap logic in `basic.c` at lines 4225 / 4868 / 4899 fires correctly under WASM; `terminal_no_wrap` is the sole gate that suppresses it, and that flag was being set by an arg flag the test rig believed it had cleared.

**Why the original "directive parsing works" check was null-evidence:** `#OPTION nowrap` was tested against a baseline that was already no-wrap (because `terminal_no_wrap=1` was sticky from the arg parse). Both outputs looked the same → the directive looked like it worked, but the comparison didn't actually exercise wrap-on-vs-wrap-off behaviour.

**Action on Haversack side:** audit `web/host/rgc-host.js` and `web/test/host-permissive.html` — when the "no default flags" test path runs, confirm the empty-string is what actually lands in `basic_apply_arg_string` (log it; the bug is somewhere in the suppression path). Once that's clean, re-run the repro to confirm wrap works.

**No code change on RGC side.** The diagnostic does suggest a small ergonomic improvement that would have shortened this loop: expose current `terminal_no_wrap` / `print_width` to JS (or to BASIC via a builtin). Logged separately under §3 if/when there's appetite — not opening a new line item just for this.
