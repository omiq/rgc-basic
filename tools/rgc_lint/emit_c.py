"""RGC-BASIC -> C emitter (Tier-1 + Tier-2 + minimal strings/input PoC).

Rides the linter front end: walks the `Statement` stream from
`tokenizer.tokenize` and emits `game`-shaped C that compiles against
retro-c's `platform.h` contract.

SCOPE
  Tier-1: CLS, TEXTAT x,y,s, FOR..TO..[STEP]/NEXT, integer vars.
  Tier-2: IF <cond> THEN <stmt> (single line), relational + AND/OR/NOT,
    DIM (1..3D, literal bounds) + array access, RND(n) -> plat_rand()%n.
  Input/strings (2026-06-16): fixed-length string vars (A$ -> char[N+1]),
    string assignment (literal / var / CHR$), string equality in IF/WHILE,
    TEXTAT of a string var, GET A$ -> plat_getkey_nb (non-blocking char),
    WHILE <cond> / WEND loops.

Still a regex-based walker, NOT the eventual expression AST. The
condition/expression handling is where this strains — that strain is the
trigger for option B (a real parser shared with the linter).
"""

from __future__ import annotations

import re
from typing import Iterable

from .tokenizer import Statement, tokenize
from . import expr as _expr
from . import blocks as _blk
from .expr import Num, Str, Var, Apply, Unary, Binary


class EmitError(Exception):
    pass


# ---- AST -> C (option B: replaces the old regex expr/cond munging) ----------

_REL_NUM = {"=": "==", "<>": "!=", "<": "<", ">": ">", "<=": "<=", ">=": ">="}
# '\\' = BASIC integer division -> C '/' (operands are ints). '^' (power) has no
# portable C operator (no float/pow on cc65) -> rejected at emit (parser accepts it
# so the linter can still see/validate it).
_ARITH = {"+": "+", "-": "-", "*": "*", "/": "/", "MOD": "%", "\\": "/",
          "<<": "<<", ">>": ">>"}


def to_c(node, ctx) -> tuple[str, str]:
    """Walk an expr AST -> (C code, type). type is 'num' or 'str'. Type
    drives '='/'<>' on strings to rgc_seq() instead of ==/!=."""
    if isinstance(node, Num):
        return node.value, "num"
    if isinstance(node, Str):
        return node.value, "str"
    if isinstance(node, Var):
        if node.name.endswith("$"):
            ctx.add_string(node.name)
            return _mangle_str(node.name), "str"
        return node.name, "num"
    if isinstance(node, Apply):
        up = node.name.upper()
        if up in ctx.arrays:
            subs = "".join(f"[{to_c(a, ctx)[0]}]" for a in node.args)
            return node.name + subs, "num"
        if up == "RND":
            ctx.uses_rnd = True
            return f"(plat_rand() % ({to_c(node.args[0], ctx)[0]}))", "num"
        a = [to_c(x, ctx)[0] for x in node.args]
        if up == "CHR$":
            ctx.funcs.add("CHR$")
            return f"rgc_chr({a[0]})", "str"
        if up == "STR$":
            ctx.funcs.add("STR$")
            return f"rgc_str({a[0]})", "str"
        if up == "VAL":
            ctx.funcs.add("VAL")
            return f"rgc_val({a[0]})", "num"
        if up == "LEN":
            ctx.funcs.add("LEN")
            return f"((int)rgc_slen({a[0]}))", "num"
        if up in ("UCASE$", "LCASE$"):
            ctx.funcs.add(up)
            fn = "rgc_ucase" if up == "UCASE$" else "rgc_lcase"
            return f"{fn}({a[0]})", "str"
        if up == "LEFT$":
            ctx.funcs.add("LEFT$")
            return f"rgc_left({a[0]}, {a[1]})", "str"
        if up == "RIGHT$":
            ctx.funcs.add("RIGHT$")
            return f"rgc_right({a[0]}, {a[1]})", "str"
        if up == "MID$":
            ctx.funcs.add("MID$")
            n = a[2] if len(a) >= 3 else str(STRMAX)
            return f"rgc_mid({a[0]}, {a[1]}, {n})", "str"
        raise EmitError(f"unsupported function/array {node.name!r} in expression")
    if isinstance(node, Unary):
        c, _ = to_c(node.operand, ctx)
        return (f"(-{c})" if node.op == "-" else f"(!({c}))"), "num"
    if isinstance(node, Binary):
        lc, lt = to_c(node.left, ctx)
        rc, rt = to_c(node.right, ctx)
        op = node.op
        if op in ("AND", "OR"):
            return f"({lc} {'&&' if op == 'AND' else '||'} {rc})", "num"
        if op == "^":
            raise EmitError("'^' (power) not supported on integer targets "
                            "(no float/pow); use repeated multiply")
        if op == "+" and (lt == "str" or rt == "str"):
            ctx.funcs.add("CAT")
            return f"rgc_scat({lc}, {rc})", "str"
        if op in _ARITH:
            return f"({lc} {_ARITH[op]} {rc})", "num"
        if op in ("=", "<>"):
            if lt == "str" or rt == "str":
                ctx.uses_seq = True
                eq = f"rgc_seq({lc}, {rc})"
                return (eq if op == "=" else f"(!{eq})"), "num"
            return f"({lc} {_REL_NUM[op]} {rc})", "num"
        if op in _REL_NUM:           # < > <= >=
            if lt == "str" or rt == "str":
                raise EmitError(f"string operand not valid with {op!r}")
            return f"({lc} {_REL_NUM[op]} {rc})", "num"
    raise EmitError(f"cannot emit node {node!r}")


def _strip_outer(c: str) -> str:
    """Drop one redundant fully-enclosing paren pair. to_c parenthesises every
    binary for precedence safety; at a call site that already groups (if (...),
    = ...;, [...]) the outermost pair is redundant and trips -Wparentheses."""
    if not (c.startswith("(") and c.endswith(")")):
        return c
    depth = 0
    for i, ch in enumerate(c):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return c[1:-1] if i == len(c) - 1 else c
    return c


def _xlate(e: str, ctx) -> str:
    """Parse a BASIC expression/condition string and emit C."""
    return _strip_outer(to_c(_expr.parse(e), ctx)[0])


STRMAX = 40   # fixed string-var capacity (chars); char[STRMAX+1]

_FOR_RE = re.compile(
    r"^\s*([A-Za-z_]\w*)\s*=\s*(.+?)\s+TO\s+(.+?)(?:\s+STEP\s+(.+?))?\s*$",
    re.IGNORECASE,
)
_RHS_RE = re.compile(r"^\s*=\s*(.+?)\s*$")
_ARRAY_ASSIGN_RE = re.compile(r"^\s*\(([^)]*)\)\s*=\s*(.+?)\s*$")
_DIM_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*\(([^)]*)\)\s*$")
_IF_RE = re.compile(r"^\s*(.+?)\s+THEN\s+(.+?)\s*$", re.IGNORECASE)
_STRVAR_RE = re.compile(r"[A-Za-z_]\w*\$")
_STRLIT_RE = re.compile(r'^"[^"]*"$')
_CHR_RE = re.compile(r"^\s*CHR\$\s*\((.+)\)\s*$", re.IGNORECASE)

_KEYWORDS = {"CLS", "TEXTAT", "FOR", "NEXT", "IF", "DIM", "REM",
             "GET", "WHILE", "WEND", "PRINT", "LOCATE"}


def _split_print(rest: str) -> list:
    """Split a PRINT list on top-level ';' and ',' (respecting quotes/parens).
    Returns [(expr, sep), ...] where sep is the separator AFTER expr ('' last)."""
    items, buf, depth, in_str = [], [], 0, False
    for c in rest:
        if c == '"':
            in_str = not in_str; buf.append(c)
        elif in_str:
            buf.append(c)
        elif c == "(":
            depth += 1; buf.append(c)
        elif c == ")":
            depth -= 1; buf.append(c)
        elif c in ";," and depth == 0:
            items.append(("".join(buf).strip(), c)); buf = []
        else:
            buf.append(c)
    items.append(("".join(buf).strip(), ""))
    return items


def _emit_print(rest: str, ctx: "Ctx") -> str:
    ctx.uses_print = True
    if not rest.strip():
        return "rgc_nl();"
    items = _split_print(rest)
    suppress = False
    if items and items[-1][0] == "":
        items.pop(); suppress = True
    out = []
    for e, sep in items:
        code, typ = to_c(_expr.parse(e), ctx)
        if typ == "str":
            out.append(f"rgc_pstr({code});")
        else:
            ctx.funcs.add("STR$")
            out.append(f"rgc_pstr(rgc_str({code}));")
        if sep == ",":
            ctx.uses_tab = True
            out.append("rgc_tab();")
    if not suppress:
        out.append("rgc_nl();")
    return " ".join(out)


def _emit_locate(rest: str, ctx: "Ctx") -> str:
    ctx.uses_print = True
    args = _split_args(rest)
    if len(args) != 2:
        raise EmitError(f"LOCATE needs x, y (got {len(args)})")
    return (f"rgc_cx = (unsigned char)({_xlate(args[0], ctx)}); "
            f"rgc_cy = (unsigned char)({_xlate(args[1], ctx)});")


def _split_args(rest: str) -> list[str]:
    """Top-level comma split, respecting quotes and nested parens."""
    args, buf, depth, in_str = [], [], 0, False
    for c in rest:
        if c == '"':
            in_str = not in_str
            buf.append(c)
        elif in_str:
            buf.append(c)
        elif c == "(":
            depth += 1; buf.append(c)
        elif c == ")":
            depth -= 1; buf.append(c)
        elif c == "," and depth == 0:
            args.append("".join(buf).strip()); buf = []
        else:
            buf.append(c)
    if buf:
        args.append("".join(buf).strip())
    return [a for a in args if a != ""]


def _mangle_str(name: str) -> str:
    """A$ -> A_str (C-safe identifier for a string var)."""
    return name.rstrip("$") + "_str"


def _is_strvar(tok: str) -> bool:
    return tok.endswith("$") and bool(re.fullmatch(r"[A-Za-z_]\w*\$", tok))


class Ctx:
    def __init__(self) -> None:
        self.scalars: list[str] = []
        self.arrays: dict[str, int] = {}
        self.array_decls: list[str] = []
        self.strings: list[str] = []           # original names (with $)
        self.uses_rnd = False
        self.uses_seq = False                   # string equality (rgc_seq)
        self.uses_scpy = False                  # string copy (rgc_scpy)
        self.uses_print = False                 # PRINT/LOCATE cursor runtime
        self.uses_tab = False                   # PRINT ',' zone tab
        self.funcs: set[str] = set()            # string/len builtins used

    def add_scalar(self, n: str) -> None:
        u = n.upper()
        if u not in self.arrays and all(s.upper() != u for s in self.scalars):
            self.scalars.append(n)

    def add_string(self, n: str) -> None:
        if all(s.upper() != n.upper() for s in self.strings):
            self.strings.append(n)


# Expressions and conditions now go through the AST (expr.parse -> to_c).
# Both numeric exprs and conditions use the same path; to_c's type inference
# routes string '='/'<>' to rgc_seq() and numerics to ==/!=.
def _xlate_expr(e: str, ctx: Ctx) -> str:
    return _xlate(e, ctx)


def _xlate_cond(e: str, ctx: Ctx) -> str:
    return _xlate(e, ctx)


def _str_ref(tok: str) -> str:
    """A string operand token -> C: literal stays, A$ -> A_str. Used by the
    statement-level string paths (assignment RHS, TEXTAT text arg)."""
    tok = tok.strip()
    if _STRLIT_RE.match(tok):
        return tok
    if _is_strvar(tok):
        return _mangle_str(tok)
    raise EmitError(f"not a string operand: {tok!r}")


def _dim_size(bound: str) -> str:
    b = bound.strip()
    if re.fullmatch(r"\d+", b):
        return str(int(b) + 1)
    return f"({b})+1"


def _collect(statements: list[Statement], ctx: Ctx) -> None:
    for s in statements:
        # string vars: any A$ token anywhere — but a `$`-name followed by '('
        # is a string FUNCTION call (UCASE$, LEFT$, CHR$...), not a variable.
        text = (s.first_word or "") + " " + (s.rest or "")
        for m in _STRVAR_RE.finditer(text):
            if text[m.end():m.end() + 1] == "(":
                continue
            ctx.add_string(m.group(0))
        if s.first_word == "DIM":
            # DIM may declare several arrays: DIM A(5), B(3,3), C(9)
            for decl in _split_args(s.rest):
                if "$" in decl:
                    raise EmitError(
                        f"line {s.line}: string arrays not supported yet: {decl!r}")
                m = _DIM_RE.match(decl)
                if not m:
                    raise EmitError(f"line {s.line}: malformed DIM: {decl!r}")
                name, dims = m.group(1), _split_args(m.group(2))
                ctx.arrays[name.upper()] = len(dims)
                sizes = "".join(f"[{_dim_size(d)}]" for d in dims)
                ctx.array_decls.append(f"int {name}{sizes};")
        elif s.first_word == "FOR":
            m = _FOR_RE.match(s.rest)
            if m:
                ctx.add_scalar(m.group(1))
        elif (s.first_word and s.first_word not in _KEYWORDS
              and not _is_strvar(s.first_word)
              and s.first_word.upper() not in ctx.arrays
              and _RHS_RE.match(s.rest)):
            ctx.add_scalar(s.first_word)


def _emit_get(strvar: str, ctx: Ctx) -> str:
    """GET A$ -> non-blocking single char (empty string if no key)."""
    if not _is_strvar(strvar):
        raise EmitError(f"GET requires a string variable, got {strvar!r}")
    ctx.add_string(strvar)
    dst = _mangle_str(strvar)
    return ("{ unsigned char _k = plat_getkey_nb(); "
            f"{dst}[0] = (char)_k; {dst}[1] = (char)0; }}")


def _emit_str_assign(name: str, rhs: str, ctx: Ctx) -> str:
    """A$ = <string expr>. The RHS goes through the AST (literal, string var,
    CHR$/UCASE$/LEFT$/... all return char*) and is copied into the var."""
    dst = _mangle_str(name)
    code, typ = to_c(_expr.parse(rhs), ctx)
    if typ != "str":
        raise EmitError(f"string variable {name} assigned a numeric value")
    ctx.uses_scpy = True
    return f"rgc_scpy({dst}, {code});"


def _emit_simple(stmt: Statement, ctx: Ctx) -> str:
    kw = stmt.first_word
    rest = stmt.rest
    if kw == "CLS":
        return "plat_cls();"
    if kw == "PRINT":
        return _emit_print(rest, ctx)
    if kw == "LOCATE":
        return _emit_locate(rest, ctx)
    if kw == "GET":
        return _emit_get(rest.strip(), ctx)
    if kw == "TEXTAT":
        args = _split_args(rest)
        if len(args) != 3:
            raise EmitError(
                f"line {stmt.line}: TEXTAT needs x, y, text (got {len(args)})")
        x, y, txt = args
        if _STRLIT_RE.match(txt) or _is_strvar(txt):
            text_c = _str_ref(txt)
        else:
            raise EmitError(f"line {stmt.line}: TEXTAT text must be a "
                            f"string literal or string var, got {txt!r}")
        return (f"plat_puts((unsigned char)({_xlate_expr(x, ctx)}), "
                f"(unsigned char)({_xlate_expr(y, ctx)}), {text_c}, COL_WHITE);")
    if _is_strvar(kw):
        m = _RHS_RE.match(rest)
        if not m:
            raise EmitError(f"line {stmt.line}: bad string assignment: {rest!r}")
        return _emit_str_assign(kw, m.group(1), ctx)
    if kw and kw.upper() in ctx.arrays:
        m = _ARRAY_ASSIGN_RE.match(rest)
        if not m:
            raise EmitError(f"line {stmt.line}: bad array assignment: {rest!r}")
        subs = _split_args(m.group(1))
        lhs = kw + "".join(f"[{_xlate_expr(s, ctx)}]" for s in subs)
        return f"{lhs} = {_xlate_expr(m.group(2), ctx)};"
    if kw and kw not in _KEYWORDS:
        m = _RHS_RE.match(rest)
        if m:
            return f"{kw} = {_xlate_expr(m.group(1), ctx)};"
    raise EmitError(
        f"line {stmt.line}: unsupported statement {kw!r} in this position")


def _emit_helpers(ctx: "Ctx") -> str:
    """Inline runtime helpers (no libc): string copy/compare + the string
    functions actually used. String-returning functions write into a small
    rotating static pool so they compose in expressions (BASIC string-temp
    idiom). Emitted only when needed; dependency order preserved."""
    parts: list[str] = []
    if ctx.uses_print:
        # Flowing-text cursor built on plat_puts (the contract has no cursor).
        # No scroll: at the bottom row PRINT clamps (plat has no scroll/read).
        parts.append(
            "static unsigned char rgc_cx = 0, rgc_cy = 0;\n"
            "static void rgc_pstr(const char *s) {\n"
            "    plat_puts(rgc_cx, rgc_cy, s, COL_WHITE);\n"
            "    while (*s++) rgc_cx++;\n"
            "}\n"
            "static void rgc_nl(void) {\n"
            "    rgc_cx = 0;\n"
            "    if (rgc_cy + 1 < plat_screen_h()) rgc_cy++;\n"
            "}\n")
    if ctx.uses_tab:
        parts.append(
            "static void rgc_tab(void) {\n"
            "    rgc_cx = (unsigned char)(((rgc_cx / 10) + 1) * 10);\n"
            "}\n")
    if ctx.uses_scpy:
        parts.append(
            "static void rgc_scpy(char *d, const char *s) {\n"
            "    while ((*d++ = *s++) != 0) {}\n"
            "}\n")
    if ctx.uses_seq:
        parts.append(
            "static unsigned char rgc_seq(const char *a, const char *b) {\n"
            "    while (*a && *a == *b) { a++; b++; }\n"
            "    return (unsigned char)(*a == *b);\n"
            "}\n")
    f = ctx.funcs
    need_left = bool(f & {"LEFT$", "RIGHT$", "MID$"})
    need_pool = need_left or bool(f & {"UCASE$", "LCASE$", "CHR$", "STR$", "CAT"})
    need_slen = bool(f & {"LEN", "RIGHT$", "MID$"})
    if need_slen:
        parts.append(
            "static unsigned rgc_slen(const char *s) {\n"
            "    unsigned n = 0; while (*s++) n++; return n;\n"
            "}\n")
    if need_pool:
        parts.append(
            f"static char rgc_pool[4][{STRMAX + 1}];\n"
            "static unsigned char rgc_pi = 0;\n")
    if "CHR$" in f:
        parts.append(
            "static char *rgc_chr(int n) {\n"
            "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3];\n"
            "    d[0] = (char)n; d[1] = 0; return d;\n"
            "}\n")
    if "CAT" in f:
        parts.append(
            "static char *rgc_scat(const char *a, const char *b) {\n"
            "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3]; int i = 0;\n"
            f"    while (*a && i < {STRMAX}) {{ d[i++] = *a++; }}\n"
            f"    while (*b && i < {STRMAX}) {{ d[i++] = *b++; }}\n"
            "    d[i] = 0; return d;\n"
            "}\n")
    if "STR$" in f:
        parts.append(
            "static char *rgc_str(int n) {\n"
            "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3]; char t[7]; int i = 0, j = 0;\n"
            "    unsigned u; if (n < 0) { d[j++] = '-'; u = (unsigned)(-n); } else u = (unsigned)n;\n"
            "    do { t[i++] = (char)('0' + u % 10); u /= 10; } while (u);\n"
            "    while (i) d[j++] = t[--i];\n"
            "    d[j] = 0; return d;\n"
            "}\n")
    if "VAL" in f:
        parts.append(
            "static int rgc_val(const char *s) {\n"
            "    int n = 0, sign = 1;\n"
            "    while (*s == ' ') s++;\n"
            "    if (*s == '-') { sign = -1; s++; } else if (*s == '+') s++;\n"
            "    while (*s >= '0' && *s <= '9') n = n * 10 + (*s++ - '0');\n"
            "    return n * sign;\n"
            "}\n")
    for which in ("UCASE$", "LCASE$"):
        if which in f:
            name = "rgc_ucase" if which == "UCASE$" else "rgc_lcase"
            lo, hi, adj = ("'a'", "'z'", "- 32") if which == "UCASE$" else ("'A'", "'Z'", "+ 32")
            parts.append(
                f"static char *{name}(const char *s) {{\n"
                "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3], *o = d;\n"
                f"    unsigned n = 0;\n"
                f"    while (*s && n < {STRMAX}) {{ char c = *s++;\n"
                f"        if (c >= {lo} && c <= {hi}) c = (char)(c {adj});\n"
                "        *o++ = c; n++; }\n"
                "    *o = 0; return d;\n"
                "}\n")
    if need_left:
        parts.append(
            "static char *rgc_left(const char *s, int n) {\n"
            "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3]; int i = 0;\n"
            f"    if (n > {STRMAX}) n = {STRMAX};\n"
            "    while (i < n && s[i]) { d[i] = s[i]; i++; }\n"
            "    d[i] = 0; return d;\n"
            "}\n")
    if "RIGHT$" in f:
        parts.append(
            "static char *rgc_right(const char *s, int n) {\n"
            "    int L = (int)rgc_slen(s);\n"
            "    if (n > L) n = L; if (n < 0) n = 0;\n"
            "    return rgc_left(s + L - n, n);\n"
            "}\n")
    if "MID$" in f:
        parts.append(
            "static char *rgc_mid(const char *s, int p, int n) {\n"
            "    int L = (int)rgc_slen(s);\n"
            "    if (p < 1) p = 1;\n"
            "    if (p > L) return rgc_left(s + L, 0);\n"
            "    return rgc_left(s + (p - 1), n);\n"
            "}\n")
    return ("".join(parts) + "\n") if parts else ""


def _emit_if_single(stmt: Statement, ctx: Ctx) -> str:
    """Single-line IF cond THEN stmt -> one-line C if."""
    m = _IF_RE.match(stmt.rest)
    if not m:
        raise EmitError(f"line {stmt.line}: IF needs THEN: {stmt.rest!r}")
    cond, then_src = m.groups()
    then_stmt = next(tokenize(then_src), None)
    if then_stmt is None:
        raise EmitError(f"line {stmt.line}: empty THEN")
    then_stmt.line = stmt.line
    return (f"if ({_xlate_cond(cond, ctx)}) {{ "
            f"{_emit_simple(then_stmt, ctx)} }}")


def _emit_nodes(nodes: list, ctx: Ctx, out: list[str], indent: int) -> None:
    """Recursively lower a list of block-tree nodes to C lines."""
    def line(txt: str) -> None:
        out.append("    " * indent + txt)

    for n in nodes:
        if isinstance(n, _blk.Line):
            s = n.stmt
            if s.first_word in ("DIM", "REM"):
                continue
            line(_emit_simple(s, ctx))
        elif isinstance(n, _blk.For):
            m = _FOR_RE.match(n.head.rest)
            if not m:
                raise EmitError(f"line {n.head.line}: malformed FOR: {n.head.rest!r}")
            var, start, end, step = m.groups()
            step_expr = _xlate_expr(step, ctx) if step else "1"
            line(f"for ({var} = {_xlate_expr(start, ctx)}; "
                 f"{var} <= {_xlate_expr(end, ctx)}; {var} += {step_expr}) {{")
            _emit_nodes(n.body, ctx, out, indent + 1)
            line("}")
        elif isinstance(n, _blk.While):
            line(f"while ({_xlate_cond(n.head.rest, ctx)}) {{")
            _emit_nodes(n.body, ctx, out, indent + 1)
            line("}")
        elif isinstance(n, _blk.IfSingle):
            line(_emit_if_single(n.stmt, ctx))
        else:
            kind = type(n).__name__
            ln = getattr(getattr(n, "head", None) or getattr(n, "stmt", None),
                         "line", "?")
            raise EmitError(f"line {ln}: {kind} not supported yet")


def emit(source: str) -> str:
    statements = [s for s in tokenize(source) if s.first_word != "REM"]
    ctx = Ctx()
    _collect(statements, ctx)

    program = _blk.parse_blocks(statements)
    if program.functions:
        fn = program.functions[0]
        raise EmitError(f"line {fn.head.line}: user FUNCTIONs not supported yet")

    body: list[str] = []
    _emit_nodes(program.main, ctx, body, 1)

    decls = ""
    if ctx.scalars:
        decls += "    int " + ", ".join(ctx.scalars) + ";\n"
    for d in ctx.array_decls:
        decls += "    " + d + "\n"
    for sv in ctx.strings:
        decls += f"    char {_mangle_str(sv)}[{STRMAX + 1}];\n"

    seed = ("    plat_seed_rand(1);   /* fixed non-zero seed -> deterministic RND */\n"
            if ctx.uses_rnd else "")

    # String helpers emitted inline (NOT <string.h>): not every retro
    # toolchain ships a usable <string.h> (cmoc doesn't), so the transpiler
    # carries its own. rgc_seq returns 1 when equal.
    helpers = _emit_helpers(ctx)

    # Faithful BASIC END: draw and return to READY/OS, screen left as-is.
    return (
        '#include "platform.h"\n\n'
        + helpers
        + "int main(void) {\n"
        + decls
        + "    plat_init();\n"
        + seed
        + "\n".join(body) + "\n"
        + "    return 0;\n"
        "}\n"
    )


if __name__ == "__main__":
    import sys
    src = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    sys.stdout.write(emit(src))
