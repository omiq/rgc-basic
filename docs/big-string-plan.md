# Big strings — length-prefixed, heap-backed string representation

Status: **proposed** (2026-05-12).

Relationship to BUFFER: `docs/buffer-type-plan.md` Step 1 already SHIPPED
(`BUFFERNEW` / `BUFFERFETCH` / `BUFFERFREE` / `BUFFERLEN` / `BUFFERPATH$`),
working around the 4 KB cap by routing big payloads through a MEMFS file.
Big strings attack the same problem at the root: refactor `struct value`
so strings themselves can grow past 4 KB. The two coexist — BUFFER stays
the right tool for streaming chunked file I/O on bounded RAM; big strings
removes the *force* to reach for BUFFER whenever `HTTP$` truncates.

## TL;DR

Replace inline `char str[MAX_STR_LEN]` in `struct value` with a pointer to a
heap-allocated, length-prefixed, reference-counted string object. BASIC surface
is unchanged. Side effects:

- `HTTP$()` and friends stop truncating at 4 KB.
- Embedded NUL bytes round-trip (fixes `\0`, BUFFER binary I/O, raw PETSCII).
- `struct value` shrinks ~4116 → ~24 bytes; locals, arrays, stack frames,
  and `data_items[]` all get proportionally cheaper.
- `#OPTION maxstr N` becomes a *runtime cap*, not a compile-time buffer size.

## Problem

`struct value` (basic.c:1385) is the universal expression-result type:

```c
struct value {
    int type;
    double num;
    char str[MAX_STR_LEN];   /* 4096 bytes — load-bearing for the whole evaluator */
};
```

Every local in `eval_expr`, every array slot, every `data_items[]` entry, every
saved UDF parameter carries the full 4 KB inline. That makes:

1. Raising `MAX_STR_LEN` infeasible — doubling it doubles every stack frame
   and every array allocation.
2. `HTTP$(url)`, `JSON$(...)`, file reads, and shell-`SYS$` calls silently
   truncate at byte 4095.
3. Embedded NULs in string literals (`"X\0Y"`) get cut by `strcpy`/`strlen`
   downstream of the value (basic.c:196-199 / to-do.md:170-201).

The previously-proposed BUFFER plan (`docs/buffer-type-plan.md`) sidesteps the
problem with a MEMFS file slot. Works, but is a parallel data type: users have
to know when to reach for it, and string intrinsics (`INSTR`, `JSON$`,
`SPLIT`) don't apply directly. This plan fixes the root cause instead.

## Non-goals

- **No new BASIC syntax.** No `DIM AS STRING`, no `BIGSTRING$`, no `&`
  sigil. Existing `A$ = "..."` semantics stay.
- **No removal of `#OPTION maxstr`.** Portability lint, C64-target tests, and
  memory-budget guards still need a runtime cap. Default stays 4096 (so
  existing tests don't suddenly slurp 1 GB of HTTP into RAM). `#OPTION maxstr
  unlimited` or `0` lifts it for desktop/wasm.
- **No small-string optimization in v1.** Inline-16-byte SSO is tempting but
  doubles the matrix of code paths. Park as a follow-up if profiling shows
  short-string churn dominates.
- **No string views / slicing aliasing.** `MID$` still allocates a fresh
  string. Aliasing would force COW on every write site; not worth the
  complexity vs the win.
- **Surface compatibility unchanged.** Every existing test must pass with
  zero `.bas` edits.

## Design

### Heap object

```c
typedef struct rgc_str {
    int refcount;       /* >=1 live; 0 freed; INT_MAX for empty singleton */
    size_t len;         /* logical length in bytes, NUL-safe */
    size_t cap;         /* allocated capacity (excluding the +1 NUL guard) */
    char data[];        /* flex array; always NUL-terminated at data[len] for legacy callers */
} rgc_str_t;
```

- `data` is always NUL-terminated at `data[len]` so legacy C helpers that take
  `const char *` keep working *for strings that contain no embedded NULs*.
  Embedded-NUL safety is opt-in: code that needs it uses `rgc_str_len()` and
  `rgc_str_data()` instead of `strlen` / pointer arithmetic.
- `cap` grows with `roundup_pow2(len + 1)`. Free list optional; not v1.
- A static `rgc_str_empty` singleton avoids allocation for `""` literals and
  `make_num` (which currently zeroes `out.str[0]`).

### Value struct

```c
struct value {
    int type;
    double num;
    rgc_str_t *str;     /* NULL or pointer to heap str; NULL == empty for VAL_NUM */
};
```

Size drops from ~4116 → ~24 bytes (8-byte alignment, 64-bit). Every consumer
(arrays, `data_items`, UDF saved params, eval scratch) wins automatically.

### Refcount + copy-on-write

- `rgc_str_ref(s)` → `s->refcount++`.
- `rgc_str_unref(s)` → decrement, free at zero (skip on empty singleton).
- Assignment (`B$ = A$`, array store, UDF arg pass): bump refcount, no copy.
- Mutation (`MID$(A$, i, j) = X$`, `A$ = A$ + B$`): COW. If `refcount > 1`,
  duplicate before write. Most ops allocate a fresh string anyway, so COW only
  fires for the rare in-place mutators.
- `#OPTION maxstr` enforced at every allocation/grow site: if `len > cap` and
  `len > max_str_limit`, raise the existing "string too long" runtime error.

### Empty-string handling

`A$ = ""` and freshly-created `VAL_NUM` values point at `rgc_str_empty`.
Refcount is `INT_MAX`, never freed. Avoids `malloc` for the most common case.

### Constructors

```c
rgc_str_t *rgc_str_new(size_t cap);                /* refs=1, len=0 */
rgc_str_t *rgc_str_from_cstr(const char *s);       /* strlen */
rgc_str_t *rgc_str_from_bytes(const void *p, size_t n);  /* NUL-safe */
rgc_str_t *rgc_str_concat(const rgc_str_t *a, const rgc_str_t *b);
rgc_str_t *rgc_str_substr(const rgc_str_t *s, size_t off, size_t n);
```

All return refs=1. Caller owns the new ref.

### Comparisons

`strcmp` sites switch to `memcmp` with `min(a.len, b.len)` + tiebreak on
length. Lexicographic order preserved for embedded-NUL strings.

### Printing / file I/O

`print_value` writes `data` for `len` bytes via `fwrite` (or canvas equivalent).
No reliance on terminator. `INPUT #` / `LINE INPUT #` already read line-by-line
into a temporary buffer — that buffer becomes `rgc_str_from_bytes(buf, n)`.

### Error / longjmp safety

The interpreter uses `setjmp` / `longjmp` for runtime errors (search `setjmp`
in basic.c). Any temporary `rgc_str_t *` allocated during expression eval that
gets abandoned by a longjmp would leak.

Mitigation:

1. A per-statement "temp ring": every `rgc_str_new` / `rgc_str_concat` result
   that isn't stored into a `struct value` slot is pushed onto a small ring.
2. At statement boundary (after eval completes OR after longjmp unwind), drain
   the ring: unref every entry, free anything that hit zero.
3. `struct value` slots that get assigned to vars/arrays explicitly *promote*
   their str out of the ring before the boundary sweep.

Concretely: `eval_expr` returns a `struct value`; the caller either stores it
or discards it. A discard path always unrefs. The ring catches the
"abandoned mid-expression by error" case.

Cheap: ring is ~64 entries, fixed array, no malloc.

## Migration plan

Mechanical, but touches ~180 sites. Best done in one PR + one
green-test pass, not piecemeal.

**Phase 0 — gate.** Add `BIG_STRINGS` compile flag, default off. New code
paths live behind it. Lets us land the helpers without breaking main.

**Phase 1 — helpers.** Add `rgc_str.{c,h}`. Unit-test in isolation: new,
ref/unref, concat, substr, from_bytes (with embedded NUL), comparison.

**Phase 2 — struct value.** Behind `BIG_STRINGS`, change `str[MAX_STR_LEN]`
to `rgc_str_t *str`. Compile breaks every `.str` reference. Triage:

| Site class | Count | Fix |
|---|---|---|
| `make_str(s)` constructor | 1 | wrap `rgc_str_from_cstr` |
| `make_num` init | 1 | point at `rgc_str_empty`, ref |
| `out.str[0] = '\0'` zero-init | many | drop; constructor handles it |
| `strcpy(v->str, ...)` write | ~40 | use `rgc_str_from_*` and assign |
| `strcat(v->str, ...)` append | ~15 | use `rgc_str_concat` |
| `strlen(v->str)` length | ~20 | use `s->len` (or `rgc_str_len(s)`) |
| `v->str` as `const char *` read-only | ~50 | use `rgc_str_data(s)` (NUL-safe callers switch later) |
| `memcpy(out.str, ...)` literal write | ~10 | `rgc_str_from_bytes` |

`grep -n "\\.str\\[\\|->str\\[\\|out\\.str\\|src\\.str\\|vp->str\\|vt\\.str" basic.c` is the worklist starter; current count = 72.

**Phase 3 — intrinsics.** Convert `LEFT$`, `RIGHT$`, `MID$` (read + write),
`CHR$`, `STR$`, `LEN`, `ASC`, `INSTR`, `REPLACE`, `TRIM$`/`LTRIM$`/`RTRIM$`,
`SPLIT`, `JSON$`, `HTTP$`, `SHELL$`, `INPUT$`, `INKEY$`. Each becomes a
length-aware version. Most are 5-10 lines.

**Phase 4 — I/O + escape.** `print_value`, `PRINT #`, `INPUT #`, `LINE INPUT
#`, `GET #`, `PUT #`, `transform_basic_line` escape expansion (basic.c around
the `\0` site). Now binary-safe.

**Phase 5 — UDF + DATA + arrays.** UDF param passing (`saved_params`), `DATA`
/ `READ` (`data_items[]`), array store/load, FOR-var refs. Each is an
assignment site; use ref/unref helpers consistently.

**Phase 6 — flip default.** Remove `BIG_STRINGS` gate; old code paths
deleted. Bump `CHANGELOG.md`.

**Phase 7 — uncap.** `#OPTION maxstr unlimited` recognized in the parser; sets
`max_str_limit = SIZE_MAX`. Default stays 4096 to preserve existing test
behavior; users opt in. CLI: `-maxstr unlimited` mirrors.

## Test plan

- Existing test suite must pass unchanged at every phase end.
- New tests in `tests/`:
  - `bigstring_http.bas` — fetch a known >4 KB JSON, verify `LEN` and last
    byte.
  - `bigstring_nul.bas` — `S$ = "A\0B" + "C\0D"`, assert `LEN(S$) = 6`,
    `ASC(MID$(S$, 2, 1)) = 0`, `ASC(MID$(S$, 5, 1)) = 0`.
  - `bigstring_refcount.bas` — `B$ = A$ : C$ = A$ : A$ = "x"`, verify B$/C$
    unchanged (proves COW boundary).
  - `bigstring_grow.bas` — loop `S$ = S$ + "x"` 100000 times under `#OPTION
    maxstr unlimited`, assert `LEN(S$) = 100000`.
  - `bigstring_cap.bas` — same loop under `#OPTION maxstr 4096`, assert
    runtime error fires at byte 4096.
- Leak check: native build under `valgrind --leak-check=full` over the full
  test suite. Ring-sweep correctness is the highest-risk area.
- WASM heap budget: build canvas WASM, run a 1 MB `HTTP$` fetch, confirm
  `HEAPU8` watermark grew by ~1 MB, not 4 MB or worse.

## Risk register

| Risk | Mitigation |
|---|---|
| longjmp leaks during error unwind | per-statement temp ring (see "Error / longjmp safety") |
| Refcount underflow / double-free in COW path | refs are `int`, assert `>0` in unref; valgrind in CI |
| Performance regression on short strings (alloc per `+`) | profile after Phase 6; consider SSO if hot |
| `#OPTION maxstr` semantics change surprises C64 users | default stays 4096; "unlimited" is opt-in |
| Third-party C in `gfx/` / canvas reaches into `v->str` | grep shows it doesn't today; lock with a `.str` → `.str_h` rename so any external touch fails to compile |
| Compile flag rot during multi-phase work | each phase ends green; no half-merged states on `main` |

## Open questions

1. Does `gfx_canvas.c` or any `tools/` C file touch `struct value.str`? Need a
   sweep across the full source tree, not just `basic.c`. If yes, those have
   to migrate too.
2. Is there an existing arena allocator we should hook into for WASM, or do
   we just call `malloc`? Default to `malloc`; revisit if heap fragmentation
   shows up in long-running canvas sessions.
3. Refcount sharing across UDF call boundaries: easy to get wrong with
   recursive UDFs. Add a targeted test.

## Pointers into the code

- `struct value` definition: `basic.c:1385`.
- `MAX_STR_LEN` macro: `basic.c:1372`.
- `make_str`: `basic.c:3533`.
- `make_num` (zero-inits str field): `basic.c:3523`.
- `max_str_limit` runtime cap parsing: `basic.c:2565`, `basic.c:2709`.
- `print_value`: `basic.c:4136`.
- `data_items`: `basic.c:1618`.
- `saved_params`: `basic.c:1504`.
- Escape expansion + `\0` truncation note: `to-do.md:170-212`.

## Why big strings even though BUFFER shipped

`docs/buffer-type-plan.md` Step 1 SHIPPED — BUFFER solves the HTTP-truncation
case by sidestepping the value type entirely (MEMFS-backed file slot, reuse
`OPEN`/`GET #`). Zero risk to the evaluator and already in user hands. So
why do this work?

- Two data types for "a bag of bytes" — users have to learn which is which.
- String intrinsics (`INSTR`, `JSON$`, `SPLIT`, `LEFT$`/`MID$`) don't apply
  to buffers without duplication or transfer-back-to-string steps.
- Doesn't fix embedded-NUL truncation in regular strings (`\0` escape,
  raw PETSCII byte 0).
- Doesn't shrink `struct value`; stack/array memory pressure stays.
- Forces users into the BUFFER detour for any payload over 4 KB even when
  they just want a string.

Big strings cost more (one big PR, one round of leak hunting) but pay off
across the whole interpreter. BUFFER stays useful for streaming chunked
file I/O on bounded RAM; big strings just removes the *forcing function*
that pushed every >4 KB string through BUFFER.
