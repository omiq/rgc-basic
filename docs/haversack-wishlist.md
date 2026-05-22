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

## 5. Marked-resolved (historical)

Items move here when shipped or declined, with a one-line "what it was" so the section stays meaningful as a record. No entries yet — this section will fill in over time.
