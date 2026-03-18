# User-Defined FUNCTIONS Plan

**Status**: Implemented  
**Goal**: Add multi-line, multi-parameter user-defined functions with `FUNCTION` … `RETURN` … `END FUNCTION`, callable from expressions.

---

## 1. Rationale

- **Beyond DEF FN**: Current `DEF FN` is single-expression, single-parameter. `FUNCTION` allows a full statement block and multiple parameters.
- **Structured subroutines that return values**: Like GOSUB but with parameters and a return value usable in expressions.
- **Modern BASIC style**: QBasic, FreeBASIC, etc. use this pattern.

---

## 2. Syntax

### 2.1 Definition

```
FUNCTION name [(param1, param2, ...)]
  REM body — any statements
  RETURN expr
END FUNCTION
```

- **name**: Identifier (letters, digits, `$` for string return). Up to 31 chars (matches variable rules). **No** `FN` prefix required (unlike DEF FN).
- **params**: Optional. Comma-separated list when present. Each is an identifier (scalar or `name$` for string). Parameters are local to the function. `FUNCTION foo()` and `FUNCTION foo` both valid.
- **body**: Statements including LET, PRINT (to stdout), IF, FOR, WHILE, etc. Parameters and locals (if we add them) are in scope.
- **RETURN [expr]**: Optional expr. `RETURN expr` — exits and provides the value (for use in expressions). `RETURN` (no expr) — exits with no value; like GOSUB, for side effects only. When called in an expression and no value was returned, default to 0 or `""`.

### 2.2 Call

```
answer = test(5, 10)
PRINT add(a, b)
x = myfunc$(s$, 3)
foo()                    REM like GOSUB — side effects only, no value
```

- Called from expressions (when value needed) or as a statement (when no value). `RETURN` with no expr makes it like GOSUB — does work and exits; used in expression yields 0/"".
- **Brackets always required**: `test()` even with no args; `test(5, 10)` with args.
- Argument count must match parameter count.

---

## 3. Coexistence with DEF FN

| Feature    | DEF FN          | FUNCTION              |
|-----------|-----------------|------------------------|
| Body      | Single expression | Multi-statement block |
| Params    | 1               | 0 or more              |
| Return    | Implicit (expr) | Explicit RETURN        |
| Name      | Must start FN   | Any identifier         |

- **Lookup**: When we see `name(...)` in an expression:
  1. Check FUNCTION table (by name + param count if needed).
  2. Else check DEF FN table (by name, single arg).
  3. Else treat as variable/array.
- **No conflict**: A program can have both `DEF FNTEST(X)=X*2` and `FUNCTION TEST(a,b)` — they differ by arity. Call `TEST(5)` → DEF FN; `TEST(5,10)` → FUNCTION.

---

## 4. Execution Model

1. **Definition (load time)**: Scan for `FUNCTION name (...)`. Record name, param list, and start position. Scan for matching `END FUNCTION`; record end position. Store in a `udf_func` table (separate from `user_funcs` for DEF FN).
2. **Call (runtime)**:
   - Evaluate arguments.
   - Push a call frame: saved `current_line`, `statement_pos`, parameter bindings.
   - Bind parameters to temp/local vars (or push onto a param stack).
   - Set `current_line` and `statement_pos` to the function body start.
   - Run until we hit `RETURN expr` or `END FUNCTION`.
   - On `RETURN`: eval expr, pop frame, restore position, pass value back to caller.
   - On `END FUNCTION` without prior RETURN: error, or return default (0/"").

---

## 5. Parameter Binding

- **Option A (simple)**: Use the global variable table. On entry, save current values of param names, assign args. On exit, restore. (Same as DEF FN.)
- **Option B**: Per-call local scope. Function calls push a scope; params and any future `LOCAL` vars live there.
- **Recommendation**: Start with A for simplicity. Parameters shadow globals for the duration of the call.

---

## 6. RETURN Statement

- **Syntax**: `RETURN [expr]`
- **Effect**: If `expr` present — evaluate, store result, exit, restore caller, provide value. If no `expr` — exit with no value (like GOSUB); when used in expression context, caller gets 0 or `""`.
- **Scope**: Only valid inside a FUNCTION body. Error if used outside.
- **Multiple RETURN**: Allowed. First one executed wins.
- **Call syntax**: Brackets always required: `test()` even with no args; `test(5, 10)` with args.

---

## 7. Data Structures

```c
#define MAX_UDF_PARAMS 16
#define MAX_UDF_FUNCS  32

struct udf_func {
    char name[VAR_NAME_MAX];
    int param_count;
    char param_names[MAX_UDF_PARAMS][VAR_NAME_MAX];
    int param_is_string[MAX_UDF_PARAMS];
    int body_line;           /* line index of first statement */
    char *body_pos;          /* position in that line */
    int end_line;             /* line index of END FUNCTION */
    char *end_pos;            /* position after END FUNCTION */
};

struct udf_call_frame {
    int func_index;
    int saved_line;
    char *saved_pos;
    struct value saved_params[MAX_UDF_PARAMS];  /* if we need to restore */
};
```

---

## 8. Implementation Phases

1. **Phase 1**: Parse and register FUNCTION definitions at load time. No execution yet.
2. **Phase 2**: Implement RETURN and call-frame handling; run function body until RETURN.
3. **Phase 3**: Wire calls from expression evaluator — when we see `name(...)` and param count matches a FUNCTION, invoke it.
4. **Phase 4**: Edge cases — recursion, RETURN without value (error?), END FUNCTION without RETURN.

---

## 9. Open Questions

- **String functions**: Support `FUNCTION foo$(x,y)` returning string? Or infer from first RETURN?
- **Recursion**: Allowed? Need a call-depth limit.
- **END FUNCTION without RETURN**: Same as `RETURN` with no value — exit with no value; caller gets 0/"" when used in expression.
- **RESUME / error handling**: Out of scope for v1.

---

## 10. Non-Goals (v1)

- `LOCAL` variables (params only).
- `EXIT FUNCTION` as an alias for RETURN.
- Optional parameters or `PARAMARRAY`.
