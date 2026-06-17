# Decision: triple-quoted string literals (`"""..."""`)

**Status:** Approved semantics (not yet implemented)  
**Date:** 2026-06-02  
**Related:** `docs/line-continuation.md` (complementary), `docs/haversack-wishlist.md` §2a, `basic.c` `transform_basic_line()`, `tests/string_escape.bas`

## Summary

Add Python-style triple-quoted string literals for embedding multi-line text and JSON blobs in source without `CHR$(34)` concatenation gymnastics. The feature is implemented as a **load-time rewrite** into ordinary double-quoted string concatenation so `{PETSCII}` / `{TOKEN}` expansion and `\` escapes reuse `transform_basic_line()` unchanged.

**Complementary feature:** VB-style line continuation (`_`) for long statements is specified separately in `docs/line-continuation.md`. Triple quotes are not a replacement for `_`, and vice versa. **Both are numberless-only.**

## Syntax

```basic
MYSTR$ = """
line one
line two with "quotes" inside
"""
```

- Delimiter: three ASCII double-quote characters (`"""`) open and close.
- Opening `"""` must appear on the **same physical source line** as the assignment (or other binding) that starts the literal. A line that is only `"""` with the assignment on a previous line is an error.
- Closing `"""` may be on the same line as the opener (single-line form) or on a later physical line (multi-line form).
- Content may span multiple physical lines; each line break in the source becomes `CHR$(10)` (LF) in the expanded form, consistent with `tests/string_escape.bas` (`\n` → LF).

## Restrictions (numbered programs)

Triple-quoted literals are allowed **only in numberless programs** (no leading line digits on any line in that file).

| Situation | Behaviour |
|-----------|-------------|
| `"""` in a file where any line has an explicit line number | Load error |
| `#INCLUDE "file.bas"` and the included file contains `"""` while the including program is in numbered mode | Load error |
| `#INCLUDE` of a triple-quote file into a numberless program | Allowed |

Rationale: avoids ambiguous rules for whether continuation lines are “code” or literal text, and matches modern/tutorial `.bas` style where inline JSON and CYOA data live anyway.

## Implementation strategy

### Phase 1: loader absorption (new code)

In `load_file_into_program()` (or a helper called before `transform_basic_line()` per logical line):

1. Track `in_triple_string` and an accumulator for raw bytes between delimiters.
2. When **not** in numbered mode, detect an opening `"""` on a line that also contains the start of the literal (same-line rule above).
3. Until closing `"""`, append physical lines to the accumulator (include newline between lines).
4. On close, replace the entire construct with a single synthetic source line, e.g.  
   `MYSTR$ = "line one" + CHR$(10) + "line two with \"quotes\" inside"`  
   (exact shape TBD: may use only `+` and quoted segments if inner quotes are escaped for the downstream pass).
5. Pass that synthetic line through existing `transform_basic_line()` then `normalize_keywords_line()`.

### Phase 2: reuse existing string transform (no duplicate token logic)

Do **not** reimplement `{RED}`, `\n`, `\"`, etc. inside the triple-quote walker.

Preferred approach:

1. Extract or call the **inner** string-body processor already used by `transform_basic_line()` on the accumulated text (between `"""` markers, delimiters stripped).
2. Emit its output as a concatenation expression the parser already accepts (same as today’s load-time expansion of `"hello {RED}world"`).

Token translation is therefore “free”: one code path for escapes and brace tokens.

Edge case: if the inner processor expects to run per physical line today, run it once on the full accumulated blob before wrapping in quotes / `CHR$(10)` pieces.

### Errors (clear hints)

- `triple-quoted strings are not allowed in numbered programs`
- `triple-quoted string must start on the same line as the assignment` (opening `"""` not on assignment line)
- `unterminated triple-quoted string` (EOF before closing `"""`)
- `triple-quoted string in included file "x.bas" cannot be used from a numbered program`

## Non-goals (v1)

- **`""` Pascal-style escape** inside normal strings (separate wishlist item; inside `"""`, two consecutive `"` are two characters, not an escape).
- **Raw / no-expand triple strings** (no `r"""`); brace tokens always expand like normal strings.
- **Triple quotes in numbered mode** even as a one-liner `10 A$="""x"""` (forbidden by policy).
- **`DICTMERGE` / dict literals** (see adventure JSON via `DICTLOAD` + file or inline `"""` JSON string).

## Tooling

| Component | Action |
|-----------|--------|
| `basic.c` loader | Absorption + errors above |
| `tools/rgc_lint/tokenizer.py` | Treat `"""` like string context for `:` split; or pre-scan and warn in numbered files (shared front end; private transpiler backends inherit the same string rules) |
| `tests/triple_quote.bas` | Numberless: multiline, embedded `"`, `{token}`, `\n`; negative tests for numbered + bad open |
| `spec.json` / retrodocs | Note numberless-only when shipped |

## Use case: CYOA / adventure data

```basic
ROOMS$ = """
{
  "lobby": {
    "text": "You stand in the hall.",
    "choices": [
      {"label": "North", "goto": "kitchen"}
    ]
  }
}
"""
H = DICTLOAD(ROOMS$)
```

For large games, `DICTLOAD` from an external `.json` file remains the recommended path; triple quotes are for demos, tests, and medium inline tables.

## Already available (no loader work)

| Feature | Example | Notes |
|---------|---------|--------|
| **`S$ += expr`** | `J$ += "{\"id\":1}"` | Compound assign; see `tests/compound_assign.bas`, README §LET |
| **`\"` in strings** | `J$ = "{\"id\":1}"` | Load-time → `CHR$(34)`; see `tests/string_escape.bas` |
| **`Q$ = CHR$(34)`** | `J$ = "{" + Q$ + "id" + Q$ + ":1}"` | Still valid; prefer `\"` for new code |

Building JSON without triple quotes: use `\"` for quotes and `+=` to append lines or chunks. Pair with `docs/line-continuation.md` (`_`) for long single statements when that ships.

## Effort estimate

| Piece | Time |
|-------|------|
| Loader absorption + same-line rule + numbered/include errors | ~1 day |
| Refactor/share inner transform with `transform_basic_line()` | ~0.5 day |
| Tests + lint alignment | ~0.5 day |
| Docs / CHANGELOG on ship | ~0.25 day |

**Total:** ~2 days for multiline, numberless-only, concat-rewrite design.

## Load order (with line continuation)

When both features ship, apply in numberless files:

1. Triple-quote absorption → synthetic line(s).
2. Line continuation join (`_`) on physical lines.
3. `transform_basic_line()` / `normalize_keywords_line()`.

See `docs/line-continuation.md`.

## Open question (minor)

Assignment forms beyond `VAR$ = """` (e.g. `PRINT """hi"""` on one line, or `SUB` parameter): v1 can limit to **assignment and `LET`-equivalent binds** only; other sites get “triple-quoted string must be assigned on the same line” or defer to a follow-up once assignment path works.
