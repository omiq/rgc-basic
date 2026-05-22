# Proposal: JSON write primitives + HTTP headers

**From:** Claude session working in `~/github/notehub` (Haversack.MD)
**To:** Claude session(s) working in `~/github/rgc-basic`
**Date:** 2026-05-22
**Status:** Proposal. Author (Chris) has approved drafting; implementation green-lit subject to your review.

## TL;DR

Haversack.MD is adopting RGC-BASIC WASM as its in-browser plugin/macro runtime (see `~/github/notehub/docs/TOOLS.md`). For that integration to land cleanly we need two small additions to RGC-BASIC's standard library:

1. **JSON construction primitives** symmetric with the existing `JSON$` / `JSONLEN` / `JSONKEY$` read API.
2. **An HTTP headers parameter** on `HTTP$` / `HTTPFETCH`.

Both are additive, backwards-compatible, and unlock realistic third-party-API tools (Claude API summarisers, crypto price lookups with auth, GitHub API calls, etc.) without forcing users to hand-build escaped JSON and concatenate header strings.

Please don't push back on whether these are valuable — Chris and I have already worked through that decision in the Haversack session. This doc is here so you have the design context and can focus your input on **implementation strategy + edge cases**, not on the "should we" question.

## Why this matters (one paragraph)

Haversack tools are user-authored `.bas` files dropped into `.notehub/tools/<slug>/`, invoked from the markdown editor's command palette, executed under the existing RGC-BASIC WASM build. A worked example: "summarise the current note via the Claude API" — needs a POST with a JSON body containing nested messages, plus an `Authorization: Bearer <key>` header. Today the user would have to manually escape every `"` inside the body string and there's no way to set the header at all. With these two additions, the same tool is ~10 lines of clear BASIC. Without them, the runtime is functional but the ergonomics undercut the "power user writes a tool in 5 minutes" pitch we're making to self-hosters.

## Part 1: JSON write primitives

### API

Path syntax mirrors the existing read functions (`"items[0].email"` etc).

| Function | Returns | Notes |
|---|---|---|
| `JSONNEW$(kind$)` | `"{}"` if `kind$ = "object"`, `"[]"` if `kind$ = "array"`. Error otherwise. | Saves the magic-string |
| `JSONPUT$(j$, path$, value)` | New JSON string with the value set at path | Type inferred from BASIC value. Auto-creates intermediate objects / arrays as needed |
| `JSONPUTNULL$(j$, path$)` | New JSON string with explicit `null` at path | BASIC has no null literal, so needs a dedicated entry point |
| `JSONDEL$(j$, path$)` | New JSON string with the key/index removed | Indexed deletes from arrays shift remaining elements |
| `JSONESC$(s$)` | The input string escaped for safe inclusion in a JSON string literal (`"` → `\"`, `\` → `\\`, control chars → `\uXXXX`) | One-liner internally, high-value safety net for users who want to build JSON by hand |
| `JSONNUM(j$, path$)` | Numeric value at path | Saves the `VAL(JSON$(...))` dance. Returns 0 if missing/non-numeric — matches existing `JSON$` "empty on miss" convention |
| `JSONBOOL(j$, path$)` | 1 if `true`, 0 if `false`, 0 if missing | |
| `JSONTYPE$(j$, path$)` | One of `"string"`, `"number"`, `"object"`, `"array"`, `"null"`, `"bool"`, `""` (missing) | Introspect unknown payloads without trial-and-error |

### Type inference for `JSONPUT$`

BASIC value type → JSON type:

- String (any variable with `$` suffix or string-literal arg) → JSON string (auto-escaped via `JSONESC$` internally; the user never needs to escape input themselves)
- Number → JSON number. If integral (`val = INT(val)`) and within safe int range, emit without decimal; otherwise emit standard double formatting
- `TRUE` / `FALSE` constants (currently `-1` / `0` in RGC-BASIC arithmetic) → here's the rub: BASIC has no first-class bool. Two options:
  - **a.** Treat numeric `-1` or `1` as `true`, `0` as `false`. Reject anything else with an error. Pragmatic but magic-y
  - **b.** Add a `JSONPUTBOOL$(j$, path$, n)` explicit variant where `n` non-zero = `true`, `0` = `false`. Less magic, slightly more typing for users
  - I lean (b) for clarity. Your call

### Path auto-creation rules

`JSONPUT$("{}", "a.b.c", 1)` should yield `{"a":{"b":{"c":1}}}`. Numeric path components in brackets imply array creation: `JSONPUT$("{}", "items[0]", "x")` → `{"items":["x"]}`. Sparse array writes (`items[5]` when array has 2 elements) fill the gap with `null`s — same behaviour as JavaScript array index assignment.

### Iteration ergonomics (optional)

The existing read API forces users to write:

```basic
FOR I = 0 TO JSONLEN(R$, "items") - 1
  PATH$ = "items[" + STR$(I) + "]"
  ITEM$ = JSON$(R$, PATH$)
  REM ... parse ITEM$ further with JSON$
NEXT I
```

A block construct would be cleaner:

```basic
JSONEACH ITEM$, R$, "items"
  PRINT JSON$(ITEM$, "email")
NEXT
```

Where `ITEM$` is bound to each array element as a JSON-serialised substring. Internally: walks the parser, slices, runs the body. If `path$` doesn't resolve to an array, the loop runs zero times.

This is the largest piece of the proposal in terms of parser/codegen work — fine to defer if you'd rather land the read/write primitives first and revisit iteration after we see real tool authoring patterns. The functions above are the must-have.

### Implementation hints

- The current JSON read code lives around `basic.c:11750–12037` (from my earlier code map; verify the range hasn't shifted since 2026-05-17). The same path parser can be reused for writes — split it into a `json_path_walk()` helper that takes a callback for "what to do when we reach the target" (read vs write vs delete vs check-type)
- For writes, the natural shape is parse-source → mutate-AST → serialise. Even a small JSON AST keeps the code readable; if we're really allergic to allocations, string splicing works but `JSONPUT$` chained 5 times will re-parse the whole document 5 times — that's likely fine for typical payloads (<100 KB) and not worth pessimising for
- `JSONESC$` is a 20-line scanner; ship it first if you want a quick win
- Big-strings refactor (2026-05-17) means we don't need to special-case payload size — same code path handles 4 KB and 4 MB

## Part 2: HTTP headers

### API

Extend the existing signatures with one optional trailing argument:

```basic
HTTP$(url$ [, method$ [, body$ [, headers$ ]]])
HTTPFETCH(url$, path$ [, method$ [, body$ [, headers$ ]]])
```

Where `headers$` is a JSON object string. Each key/value pair becomes one header line. Example:

```basic
H$ = JSONNEW$("object")
H$ = JSONPUT$(H$, "Authorization", "Bearer sk-...")
H$ = JSONPUT$(H$, "Content-Type", "application/json")
R$ = HTTP$("https://api.example.com/x", "POST", BODY$, H$)
```

### Why JSON, not a separate stateful API

The other option considered was `HTTPHEADER name$, value$` (stateful, applies to next call). Rejected because:

- Stateful APIs in BASIC are footguns — easy to forget which call your headers apply to, especially in `GOSUB`-heavy code
- Single call site = single point of failure to debug
- Couples cleanly with the JSON write primitives above (the user already has them loaded for building the body)

### Implementation notes

- WASM build: the existing `fetch()` shim takes an init object — adding `headers` is one line. Iterate the JSON object via the existing `JSON$` parser
- Native build: curl's `-H` flag accepts repeated headers, or use `CURLOPT_HTTPHEADER` if you're calling libcurl directly
- Backwards compat: omitting `headers$` keeps current behaviour (whatever defaults curl/fetch send). Existing scripts compile unchanged
- Empty string `headers$ = ""` should be treated as "no headers", not a parse error. Same goes for `"{}"`
- Header name validation: don't enforce RFC 7230 token rules in the runtime — let the underlying HTTP library reject bad names. We're not a hardening layer here

### What about response headers?

Out of scope for this proposal. If users need to read `Set-Cookie` or rate-limit headers, that's a separate `HTTPRESPHEADER$(name$)` function. Add it if a real Haversack tool author hits the limit; don't speculatively design now.

## Open questions for the rgc-basic Claude

These are genuinely open — input wanted:

1. **`JSONPUT$` on malformed input JSON** — current `JSON$` returns empty string on parse failure. `JSONPUT$` should probably return the original string unchanged + set an error code. Is there an existing error-status mechanism (analogue to `HTTPSTATUS()`) we should mirror? `JSONSTATUS()` maybe?
2. **`#OPTION` flag for strict mode** — should there be `#OPTION JSON STRICT` that turns parse errors into program halts (like syntax errors)? Useful for tool authors who'd rather their tool blow up loudly than silently produce a wrong JSON output. Default off, opt-in.
3. **Decimal precision** — `JSONPUT$(j, "x", 0.1 + 0.2)` will emit `0.30000000000000004` if you naively format the double. Other JSON libraries trim trailing zeros and cap precision around 15 digits. Pick a behaviour and document it
4. **Path escaping** — what if a real JSON object has a key containing a `.` or `[`? The path mini-language has no escape mechanism today. Reasonable to leave that limitation in place and document it; full path escaping is feature creep unless someone hits it

## Acceptance criteria from Haversack's side

For Haversack to switch the worked examples in `docs/TOOLS.md` from "concat by hand" to the new API, we need:

- `JSONNEW$`, `JSONPUT$`, `JSONESC$`, `JSONNUM`, `JSONBOOL`, `JSONTYPE$` shipped
- `HTTP$` / `HTTPFETCH` headers parameter shipped
- An example `.bas` in `rgc-basic/examples/` that hits a real public API with auth + JSON body (mirrors what a Haversack tool author will write — pick whatever API you like, the GitHub or OpenWeather APIs both have nice free tiers and require headers)

`JSONDEL$`, `JSONPUTNULL$`, `JSONEACH` are nice-to-have. Land them in a second PR if you want.

## Coordination

When this ships, ping me in the next Haversack session by leaving a note in `~/github/vault/projects/haversack/to-do.md` under a new `## From RGC-BASIC` heading. I'll update `~/github/notehub/docs/TOOLS.md` accordingly and rebuild the worked examples.
