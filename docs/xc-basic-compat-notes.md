## XC=BASIC‑style functions & subroutines – design notes

This document captures design ideas for adding XC=BASIC 3–style `FUNCTION` and `SUB` syntax on top of the existing CBM‑style line interpreter, using **syntactic sugar** and incremental changes rather than a full compiler rewrite.

This is a **future‑work** sketch, not an implemented feature.

---

### 1. Goals and non‑goals

**Goals:**

- Allow users to write code that *resembles* XC=BASIC 3:
  - `FUNCTION name(...) ... END FUNCTION`
  - `SUB name(...) ... END SUB`
  - `CALL name(args...)`
- Preserve the existing interpreter architecture:
  - Line‑by‑line execution.
  - `GOSUB`/`RETURN` with a simple stack.
  - Global variables by default.
- Make the first step **pure syntactic sugar**:
  - No new type system.
  - No genuine local variables yet.
  - No overloading, visibility (`PRIVATE`/`SHARED`), or modules.

**Non‑goals (for the first iterations):**

- Implementing the full XC=BASIC function model (typed arguments, static vs dynamic frames, recursion analysis, etc.).
- Changing the core execution model to a block‑structured compiler with separate code generation.

---

### 2. Current building blocks we can reuse

We already have:

- `GOSUB` / `RETURN` with a fixed‑depth stack (`gosub_stack`).
- `DEF FN` user functions (`DEF FNY(X)=...`) stored in `user_funcs` and invoked from expressions.
- Labels (`LABEL:` at start of line) resolved at load time by `build_label_table()`.
- A robust line loader + execution loop.

These are enough to **lower** higher‑level constructs into the existing primitives.

---

### 3. Phase 1: SUB / CALL as sugar for GOSUB

#### 3.1 Syntax subset

Support a minimal subset:

```basic
SUB DrawStatus()
  PRINT "STATUS LINE"
END SUB

CALL DrawStatus()
```

Constraints for phase 1:

- No arguments (or arguments only as sugar that writes globals).
- No local variables; everything is global, as in traditional CBM BASIC.
- No overloading, visibility, or forward declarations.

#### 3.2 Lowering strategy

At load time, treat `SUB`/`END SUB` as **labels** plus some book‑keeping.

- Detect `SUB name` lines during loading:
  - Register a label called `SUB:name` pointing to the line *after* the `SUB` header.
  - Optionally record metadata about the block (`sub_table`) for debugging.
  - Strip the `SUB` header text and replace it with a comment/empty line so it does not execute.

- Detect `END SUB` lines:
  - Replace with a simple `RETURN` statement so that the existing `gosub_stack` unwinds correctly.

- Detect `CALL name` statements in `execute_statement`:

  ```c
  if (c == 'C' && starts_with_kw(*p, "CALL")) {
      *p += 4;
      statement_call(p);
      return;
  }
  ```

  And in `statement_call`:

  ```c
  static void statement_call(char **p)
  {
      char namebuf[32];
      int len = 0;
      int target_index;

      skip_spaces(p);
      /* Read identifier up to '(' or whitespace */
      while ((isalpha((unsigned char)**p) || isdigit((unsigned char)**p) || **p == '$') &&
             len < (int)sizeof(namebuf) - 1) {
          namebuf[len++] = **p;
          (*p)++;
      }
      namebuf[len] = '\0';

      /* For now, ignore argument list if present: CALL Name() */
      skip_spaces(p);
      if (**p == '(') {
          /* Skip balanced parentheses; arguments handled in later phases */
          int depth = 1;
          (*p)++;
          while (**p && depth > 0) {
              if (**p == '(') depth++;
              else if (**p == ')') depth--;
              (*p)++;
          }
      }

      /* Resolve to a label like "SUB:Name" to avoid conflicts */
      target_index = find_label_line(namebuf /* or "SUB:Name" */);
      if (target_index < 0) {
          runtime_error("Unknown subroutine in CALL");
          return;
      }

      /* Defer to existing GOSUB machinery */
      /* Equivalent to: GOSUB label */
      if (gosub_top >= MAX_GOSUB) { runtime_error("GOSUB stack overflow"); return; }
      gosub_stack[gosub_top].line_index = current_line;
      gosub_stack[gosub_top].position   = *p;
      gosub_top++;

      current_line  = target_index;
      statement_pos = NULL;
  }
  ```

Effectively, `CALL name()` becomes a type‑checked, label‑based `GOSUB` using syntax that looks like XC=BASIC’s `CALL`.

#### 3.3 Testing strategy

Create small tests under `tests/`:

```basic
REM tests/sub_call_smoke.bas
SUB HELLO()
  PRINT "HELLO";
END SUB

PRINT "A";
CALL HELLO()
PRINT "B"
END
```

Expect output: `AHELLOB` (plus final newline).  
Add variants:

- Nested CALLs.
- CALLs from inside `FOR`/`IF`.

Use plain runs and `hexdump -C` to verify no extra newlines or stack mis‑handling.

---

### 4. Phase 1.5: FUNCTION / END FUNCTION as sugar for DEF FN

Target syntax (restricted):

```basic
FUNCTION DoubleX(X)
  RETURN X*2
END FUNCTION

PRINT DoubleX(5)
END
```

Constraints for the first cut:

- Single expression‑return only (one `RETURN expr` as the last statement).
- No local variables beyond the parameter.
- No early `EXIT FUNCTION` yet.

#### 4.1 Lowering strategy

At load time, transform `FUNCTION` blocks into `DEF FN` definitions:

- Detect:

  ```basic
  FUNCTION Name(arg1, arg2, ...)
    RETURN <expr>
  END FUNCTION
  ```

- Concatenate the `RETURN` expression into a single line:

  ```basic
  DEF FNName(arg1, arg2, ...) = <expr>
  ```

- Feed this synthetic line into the existing `statement_def` logic:
  - This populates `user_funcs` with `Name` as a DEF FN‑style function.

This lets existing `eval_factor` / `user_func_lookup` machinery handle calls like `Name(5)`.

#### 4.2 Parser changes

`execute_statement` would gain a branch:

```c
if (c == 'F' && starts_with_kw(*p, "FUNCTION")) {
    *p += 8;
    statement_function(p);
    return;
}
```

`statement_function` would:

- Parse the function header: name + parameter list.
- Collect lines until `END FUNCTION`, buffering the body.
- For the initial subset:
  - Require that the body reduces to a simple `RETURN <expr>`.
  - Synthesize a `DEF FN` line and call `statement_def` on that synthetic text.

Later phases could extend this to allow multiple statements, early `RETURN`s, and local variables by interpreting the block directly rather than lowering to `DEF FN`.

#### 4.3 Testing strategy

Add tests such as:

```basic
REM tests/function_sugar.bas
FUNCTION DOUBLE(X)
  RETURN X*2
END FUNCTION

PRINT DOUBLE(3)
END
```

Expected output: `6` (with newline).  
Also test:

- Multiple functions in one file.
- Mixed `DEF FN` and `FUNCTION` definitions.

---

### 5. Phase 2: true locals and arguments (optional)

Once the sugar paths are stable and well‑tested, we can incrementally move toward **real** XC=BASIC semantics:

- Introduce a per‑call frame structure holding:
  - A pointer to the previous frame.
  - Argument values.
  - Local variables.
- When entering a `SUB`/`FUNCTION`:
  - Allocate a frame, bind arguments, redirect variable lookup to prefer locals.
- When exiting:
  - Pop the frame and restore the previous context.

This would enable:

- Proper local variables.
- Recursive SUBs/FUNCTIONs (if we allow it).
- Closer parity with XC=BASIC’s `SUB`/`FUNCTION` semantics without abandoning the interpreter approach.

This is deliberately sketched only at a high level; we should not attempt it until Phase 1 is battle‑tested.

---

### 6. Regression testing strategy

To keep these features correct over time:

1. **Unit‑style BASIC programs under `tests/`**
   - `tests/sub_call_smoke.bas` – simple SUB/CALL behavior.
   - `tests/function_sugar.bas` – FUNCTION / RETURN sugar over DEF FN.
   - `tests/sub_nesting.bas` – nested CALLs and CALL within loops.
   - `tests/function_errors.bas` – malformed FUNCTION blocks that should produce clear errors.

2. **Hex‑level verification when control codes are involved**
   - For features touching cursor movement or colors, pipe through `hexdump -C`:

     ```bash
     ./basic -petscii -palette c64 tests/sub_call_smoke.bas | hexdump -C
     ```

3. **CI integration**
   - Extend the GitHub Actions workflow to run:

     ```bash
     ./basic tests/def_fn.bas
     ./basic tests/sub_call_smoke.bas
     ./basic tests/function_sugar.bas
     ```

   - Optionally compare output to golden files using a small shell or Python harness.

4. **Real‑world compatibility tests**
   - Port a small XC=BASIC sample that uses only the supported subset:
     - A few `SUB`s called with `CALL`.
     - A `FUNCTION` or two that can be expressed as a single expression.
   - Keep it under `examples/xc-basic-demo.bas` and run it in CI as an integration test.

With this staged, sugar‑based approach and a solid test harness, we can move toward XC=BASIC‑style syntax confidently, without destabilizing the existing CBM BASIC interpreter.

