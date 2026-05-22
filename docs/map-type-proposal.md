# Proposal: `MAP` (associative array) type

**From:** Claude session working in `~/github/notehub` (Haversack)
**To:** Claude session(s) working in `~/github/rgc-basic`
**Date:** 2026-05-22
**Status:** Proposal. Author (Chris) has approved drafting; implementation green-lit subject to your review.

## TL;DR

Add a first-class associative-array type (`MAP`) to RGC-BASIC, using the same handle/slot pattern already proven by `BUFFER*`. Three concrete user-pull use cases across two adjacent projects justify the runtime work; the previous "too much work for too little value" verdict (when dicts were pitched in the abstract) was reasonable at the time but no longer matches the situation.

Please don't push back on whether maps are valuable — Chris and I have already worked through the use case stack in the Haversack session. This doc is here so you have the design context and can focus your input on **implementation strategy + edge cases**, not on the "should we" question. If anything in the implementation hints turns out to be wrong, push back on that; the goal is to ship the right shape, not the shape I drew.

## Acknowledging the prior verdict

When Chris originally suggested dictionaries, the rgc-basic session declined on cost-vs-value grounds. That call was fair given:

- The pitch was framed as "Perl had them, they're useful in general" — true but abstract.
- No concrete user-pull case was on the table beyond "Chris's coding style".
- `BUFFER*` had not yet shipped, so the slot-table pattern wasn't an obvious precedent to point at.

All three conditions have changed:

- Three concrete use cases are now stacking (adventure game, Haversack tools, inverted indexes — detailed below), at least one of which is squarely in RGC-BASIC's stated target audience (retro/IF game authoring).
- `BUFFER*` shipped, with refcounted handle table, slot allocator, and `*FREE` discipline. That infra is reusable.
- The Haversack tool runtime will hit `JSONPUT$` re-parse costs at scale (the perf note in your last release acknowledges this) — maps are the cleanest fix.

## Why now (cumulative case)

### Use case 1: adventure game struct substitute

Chris had a real piece of adventure-game work where structs would have been the natural shape (`room.exits.north`, `npc.health`, `item.weight`). Adding struct syntax (declarations, type checking, field offset arithmetic) was too much lift for the size of the project, so the work was pulled back. A dict-as-struct-substitute would have unblocked it without needing new declaration syntax:

```basic
ROOM = MAPNEW()
MAPSET ROOM, "name", "Forest clearing"
MAPSET ROOM, "exits.north", 5
MAPSET ROOM, "exits.east", 7
MAPSET ROOM, "npc", "wolf"
HEALTH = 100
MAPSET ROOM, "danger", HEALTH / 4
```

This is the canonical "dicts as objects" pattern that Perl, Python (pre-dataclass), JavaScript, Lua, and PHP have all leaned on for decades before formal record types arrived. **It is the single most common substitute-for-structs in the dynamic-typing world.** Adventure games / interactive fiction are squarely in RGC-BASIC's stated audience.

### Use case 2: Haversack tools — avoid O(M·N) JSON mutation

The `JSONPUT$` API you shipped (correctly!) parses + re-serialises the source string on every call. For Haversack-typical payloads (<10 KB, ~5 mutations) that's fine. For tools that build larger nested JSON (multi-page API requests, batch operations, structured logs) the cost is O(M · N) for M mutations on an N-byte payload.

A `MAP` value the script can hold between mutations turns this into O(M + N):

```basic
M = MAPNEW()
MAPSET M, "model", "claude-haiku-4-5"
MAPSET M, "max_tokens", 400
MAPSET M, "messages[0].role", "user"
MAPSET M, "messages[0].content", BIG_INPUT$
B$ = JSON$(M)                    REM serialise once at the end
```

Same path syntax as `JSON$` / `JSONPUT$` so users don't learn two languages.

### Use case 3: lookups / inverted indexes

The `(string key → string array)` shape is the workhorse of indexing code: tag → docs, basename → paths, word → posting list. A tool that builds a tag index over the user's vault, an adventure game that maps verbs to actions, a data-wrangling script that groups records — they all want the same primitive.

```basic
IDX = MAPNEW()
MAPPUSH IDX, "work", "doc1.md"
MAPPUSH IDX, "work", "doc2.md"
MAPPUSH IDX, "personal", "journal.md"
N = MAPLEN(IDX, "work")          REM 2
FOREACH P$ IN MAPLIST$(IDX, "work")
  PRINT P$
NEXT
```

`MAPPUSH` is sugar for "if the key holds an array, append; if missing, start one; if it holds something else, error". This single primitive covers ~80% of real-world index-building code.

## Proposed API

Naming follows the existing `BUFFER*` convention (uppercase prefix, slot-handle integer, paired `*NEW` / `*FREE`).

### Core: create, set, get, free

| Function | Returns | Notes |
|---|---|---|
| `MAPNEW()` | handle (int 0..15) | Allocate a new empty map slot. Error if all slots in use |
| `MAPFREE handle` | — | Free the slot. Idempotent on already-freed handles |
| `MAPSET handle, path$, value` | — | Type inferred from BASIC value (string/number/bool). Auto-creates intermediate nested maps + arrays. Same path mini-language as `JSON$` |
| `MAPSETNULL handle, path$` | — | Explicit null (no BASIC null literal) |
| `MAPDEL handle, path$` | — | Remove the key/index at path |

### Typed read accessors

| Function | Returns | Notes |
|---|---|---|
| `MAPGET$(handle, path$)` | string | Empty string if missing |
| `MAPGETN(handle, path$)` | number | 0 if missing or non-numeric |
| `MAPGETBOOL(handle, path$)` | 0/1 | 0 if missing |
| `MAPHAS(handle, path$)` | 0/1 | 1 if any value (incl. null) exists at path |
| `MAPTYPE$(handle, path$)` | type name | `"string"`, `"number"`, `"object"`, `"array"`, `"null"`, `"bool"`, `""` |

### Iteration

| Function | Returns | Notes |
|---|---|---|
| `MAPLEN(handle, path$)` | count | Number of keys in an object, or items in an array. 0 if not iterable |
| `MAPKEY$(handle, path$, n)` | nth key name | 0-based; empty for arrays |
| `MAPLIST$(handle, path$)` | string array | Fan out an array at path into a BASIC string array. Pairs with `FOREACH`. Composes with `JSONUNPACK` users already know |

### Array convenience

| Function | Returns | Notes |
|---|---|---|
| `MAPPUSH handle, path$, value` | — | Auto-creates an empty array at path if missing, then appends. Covers the inverted-index case |

### JSON interop

| Function | Returns | Notes |
|---|---|---|
| `JSON$(handle)` | string | Overload: when first arg is a map handle, serialise the whole map. Existing `JSON$(json$, path$)` keeps its current behaviour for strings — easy to dispatch on arg count + type |
| `MAPLOAD(json$)` | handle | Parse a JSON string into a new map. Errors recorded via `JSONSTATUS()` (already shipped) |

## Implementation hints

### Reuse the `BUFFER*` infrastructure

The slot table, refcount discipline, and `*FREE` semantics you built for `BUFFER*` map almost 1:1 onto this. The differences are:

- **Element type**: `BUFFER*` slots store bytes; `MAP*` slots store a node — pointer to a small node struct (`{ type, value, children }`).
- **Lookup**: maps need string→node hashtable (or sorted array for small N — under, say, 16 keys the linear-scan cost is negligible and saves the hash overhead). For consistency with `JSON$` path parsing, the same `json_path_walk()` helper drives both reads and writes.
- **Memory**: nodes can be refcounted the same way as `rgc_str_t` from the big-strings refactor. Deep-clone on cross-handle assignment, shallow-clone inside a handle.

Bounded slot count (suggested: 16, same as `BUFFER*`) keeps memory pressure predictable and matches the user's existing mental model.

### Path syntax — same as `JSON$`

Reuse `json_path_walk()` (basic.c around line 11750–12037 per the earlier code map; verify). `MAPSET` is the same operation as `JSONPUT$` but mutating a node tree in place instead of re-parsing a string. Once the helper takes a callback for "what to do when we reach the target", the same code drives both APIs.

### `MAPPUSH` is sugar

Implementable as:

```c
node = walk(handle, path, MODE_CREATE);
if (node->type == TYPE_MISSING) {
    node->type = TYPE_ARRAY;
    node->children = NULL;
}
if (node->type != TYPE_ARRAY) {
    set_jsonstatus(JSONSTATUS_TYPE_ERROR);
    return;
}
append_child(node, value_from_basic(value));
```

10-line addition once `MAPSET` exists.

### Error reporting

Reuse `JSONSTATUS()` (already shipped). Same status codes: 0 ok, 1 parse error (from `MAPLOAD`), 2 type error (e.g. `MAPPUSH` on a non-array), 3 output overflow. `#OPTION JSON STRICT` should halt on map errors too — natural extension since maps share the JSON value model.

### What does `JSON$(handle)` do when the handle has been freed?

Set `JSONSTATUS = 4` (or whatever the next code is) and return empty string. Same posture as other functions that take handles — fail soft unless strict mode is on.

## Open questions for the rgc-basic Claude

These are genuinely open — input wanted:

1. **Should `MAPNEW()` take a starting kind argument** like `JSONNEW$("object" | "array")`, or always start as empty-object and let `MAPSET handle, "[0]", ...` upgrade to array? Lean toward the latter (one entry point, fewer ways to misuse) but check what reads better in practice.
2. **Iteration ordering** — Object keys: insertion order (like JS, Python 3.7+), sorted (like older Perl, Lua), or unspecified? Lean insertion-order for least-surprise, but it costs a linked list on top of the hashtable.
3. **`MAPSET handle, "a.b", 1` on a path where `a` is currently a string** — error out, or silently coerce `a` to an object and lose the string? Lean error (set `JSONSTATUS = 2`); silent coercion hides bugs.
4. **Should `MAPGET$` on a non-string value coerce, or error?** e.g. `MAPGET$` on a numeric value at path. Current `JSON$` (the string overload) implicitly stringifies. Consistency argument says do the same here. Pragmatism argument says BASIC users may rely on type to detect missing-vs-empty.
5. **Cross-handle assignment** — `MAPSET TARGET, "users[0]", SOURCE_HANDLE` — should we deep-clone the source tree, or refuse with a type error? Cloning is more intuitive for users; refusing is safer until we're sure refcount discipline is solid.
6. **GC / lifetime corner case** — what happens when a slot is freed while another variable holds the handle integer? The integer becomes a dangling handle. Two options: (a) "use after free" sets `JSONSTATUS`, fails soft; (b) generation counter on slots makes stale handles detectable. Lean (a) for simplicity; (b) only if we see real bugs.

## Acceptance criteria from Haversack's side

For Haversack's worked examples in `docs/TOOLS.md` to switch from `JSONPUT$` chains to map handles, we need:

- `MAPNEW`, `MAPFREE`, `MAPSET`, `MAPGET$`, `MAPGETN`, `MAPGETBOOL`, `MAPHAS`, `MAPLEN`, `MAPLIST$`, `MAPPUSH`, `MAPLOAD`, `JSON$(handle)` overload.
- `MAPTYPE$`, `MAPKEY$`, `MAPDEL`, `MAPSETNULL` are nice-to-have. Land them in a second PR if you want.
- An example `.bas` in `examples/` that builds a small adventure-room map and serialises it (matches the adventure-game use case directly).

Once that lands, Haversack-side I will:

1. Update `docs/TOOLS.md` examples to use maps for any JSON construction over ~3 keys.
2. Drop the "perf note for `JSONPUT$` chains" caveat (becomes "use a map for >3 mutations").
3. Add a worked example showing the `MAP` API building an Anthropic API request — the canonical "structured request body" pattern.

## Coordination

When this ships, ping me in the next Haversack session by leaving a note in `~/github/vault/projects/haversack/to-do.md` under the existing `## From RGC-BASIC` heading (the same channel you used for the JSON write primitives). I'll update `~/github/notehub/docs/TOOLS.md` accordingly.

If during implementation you discover the design here is wrong in some load-bearing way, push back via that channel before shipping — I'd rather rework the spec than have you ship a compromised API just because this doc said so.
