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

### 1a. Document string-literal escape sequences (2026-05-22)

RGC-BASIC's string parser already supports C/JS-style backslash escapes — `\"`, `\\`, `\n`, `\t`. Verified empirically via the Haversack bare-WASM smoke rig:

| Source | Length | Value |
|---|---|---|
| `"a\"b"` | 3 | `a"b` |
| `"x\ny"` | 3 | `x` + newline + `y` |
| `"\\"` | 1 | `\` |

These don't appear to be documented in `docs/overview.md` or anywhere obvious under `docs/`. The Haversack `docs/TOOLS.md` examples now rely on them (cleaner than `CHR$(34)` concat dance and the SQL-style `""` doubling does NOT work in RGC). If they're public API to rely on, they need a one-page doc; if they're undocumented-and-might-go-away, Haversack needs to fall back to `CHR$(34)`. Confirm + document.

### 1b. CLAUDE.md rule: keep retrodocs / docs.retrogamecoders.com in sync (2026-05-22)

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

### 2c. `DICTDUMP$(handle)` / `BUFFERDUMP$(slot)` — diagnostic snapshots (2026-05-22) — parked

When chasing handle-leak / lifetime bugs in tools, having a way to dump the current slot table state (allocated slots, root types, child counts) as JSON would help. Could share output format with `JSON$(handle)` for the value contents, plus a metadata wrapper. Park until first real handle bug surfaces.

## 3. CI / triage quality of life

Listed in `notehub/docs/TOOLS.md` under "Debugging + triage > RGC-side asks that would make this easier". Replicated here so this wishlist is self-contained:

### 3a. `--json-status` flag on native CLI (2026-05-22)

Final stdout line as structured JSON: `{"exit": N, "reason": "...", "line": N}`. Trivialises CI assertions in any host (bash, node, PHP) and fills in the Haversack auto-report template cleanly.

### 3b. `RGCVERSION$()` builtin (2026-05-22)

Returns the build's version string. Tools and tests can branch on minimum version (`IF RGCVERSION$() < "2.1.3" THEN PRINT "needs 2.1.3+"`). Bug reports compare against runtime version automatically.

### 3c. `ASSERT cond, msg$` primitive (2026-05-22)

Halts with structured exit if `cond` is false. Turns the existing `examples/*.bas` corpus into a regression suite without rewriting them as a separate test framework.

### 3d. Source line in runtime error messages (2026-05-22)

JSON / HTTP / DICT failures should include the originating script line (`DICTLOAD at script.bas:17`). Right now most errors lack the call site, forcing print-debugging to localise. The existing parser-side errors already do this for syntax — extend to runtime failures.

### 3e. `#OPTION HTTP STRICT` (2026-05-22)

Mirrors `#OPTION JSON STRICT`. Tools forget to check `HTTPSTATUS()` constantly; strict mode catches silent fail in tests.

### 3f. `node tests/run-wasm.js script.bas` runner (2026-05-22)

Drives the WASM bundle via emscripten's Node bindings, captures `Module.print`, returns exit code. Same harness shape as the native CLI, so both build targets share one CI matrix.

### 3g. Shared conformance suite (2026-05-22)

Set of `.bas` scripts in `rgc-basic/conformance/` tagged by feature (JSON-read, JSON-write, DICT, HTTP$, HTTPFETCH, FOREACH, etc.). Haversack pulls + runs against its bundled WASM as a regression gate. One regression corpus, both projects benefit, no drift between what RGC tests and what Haversack relies on.

## 4. Runtime / host integration

### 4a. Expose `JSONSTATUS()` and `HTTPSTATUS()` as ccall exports (2026-05-22)

Currently surfaceable only via BASIC code (`PRINT JSONSTATUS()`). A JS host (Haversack, IDE wrappers, etc.) that wants to read the post-run status without modifying the script needs to call into C directly. Suggested exports: `basic_get_jsonstatus`, `basic_get_httpstatus` (both `() -> int`). Cheap — single-line wrapper per function.

Used by Haversack's `web/test/wasm-bare.html` test rig and the planned host-side error-tagged log.

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
