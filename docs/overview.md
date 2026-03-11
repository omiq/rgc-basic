## Developer overview – `cbm-basic` interpreter

This document is a high‑level guide to how the interpreter in `basic.c` is structured, how execution flows, and how to add new BASIC features safely.

The goal is to preserve the spirit of CBM BASIC v2 while keeping the core engine small and understandable.

---

### 1. Big picture architecture

At a high level the interpreter does three things:

1. **Load program text** from a `.bas` file into an in‑memory array of lines.
2. **Execute statements** line by line, maintaining interpreter state (variables, stacks, etc.).
3. **Provide built‑in functions and statements** (`PRINT`, `IF`, `MID$`, `SLEEP`, etc.) as small C helpers.

Key global structures in `basic.c`:

- **Program storage**
  - `struct line { int number; char *text; };`
  - `static struct line *program_lines[MAX_LINES];`
  - `static int line_count;`

- **Execution state**
  - `static int current_line;` – index into `program_lines` (not the BASIC line number).
  - `static char *statement_pos;` – current position within `program_lines[current_line]->text`.
  - `static int halted;` – set non‑zero to stop the interpreter.
  - `static int print_col;` – current output column (for wrapping and `TAB`).

- **Variables and stacks**
  - `static struct var vars[MAX_VARS];` – scalar/array variables (numeric and string).
  - `static struct gosub_frame gosub_stack[MAX_GOSUB];`
  - `static struct for_frame  for_stack[MAX_FOR];`
  - `static struct user_func  user_funcs[MAX_USER_FUNCS];` – `DEF FN` functions.

- **PETSCII / ANSI config**
  - `static int petscii_mode;` – enabled by `-petscii` CLI flag.
  - `static int palette_mode;` – `PALETTE_ANSI` or `PALETTE_C64_8BIT` (from `-palette` CLI flag).

---

### 2. Program loading and labels

#### 2.1 Line‑numbered vs numberless programs

Loading is handled by `load_program(const char *path)`:

- Reads each line of the source file into `linebuf`.
- Trims whitespace and UTF‑8 BOM.
- If the **first non‑blank line starts with digits**, the file is treated as **classic line‑numbered BASIC**:
  - The numeric prefix becomes `struct line.number`.
  - The remainder of the line (after the line number) becomes `struct line.text`.
- If the first non‑blank line **does not** start with a digit, the file is treated as **numberless**:
  - Synthetic line numbers (`10, 20, 30, ...`) are assigned in load order.
  - The entire trimmed line becomes `struct line.text`.

Lines are then sorted by `line.number` (`sort_program`) so that `GOTO 100` and friends can find the correct index via `find_line_index(int number)`.

#### 2.2 Labels

Label support is built on top of this representation:

- `build_label_table()` scans `program_lines` after loading.
- Any line whose **first token** matches `NAME:` (letters/digits/`$` followed by `:`) is treated as a **label definition**.
  - The label name is stored (upper‑cased) in `label_table[i].name`.
  - The corresponding `line_index` is stored.
  - The `LABEL:` prefix is stripped from `program_lines[i]->text`, so execution sees only the remaining statement(s).
- `find_label_line(const char *name)` resolves `GOTO LABEL` and `GOSUB LABEL` into a `line_index` by looking up the upper‑cased label.

Example:

```basic
START:
PRINT "HELLO"
GOTO START
```

At load time, `START` is recorded as a label pointing at the `PRINT` line, and the stored text becomes just `PRINT "HELLO"`.

---

### 3. Execution loop

The main execution loop lives in `run_program(void)`:

```c
halted = 0;
current_line = 0;
statement_pos = NULL;
print_col = 0;

while (!halted && current_line >= 0 && current_line < line_count) {
    char *p;
    if (statement_pos == NULL) {
        statement_pos = program_lines[current_line]->text;
    }
    p = statement_pos;
    skip_spaces(&p);
    if (*p == '\0') {
        current_line++;
        statement_pos = NULL;
        continue;
    }
    statement_pos = p;
    execute_statement(&statement_pos);

    if (halted) break;
    if (statement_pos == NULL) continue;

    skip_spaces(&statement_pos);
    if (*statement_pos == ':') {
        statement_pos++;    /* next statement on the same line */
        continue;
    }
    skip_spaces(&statement_pos);
    if (*statement_pos == '\0') {
        current_line++;
        statement_pos = NULL;
    }
}
```

Important points:

- `statement_pos` is reused to walk through multiple statements on the same line separated by `:`.
- `execute_statement` is responsible for:
  - recognizing a keyword (e.g. `PRINT`, `IF`, `FOR`).  
  - or falling back to implicit `LET` (assignment) if the line begins with a variable name.
- Some statements intentionally set `statement_pos = NULL` (e.g. `GOTO`, `GOSUB`, `RETURN`) to force the loop to re‑fetch the next line’s text.

---

### 4. Statement dispatcher

`execute_statement(char **p)` is the main dispatcher. It looks at the **first non‑space character** and then uses `starts_with_kw` to match keywords in a case‑insensitive way:

```c
skip_spaces(p);
if (**p == '\0') return;
char c = toupper((unsigned char)**p);

if (c == '\'') { statement_rem(p); return; }
if (c == '?')  { (*p)++; statement_print(p); return; }

if (c == 'P') {
    if (starts_with_kw(*p, "PRINT")) { *p += 5; statement_print(p); return; }
    if (starts_with_kw(*p, "POKE"))  { ...; return; }
}

if (c == 'I' && starts_with_kw(*p, "INPUT")) { ... }
if (c == 'G' && starts_with_kw(*p, "GET"))   { ... }
if (c == 'G' && starts_with_kw(*p, "GOTO"))  { ... }
if (c == 'G' && starts_with_kw(*p, "GOSUB")) { ... }
if (c == 'I' && starts_with_kw(*p, "IF"))    { ... }
/* ... many more ... */

/* Fallback: implicit LET assignment */
if (isalpha((unsigned char)c)) {
    statement_let(p);
    return;
}
runtime_error("Unknown statement");
```

Adding a new **statement keyword** almost always means:

1. Writing a helper `static void statement_X(char **p)` that parses the rest of the line.
2. Adding one small branch in `execute_statement` to recognize the keyword and call your helper.

Example: `SLEEP` was added exactly this way (`statement_sleep` + minimal dispatch).

---

### 5. Expressions and intrinsic functions

Expressions are parsed recursively by:

- `eval_expr` – `+` and `-` (with string concatenation on `+`).
- `eval_term` – `*` and `/`.
- `eval_power` – exponentiation `^`.
- `eval_factor` – literals, variables, function calls, parenthesized expressions.

`eval_factor` is where **built‑in functions** such as `SIN`, `MID$`, `LEFT$`, etc. are recognized:

```c
if (isalpha((unsigned char)**p)) {
    if (starts_with_kw(*p, "SIN")  || starts_with_kw(*p, "COS")  ||
        starts_with_kw(*p, "MID")  || starts_with_kw(*p, "LEFT") ||
        starts_with_kw(*p, "RIGHT") || /* ... many others ... */ ) {
        char namebuf[8];
        char *q = *p;
        read_identifier(&q, namebuf, sizeof(namebuf));
        return eval_function(namebuf, p);
    } else {
        /* user-defined FN or variable */
    }
}
```

The function name is normalized and mapped to a small `enum` in `function_lookup`, then dispatched in `eval_function`:

```c
enum func_code {
    FN_NONE = 0,
    FN_SIN, FN_COS, FN_TAN, FN_ABS, FN_INT, FN_SQR, FN_SGN,
    FN_EXP, FN_LOG, FN_RND, FN_LEN, FN_STR, FN_CHR,
    FN_ASC, FN_VAL, FN_TAB, FN_SPC,
    FN_MID, FN_LEFT, FN_RIGHT
};
```

`eval_function` handles the common “one argument in parentheses” case for most functions, but leaves multi‑argument functions (such as `MID$`, `LEFT$`, `RIGHT$`) to parse the rest of their arguments and closing `')'` themselves.

Example: the simplified `LEFT$` implementation:

```c
case FN_LEFT: {
    struct value src = arg;
    struct value v_len;
    int sub_len, s_len;

    ensure_str(&src);
    skip_spaces(p);
    if (**p != ',') { runtime_error("LEFT requires 2 arguments"); return make_str(""); }
    (*p)++;
    v_len = eval_expr(p);
    ensure_num(&v_len);
    skip_spaces(p);
    if (**p == ')') (*p)++; else runtime_error("Missing ')'");

    sub_len = (int)v_len.num;
    /* clamp, slice src.str, return make_str(...) */
}
```

To add a new **intrinsic function**:

1. Add a new code to `enum func_code`.
2. Extend `function_lookup` with the upper‑case name and its `$` variant (if any).
3. Teach `eval_factor`’s “function call?” block to recognize your keyword (via `starts_with_kw`).
4. Implement a `case` in `eval_function` to parse arguments and return a `struct value`.

---

### 6. PRINT, column tracking, and ANSI escapes

`PRINT` is implemented by `statement_print` and `print_value`:

- `statement_print` parses a comma/semicolon separated list of expressions:
  - `;` – concatenate with **no extra spacing**, suppress newline if it’s the last token.
  - `,` – advance to the next 10‑column “zone” (`zone = 10`) using `print_spaces`.
  - If the statement **does not end** with `;` or `,`, `PRINT` emits a newline at the end.
  - A bare `PRINT` (no expressions) always emits a newline.

- `print_value`:
  - Prints strings and numbers and keeps `print_col` up to date.
  - Wraps automatically at `PRINT_WIDTH` columns (default is 40 for C64 feel).
  - Treats **ANSI escape sequences** as **zero‑width**, except for explicit cursor‑move CSI codes (`ESC[nC`, `ESC[nD`, `ESC[H`/`ESC[f`), which adjust `print_col` to match the visible cursor.

This combination allows PETSCII → ANSI mappings to behave as expected: color and reverse sequences affect appearance but do not confuse column counting for wrapping and `TAB`.

---

### 7. Adding a new BASIC statement – worked example (`TEXTAT`)

Suppose you want to add a `TEXTAT x, y, text` statement that prints a string at an absolute cursor position using ANSI escapes.

1. **Declare the helper** near the other statement prototypes:

```c
static void statement_textat(char **p);
```

2. **Implement the parser/behavior**, e.g. near `statement_print`:

```c
static void statement_textat(char **p)
{
    struct value vx, vy, vtext;
    int x, y;

    /* TEXTAT x, y, text */
    vx = eval_expr(p);  ensure_num(&vx);
    skip_spaces(p);
    if (**p != ',') { runtime_error("TEXTAT: expected ',' after X"); return; }
    (*p)++;

    vy = eval_expr(p);  ensure_num(&vy);
    skip_spaces(p);
    if (**p != ',') { runtime_error("TEXTAT: expected ',' after Y"); return; }
    (*p)++;

    vtext = eval_expr(p); ensure_str(&vtext);

    x = (int)vx.num; if (x < 0) x = 0;
    y = (int)vy.num; if (y < 0) y = 0;

    /* Move cursor with ANSI: rows/cols are 1-based */
    printf("\033[%d;%dH", y + 1, x + 1);
    fputs(vtext.str, stdout);
    fflush(stdout);
}
```

3. **Wire it into `execute_statement`**:

```c
if (c == 'T' && starts_with_kw(*p, "TEXTAT")) {
    *p += 6;
    statement_textat(p);
    return;
}
```

4. **Add tests** under `tests/` (e.g., `tests/textat.bas`) to exercise success paths and syntax errors, and run them via `./basic tests/textat.bas` and `hexdump -C` if you need exact escape‑code verification.

---

### 8. Implementation tips

- **Always reuse helpers**:
  - Use `eval_expr`, `get_var_reference`, `ensure_num`, `ensure_str`, and `starts_with_kw` rather than re‑parsing tokens by hand.
  - Use `runtime_error` for all user‑visible errors; it will include BASIC line number and source text.

- **Keep new statements small**:
  - Parse just enough to evaluate arguments and then delegate work to small C helpers.

- **Add regression tests**:
  - For any new syntax or behavior, add a tiny program under `tests/` and check its raw output (and exit behavior) in CI.
  - Hex dumps (`hexdump -C`) are very handy when you’re dealing with control codes or PETSCII mappings.

- **Match visible behavior, not just theory**:
  - For PETSCII/ANSI and `PRINT` semantics, compare against an actual C64 emulator or the original `chr.bas`/`adventure.bas` programs whenever in doubt.

This overview should give you enough context to confidently navigate and extend `basic.c`. When in doubt, follow the patterns used by existing statements like `PRINT`, `INPUT`, `SLEEP`, and `GET`—they are intentionally kept as small, readable reference implementations.*** End Patch`}}} -->