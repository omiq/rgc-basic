# Decision: line continuation (`_`)

**Status:** Approved semantics (not yet implemented)  
**Date:** 2026-06-02  
**Related:** `docs/triple-quote-strings.md` (complementary), `basic.c` `load_file_into_program()`, `transform_basic_line()`

## Summary

Add Visual Basic-style **line continuation**: a trailing `_` joins the current physical source line to the next one so a single statement can span multiple lines. This is **not** a multiline string literal; it only breaks long **statements** (expressions, `PRINT` argument lists, etc.) across lines.

**Complementary to triple quotes:** use `_` for long one-liners; use `"""` for paste-in JSON or prose with embedded newlines and quotes. See `docs/triple-quote-strings.md`.

Neither feature replaces the other. Both are **numberless-only** (same policy as triple quotes).

## Syntax

```basic
PRINT "The USS Enterprise --- NCC-1701" + _
      " stands ready."

J$ = "{" + _
     Q$ + "id" + Q$ + ":1," + _
     Q$ + "name" + Q$ + ":" + Q$ + "Lobby" + Q$ + _
     "}"
```

- **Sigil:** ASCII underscore `_` at the **end** of a physical line (optional trailing spaces/tabs before newline are ignored; the `_` must be the last non-whitespace character on that line).
- **Join rule:** The next physical line is appended with a single ASCII space inserted between the joined parts (VB convention). Leading whitespace on the continuation line is stripped before join.
- **Chains:** If the continuation line also ends with `_`, repeat until a line without a trailing `_`.
- After all joins for that statement, run the existing pipeline on the **merged logical line:** `transform_basic_line()` then `normalize_keywords_line()`.

## What continuation does not do

- It does **not** put literal newlines inside a string. Use `"""..."""`, `\n` inside `"..."`, or `CHR$(10)` for that.
- It does **not** remove the need for `+` between string fragments on separate lines (each continued segment is still normal BASIC syntax).
- It is **not** statement separator `:` (that stays a separate mechanism).

## Restrictions (numbered programs)

Line continuation is allowed **only in numberless programs**, matching triple-quoted strings.

| Situation | Behaviour |
|-----------|-------------|
| Trailing `_` in a file where any line has an explicit line number | Load error |
| `#INCLUDE` of a file that uses `_` continuation while the including program is numbered | Load error |
| `#INCLUDE` into a numberless program | Allowed |

Rationale: continuation lines have no line number of their own; mixing that with Commodore-style numbered source is ambiguous and out of scope for retro-numbered `.bas` files.

## Implementation strategy

### Phase 1: pre-join (loader)

Before `transform_basic_line()` on each **statement line** in numberless mode:

1. If the trimmed line ends with `_` (outside of string literals and comments), do not finalize the line yet.
2. Read the next physical line(s), strip leading whitespace, insert one space, append to the accumulator, until a line without trailing `_`.
3. Feed the merged logical line to `transform_basic_line()` / `normalize_keywords_line()` as today.

### Detecting `_` outside strings

While scanning for trailing `_`, honour:

- Double-quoted strings (`\"` escapes already handled at transform time; at join time, treat `\` + next char inside strings like `transform_basic_line` does, or join only when `_` is outside quotes).
- `REM` / `'` comments: nothing after the comment starts a continuation (trailing `_` in comment text does not continue).

### Order relative to triple quotes

Recommended load order for numberless files:

1. **Triple-quote absorption** (if implemented): raw lines → synthetic assignment line(s).
2. **Line continuation join** on the resulting physical/logical lines.
3. **`transform_basic_line()`** / **`normalize_keywords_line()`**.

Triple-quote blocks should not use `_` inside the absorbed region (v1: error or treat `_` as literal inside `"""` only; continuation applies outside triple blocks).

### Errors (clear hints)

- `line continuation is not allowed in numbered programs`
- `line continuation in included file "x.bas" cannot be used from a numbered program`
- `unexpected end of file in continued line` (EOF while still expecting a continuation line)

## Tooling

| Component | Action |
|-----------|--------|
| `basic.c` loader | Pre-join pass + errors above |
| `tools/rgc_lint/tokenizer.py` | Join continuation lines before `:` split, or warn in numbered files (shared front end; private transpiler backends inherit the same join rules) |
| `tests/line_continuation.bas` | Numberless: chained `_`, string `+` across lines; negative numbered test |
| `spec.json` / retrodocs | Note numberless-only when shipped |

## Effort estimate

| Piece | Time |
|-------|------|
| Pre-join pass + string/comment-aware trailing `_` | ~0.5–1 day |
| Numbered / include errors | ~0.25 day |
| Tests + lint | ~0.25–0.5 day |
| Docs / CHANGELOG on ship | ~0.25 day |

**Total:** ~1–1.5 days (can ship before or after triple quotes; no dependency either way).

## Comparison (quick reference)

| Need | Use |
|------|-----|
| Long `PRINT` / expression wrapped for readability | `_` |
| JSON or story text with newlines and `"` inside | `"""` |
| Incremental string build (loops, chunks) | **`S$ += "..."`** (shipped; `tests/compound_assign.bas`) |
| `"` inside a one-line string | **`\"`** (shipped; `tests/string_escape.bas`) — prefer over `Q$ = CHR$(34)` |
| Large adventure data | `DICTLOAD` from `.json` file |
| Retro numbered program | Neither `_` nor `"""` (use `+=`, `\"`, `+`, external file) |
