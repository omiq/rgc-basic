# IF ELSE END IF – Implementation Plan

**Status**: Implemented.

This document outlines what it would take to add structured `IF … THEN … ELSE … END IF` blocks to CBM-BASIC, spanning multiple lines and statements.

---

## 1. Target syntax

```basic
IF X > 0 THEN
  PRINT "POSITIVE"
  A = 1
ELSE
  PRINT "NON-POSITIVE"
  A = 0
END IF
```

- `IF condition THEN` — start of block; condition is evaluated
- One or more statements (possibly multiple lines) in the THEN branch
- Optional `ELSE` — start of ELSE branch
- `END IF` — end of block

Nested blocks:

```basic
IF X > 0 THEN
  IF Y > 0 THEN
    PRINT "BOTH POSITIVE"
  ELSE
    PRINT "X POSITIVE, Y NOT"
  END IF
ELSE
  PRINT "X NOT POSITIVE"
END IF
```

---

## 2. Current IF implementation

Today `statement_if`:

1. Evaluates the condition
2. Requires `THEN` (error if missing)
3. If **false**: skips the rest of the **current line** (`*p += strlen(*p)`)
4. If **true**: either
   - `GOTO line#` → jump to that line
   - otherwise → execute the rest of the line inline by setting `statement_pos = *p`

So the current IF is single-line (or one branch is a GOTO). It does not support multi-line blocks or ELSE.

---

## 3. Execution model

The main loop:

- `current_line` = line index
- `statement_pos` = pointer into current line text (or NULL to advance to next line)
- Each step: run one statement from `statement_pos`; advance past it; if more on line, repeat; else next line

To support multi-line IF blocks we need to:

- **Skip** until matching `ELSE` or `END IF` (when condition is false and we are before ELSE, or when condition is true and we hit ELSE)
- **Execute** the appropriate branch
- **Recognise** `ELSE` and `END IF` as control-flow statements, not ordinary code

---

## 4. Implementation approaches

### Option A: Block stack (recommended)

Introduce a small block stack, e.g.:

```c
#define MAX_IF_DEPTH 16
struct if_block {
    int took_then;    /* 1 if we executed THEN branch, 0 if we skipped */
    int after_else;   /* 1 if we've passed ELSE (so we're in ELSE branch) */
};
static struct if_block if_stack[MAX_IF_DEPTH];
static int if_depth = 0;
```

**IF condition THEN**:

1. Evaluate condition
2. Push `{ took_then = cond, after_else = 0 }`
3. If false: enter “skip” mode until `ELSE` or `END IF`

**ELSE** (when `if_depth > 0`):

1. Pop the current IF block
2. If we took the THEN branch: skip until `END IF`
3. If we skipped THEN: start executing (we are now in ELSE branch)
4. Push new state `{ took_then = 0, after_else = 1 }` for the same block (or equivalent)

**END IF**:

1. Pop the block stack
2. Continue normal execution

**Skip mode**: When we need to skip, we scan forward line-by-line and statement-by-statement. For each statement we check if it’s `ELSE`, `END IF`, or nested `IF`. Nested `IF` requires matching `END IF` before we can match our own `ELSE`/`END IF`.

### Option B: Load-time transformation to GOTOs

At load time, rewrite:

```basic
IF X>0 THEN
  PRINT "A"
ELSE
  PRINT "B"
END IF
```

to something like:

```basic
IF X>0 THEN GOTO __L1
GOTO __L2
__L1: PRINT "A"
GOTO __L3
__L2: PRINT "B"
__L3:
```

**Pros**: Reuses existing IF/GOTO, no block stack  
**Cons**: Synthetic labels, more complex parser, line numbering and structure can become opaque

### Option C: Full recursive parser

Parse IF/ELSE/END IF into an AST and execute from that.

**Pros**: Very clean semantics  
**Cons**: Larger change to the current “line + position” execution model

---

## 5. Recommended design (Option A)

### 5.1 New statements

1. **IF … THEN** — extended
   - If `THEN` is followed by newline/EOL (or `:` and then newline), start a *block* and push onto `if_stack`
   - If `THEN` is followed by a line number or inline statements, keep current behaviour (backward compatible)

2. **ELSE**
   - Only valid when `if_depth > 0`
   - Implements the behaviour described in §4

3. **END IF**
   - Only valid when `if_depth > 0`
   - Pops the block stack

### 5.2 Skip logic

When skipping (condition false, before ELSE; or THEN taken, after ELSE):

- Advance line-by-line and statement-by-statement
- On each statement: if it’s `IF`, increment a local nesting counter; if it’s `END IF`, decrement
- When we see `ELSE` at our nesting level (counter 0): stop skipping (or start skipping, depending on branch)
- When we see `END IF` at our nesting level: stop and pop

### 5.3 END vs END IF

Currently `END` halts the program. We need to treat `END IF` differently:

- When the dispatcher sees `E` and `starts_with_kw(*p, "END")`, peek ahead past optional spaces
- If the next token is `IF` → handle as `END IF`
- Otherwise → handle as `END` (halt)

---

## 6. Edge cases

- **ELSE IF** (optional extension): `ELSE IF cond THEN` as shorthand for `ELSE` + `IF cond THEN`. Can be implemented as `ELSE` followed by `IF` or via extra parsing.
- **Empty branches**: `IF X THEN ELSE PRINT "NO" END IF` — THEN branch empty; skip to ELSE.
- **Missing END IF**: Runtime error “END IF expected” or “IF without END IF”.
- **END IF without IF**: Runtime error “END IF without matching IF”.

---

## 7. Files to touch

| File      | Changes |
|-----------|---------|
| `basic.c` | Block stack; extended `statement_if`; new `statement_else`, `statement_end_if`; skip helper; END/END IF split; dispatcher changes |
| `to-do.md` | Mark item done when implemented |

---

## 8. Effort estimate

- **Small**: Block stack + `statement_if` extension + ELSE/END IF handlers + skip logic (on the order of 100–150 lines)
- **Risk**: Skip logic across lines and nested blocks must correctly handle `:`, multiple statements per line, and nested IFs

---

## 9. Backward compatibility

- `IF X THEN 100` — unchanged (GOTO 100)
- `IF X THEN PRINT "Y"` — unchanged (inline THEN)
- `IF X THEN` at EOL — new: start block
- Existing programs without `ELSE` / `END IF` are unaffected
