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


def _real_lit(value: str) -> str:
    """A BASIC real literal token -> RGC_LIT(fixedbits, floatval). The emitter
    pre-computes the 16.16 fixed bits so the cc65 path never sees a float."""
    f = float(value)
    bits = int(round(f * 65536.0))
    fv = value if ("." in value or "e" in value.lower()) else value + ".0"
    return f"RGC_LIT({bits}L, {fv}f)"


def _to_real(code: str, typ: str, ctx: Ctx) -> str:
    """Promote a numeric (code,typ) to an rgc_real expression."""
    ctx.uses_real = True
    if typ == "real":
        return code
    return f"RGC_FROMINT({code})"


def to_c(node, ctx) -> tuple[str, str]:
    """Walk an expr AST -> (C code, type). type is 'int' | 'real' | 'str'.
    Real arithmetic goes through the RGC_* macros (rgc_real.h); ints promote
    to real on demand. String '='/'<>' route to rgc_seq()."""
    if isinstance(node, Num):
        if "." in node.value:
            ctx.uses_real = True
            return _real_lit(node.value), "real"
        return node.value, "int"
    if isinstance(node, Str):
        return node.value, "str"
    if isinstance(node, Var):
        if node.name.endswith("$"):
            if node.name.upper() not in ctx.cur_params:
                ctx.add_string(node.name)   # param strings are C locals, not globals
            return _mangle_str(node.name), "str"
        t = "real" if _var_is_real(node.name.upper(), ctx) else "int"
        if t == "real":
            ctx.uses_real = True
        return node.name, t
    if isinstance(node, Apply):
        up = node.name.upper()
        if up in ctx.arrays:
            # array subscripts must be C ints — floor any real index
            subs = ""
            for arg in node.args:
                ic, it = to_c(arg, ctx)
                subs += f"[{f'RGC_TOINT({ic})' if it == 'real' else _strip_outer(ic)}]"
            t = "real" if up in ctx.real_arrays else "int"
            if t == "real":
                ctx.uses_real = True
            return node.name + subs, t
        if up == "RND":
            ctx.uses_rnd = True
            ctx.uses_rrnd = True
            ctx.uses_real = True
            if node.args:                    # arg only matters by sign (reseed)
                to_c(node.args[0], ctx)
            return "rgc_rnd()", "real"
        if up == "INT":
            ic, it = to_c(node.args[0], ctx)
            if it == "int":
                return ic, "int"          # INT of an int is identity
            return f"RGC_TOINT({ic})", "int"
        if up == "ABS":
            ic, it = to_c(node.args[0], ctx)
            if it == "real":
                return f"RGC_ABS({ic})", "real"
            return f"(({ic}) < 0 ? -({ic}) : ({ic}))", "int"
        if up == "SQR":
            ic, it = to_c(node.args[0], ctx)
            return f"rgc_sqrt({_to_real(ic, it, ctx)})", "real"
        a = [to_c(x, ctx)[0] for x in node.args]
        if up == "CHR$":
            ctx.funcs.add("CHR$")
            return f"rgc_chr({a[0]})", "str"
        if up == "STR$":
            ctx.funcs.add("STR$")
            return f"rgc_str({a[0]})", "str"
        if up == "VAL":
            ctx.funcs.add("VAL")
            return f"rgc_val({a[0]})", "int"
        if up == "LEN":
            ctx.funcs.add("LEN")
            return f"((int)rgc_slen({a[0]}))", "int"
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
        if up in ctx.udfs:
            u = ctx.udfs[up]
            t = "str" if u["ret"] == "str" else ("real" if up in ctx.udf_real else "int")
            if t == "real":
                ctx.uses_real = True
            return f"{u['cname']}({', '.join(a)})", t
        raise EmitError(f"unsupported function/array {node.name!r} in expression")
    if isinstance(node, Unary):
        c, t = to_c(node.operand, ctx)
        if node.op == "!":
            return f"(!({c}))", "int"
        return (f"RGC_NEG({c})" if t == "real" else f"(-{c})"), t
    if isinstance(node, Binary):
        lc, lt = to_c(node.left, ctx)
        rc, rt = to_c(node.right, ctx)
        op = node.op
        if op in ("AND", "OR"):
            return f"({lc} {'&&' if op == 'AND' else '||'} {rc})", "int"
        if op == "+" and (lt == "str" or rt == "str"):
            ctx.funcs.add("CAT")
            return f"rgc_scat({lc}, {rc})", "str"
        if op == "^":
            return _emit_power(node.left, node.right, ctx)
        if op == "/":           # BASIC '/' is always real division
            return (f"RGC_DIV({_to_real(lc, lt, ctx)}, {_to_real(rc, rt, ctx)})",
                    "real")
        if op in ("\\", "MOD", "<<", ">>"):     # integer ops: floor real operands
            li = f"RGC_TOINT({lc})" if lt == "real" else lc
            ri = f"RGC_TOINT({rc})" if rt == "real" else rc
            return f"({li} {_ARITH[op]} {ri})", "int"
        if op in ("+", "-", "*"):
            if lt == "real" or rt == "real":
                fn = {"+": "RGC_ADD", "-": "RGC_SUB", "*": "RGC_MUL"}[op]
                return f"{fn}({_to_real(lc, lt, ctx)}, {_to_real(rc, rt, ctx)})", "real"
            return f"({lc} {_ARITH[op]} {rc})", "int"
        if op in ("=", "<>"):
            if lt == "str" or rt == "str":
                ctx.uses_seq = True
                eq = f"rgc_seq({lc}, {rc})"
                return (eq if op == "=" else f"(!{eq})"), "int"
            return _rel(op, lc, lt, rc, rt, ctx), "int"
        if op in _REL_NUM:           # < > <= >=
            if lt == "str" or rt == "str":
                raise EmitError(f"string operand not valid with {op!r}")
            return _rel(op, lc, lt, rc, rt, ctx), "int"
    raise EmitError(f"cannot emit node {node!r}")


def _rel(op, lc, lt, rc, rt, ctx) -> str:
    """Relational compare. Fixed-point is monotonic so plain operators work on
    real operands too; just promote a mixed int operand to real first."""
    if lt == "real" or rt == "real":
        lc, rc = _to_real(lc, lt, ctx), _to_real(rc, rt, ctx)
    return f"({lc} {_REL_NUM[op]} {rc})"


def _emit_power(base_node, exp_node, ctx) -> tuple[str, str]:
    """x ^ n. Only integer-literal exponents (trek uses ^2). Repeated RGC_MUL,
    so no pow()/float lib needed on any target."""
    if not (isinstance(exp_node, Num) and "." not in exp_node.value):
        raise EmitError("'^' supported only with an integer literal exponent")
    n = int(exp_node.value)
    bc, bt = to_c(base_node, ctx)
    br = _to_real(bc, bt, ctx)
    if n == 0:
        return _real_lit("1.0"), "real"
    if n < 0:
        return f"RGC_DIV({_real_lit('1.0')}, {_pow_mul(br, -n)})", "real"
    return _pow_mul(br, n), "real"


def _pow_mul(code: str, n: int) -> str:
    out = code
    for _ in range(n - 1):
        out = f"RGC_MUL({out}, {code})"
    return out


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
        elif typ == "real":
            ctx.uses_rstr = True
            out.append(f"rgc_pstr(rgc_realstr({_strip_outer(code)}));")
        else:
            ctx.funcs.add("STR$")
            out.append(f"rgc_pstr(rgc_str({_strip_outer(code)}));")
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


_FNHEAD_RE = re.compile(r"^\s*([A-Za-z_]\w*\$?)\s*(?:\(([^)]*)\))?\s*$")


def _parse_fn_header(rest: str):
    """'PlaceToken(TOKEN$, X, Y)' -> ('PlaceToken', [('TOKEN$',True),('X',F),('Y',F)]).
    Returns (orig_name, params). DEF FN headers ('FND(D)=...') handled by caller."""
    m = _FNHEAD_RE.match(rest)
    if not m:
        raise EmitError(f"malformed FUNCTION header: {rest!r}")
    name = m.group(1)
    params = []
    if m.group(2) and m.group(2).strip():
        for p in _split_args(m.group(2)):
            p = p.strip()
            params.append((p, p.endswith("$")))
    return name, params


def _udf_ret(name: str) -> str:
    """Return type from name: NAME$ -> 'str', else 'num'."""
    return "str" if name.endswith("$") else "num"


def _udf_cname(name: str) -> str:
    """BASIC fn name -> C-safe identifier. Greet$ -> Greet_str (no '$' in C)."""
    return name[:-1] + "_str" if name.endswith("$") else name


def _c_ret_type(ret: str, real: bool = False) -> str:
    if ret == "str":
        return "const char *"
    return "rgc_real" if real else "int"


def _is_strvar(tok: str) -> bool:
    return tok.endswith("$") and bool(re.fullmatch(r"[A-Za-z_]\w*\$", tok))


class Ctx:
    def __init__(self) -> None:
        self.scalars: list[str] = []
        self.arrays: dict[str, int] = {}
        self.array_sizes: dict[str, str] = {}   # NAME -> C subscript string
        self.strings: list[str] = []           # original names (with $)
        self.uses_rnd = False
        self.uses_seq = False                   # string equality (rgc_seq)
        self.uses_scpy = False                  # string copy (rgc_scpy)
        self.uses_print = False                 # PRINT/LOCATE cursor runtime
        self.uses_tab = False                   # PRINT ',' zone tab
        self.funcs: set[str] = set()            # string/len builtins used
        self.udfs: dict[str, dict] = {}         # UPPER -> {name, ret, params}
        self.cur_ret = "int"                    # return type of fn being emitted
        self.cur_ret_real = False               # fn being emitted returns real
        self.cur_params: set[str] = set()       # param UPPER names in scope
        self.cur_fn = ""                        # UPPER name of fn being emitted
        self.uses_real = False                  # any rgc_real used -> emit runtime
        self.uses_rrnd = False                  # real RND helper
        self.uses_rstr = False                  # real -> string formatter
        self.real_scalars: set[str] = set()     # scalar UPPER names typed real
        self.real_arrays: set[str] = set()      # array UPPER names typed real
        self.real_params: set[tuple] = set()    # (FN_UPPER, PARAM_UPPER) typed real
        self.udf_real: set[str] = set()         # UDF UPPER names returning real
        self._tmp = 0                           # unique temp-id counter

    def next_tmp(self) -> int:
        self._tmp += 1
        return self._tmp

    def add_scalar(self, n: str) -> None:
        u = n.upper()
        if u not in self.arrays and all(s.upper() != u for s in self.scalars):
            self.scalars.append(n)

    def add_string(self, n: str) -> None:
        if all(s.upper() != n.upper() for s in self.strings):
            self.strings.append(n)


# ---- numeric type inference (int vs real) -----------------------------------
# BASIC numeric vars are floating point; we keep a var/array/param INT unless an
# assignment or use proves it real, then propagate to a fixpoint. Fewer reals =
# less fixed-point overhead, so INT() is treated as producing an int.

_REAL_FUNCS = {"SQR", "SIN", "COS", "TAN", "ATN", "VAL"}


def _var_is_real(nu: str, ctx: Ctx) -> bool:
    if nu in ctx.cur_params:
        return (ctx.cur_fn, nu) in ctx.real_params
    return nu in ctx.real_scalars


def _expr_type(node, ctx: Ctx) -> str:
    """'int' | 'real' | 'str' using the current (in-progress) real sets."""
    if isinstance(node, Num):
        return "real" if "." in node.value else "int"
    if isinstance(node, Str):
        return "str"
    if isinstance(node, Var):
        if node.name.endswith("$"):
            return "str"
        return "real" if _var_is_real(node.name.upper(), ctx) else "int"
    if isinstance(node, Apply):
        up = node.name.upper()
        if up in ctx.arrays:
            return "real" if up in ctx.real_arrays else "int"
        if up == "RND" or up in _REAL_FUNCS:
            return "real"
        if up == "INT":
            return "int"
        if up == "ABS":
            return _expr_type(node.args[0], ctx) if node.args else "int"
        if up == "LEN":
            return "int"
        if up in ("CHR$", "STR$", "UCASE$", "LCASE$", "LEFT$", "RIGHT$", "MID$"):
            return "str"
        if up in ctx.udfs:
            if ctx.udfs[up]["ret"] == "str":
                return "str"
            return "real" if up in ctx.udf_real else "int"
        return "int"
    if isinstance(node, Unary):
        return "int" if node.op == "!" else _expr_type(node.operand, ctx)
    if isinstance(node, Binary):
        op = node.op
        if op in ("AND", "OR", "=", "<>", "<", ">", "<=", ">="):
            return "int"
        if op in ("\\", "MOD", "<<", ">>"):
            return "int"
        if op in ("/", "^"):
            return "real"
        lt = _expr_type(node.left, ctx)
        rt = _expr_type(node.right, ctx)
        if op == "+" and (lt == "str" or rt == "str"):
            return "str"
        return "real" if "real" in (lt, rt) else "int"
    return "int"


def _assign_target(s: Statement):
    """If statement is an assignment, return (kind, name) where kind is
    'scalar'|'array'|'string', else None. Mirrors _emit_simple dispatch."""
    kw = s.first_word
    if not kw or kw in _KEYWORDS or kw in ("RETURN", "END"):
        return None
    if _is_strvar(kw):
        return ("string", kw)
    if kw.upper() in ("DIM",):
        return None
    if _ARRAY_ASSIGN_RE.match(s.rest or ""):
        return ("array", kw)
    if _RHS_RE.match(s.rest or ""):
        return ("scalar", kw)
    return None


def _infer_types(program, ctx: Ctx) -> None:
    """Fixpoint: mark scalars/arrays/params/udf-returns real where an
    assignment RHS (or FOR bound, or RETURN) is real."""
    # gather (scope_fn_upper, params_set, statements) per scope
    scopes = [("", set(), list(_iter_stmts(program.main)))]
    for fn in program.functions:
        nm, params = _parse_fn_header(fn.head.rest)
        scopes.append((nm.upper(), {p.upper() for p, _ in params},
                       list(_iter_stmts(fn.body))))

    def mark_real(nu, fn_upper, params):
        if nu in params:
            key = (fn_upper, nu)
            if key not in ctx.real_params:
                ctx.real_params.add(key); return True
        elif nu in ctx.arrays:
            if nu not in ctx.real_arrays:
                ctx.real_arrays.add(nu); return True
        elif nu not in ctx.real_scalars:
            ctx.real_scalars.add(nu); return True
        return False

    changed = True
    while changed:
        changed = False
        for fn_upper, params, stmts in scopes:
            ctx.cur_fn, ctx.cur_params = fn_upper, params
            for s in stmts:
                # assignment RHS
                tgt = _assign_target(s)
                if tgt:
                    kind, name = tgt
                    if kind == "string":
                        continue
                    rhs = _RHS_RE.match(s.rest) or _ARRAY_ASSIGN_RE.match(s.rest)
                    rhs_expr = rhs.group(2) if kind == "array" else rhs.group(1)
                    try:
                        if _expr_type(_expr.parse(rhs_expr), ctx) == "real":
                            nm2 = (name if kind == "array" else name).upper()
                            if mark_real(nm2, fn_upper, params):
                                changed = True
                    except Exception:
                        pass
                # FOR counter
                elif s.first_word == "FOR":
                    m = _FOR_RE.match(s.rest)
                    if m:
                        bounds = [m.group(2), m.group(3)] + (
                            [m.group(4)] if m.group(4) else [])
                        try:
                            if any(_expr_type(_expr.parse(b), ctx) == "real"
                                   for b in bounds):
                                if mark_real(m.group(1).upper(), fn_upper, params):
                                    changed = True
                        except Exception:
                            pass
                # RETURN expr -> function return real
                elif s.first_word == "RETURN" and fn_upper and s.rest.strip():
                    try:
                        if _expr_type(_expr.parse(s.rest.strip()), ctx) == "real":
                            if fn_upper not in ctx.udf_real:
                                ctx.udf_real.add(fn_upper); changed = True
                    except Exception:
                        pass
                # call args -> param real-ness (any scope's calls)
                for ftup, ptypes in _calls_in(s, ctx):
                    udf = ctx.udfs.get(ftup)
                    if not udf:
                        continue
                    for (pn, _is), at in zip(udf["params"], ptypes):
                        if at == "real":
                            key = (ftup, pn.upper())
                            if key not in ctx.real_params:
                                ctx.real_params.add(key); changed = True
        ctx.cur_fn, ctx.cur_params = "", set()


def _calls_in(s: Statement, ctx: Ctx):
    """Yield (FN_UPPER, [argtype,...]) for UDF calls in a statement's exprs."""
    text = s.rest or ""
    if not text:
        return
    try:
        node = _expr.parse(text.lstrip("="))
    except Exception:
        return
    out = []

    def walk(n):
        if isinstance(n, Apply):
            up = n.name.upper()
            if up in ctx.udfs:
                out.append((up, [_expr_type(a, ctx) for a in n.args]))
            for a in n.args:
                walk(a)
        elif isinstance(n, Binary):
            walk(n.left); walk(n.right)
        elif isinstance(n, Unary):
            walk(n.operand)
    walk(node)
    yield from out


# Expressions and conditions now go through the AST (expr.parse -> to_c).
# Both numeric exprs and conditions use the same path; to_c's type inference
# routes string '='/'<>' to rgc_seq() and numerics to ==/!=.
def _xlate_expr(e: str, ctx: Ctx) -> str:
    return _xlate(e, ctx)


def _xlate_cond(e: str, ctx: Ctx) -> str:
    return _xlate(e, ctx)


def _xlate_to(e: str, target_real: bool, ctx: Ctx) -> str:
    """Translate an expression and coerce it to the assignment target's type."""
    code, typ = to_c(_expr.parse(e), ctx)
    code = _strip_outer(code)
    if target_real and typ == "int":
        ctx.uses_real = True
        return f"RGC_FROMINT({code})"
    if not target_real and typ == "real":
        return f"RGC_TOINT({code})"
    return code


def _idx(e: str, ctx: Ctx) -> str:
    """An array subscript expression -> C int (floor a real index)."""
    code, typ = to_c(_expr.parse(e), ctx)
    return f"RGC_TOINT({code})" if typ == "real" else _strip_outer(code)


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


def _iter_stmts(nodes: list):
    """Yield every Statement in a block-tree node list (recurses into bodies).
    Does NOT descend into Function nodes — callers collect per-scope."""
    for n in nodes:
        if isinstance(n, _blk.Line):
            yield n.stmt
        elif isinstance(n, _blk.IfSingle):
            yield n.stmt
        elif isinstance(n, (_blk.For, _blk.While, _blk.Do)):
            yield n.head
            yield from _iter_stmts(n.body)
        elif isinstance(n, _blk.IfBlock):
            yield n.head
            yield from _iter_stmts(n.body)
            for ei, body in n.elifs:
                yield ei
                yield from _iter_stmts(body)
            if n.else_body is not None:
                yield from _iter_stmts(n.else_body)
        elif isinstance(n, _blk.Select):
            yield n.head
            for case, body in n.cases:
                if case is not None:
                    yield case
                yield from _iter_stmts(body)


def _collect(statements: list[Statement], ctx: Ctx,
             params: set[str] | None = None) -> None:
    params = params or set()
    for s in statements:
        # string vars: any A$ token anywhere — but a `$`-name followed by '('
        # is a string FUNCTION call (UCASE$, LEFT$, CHR$...), not a variable.
        text = (s.first_word or "") + " " + (s.rest or "")
        for m in _STRVAR_RE.finditer(text):
            if text[m.end():m.end() + 1] == "(":
                continue
            if m.group(0).upper() in params:
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
                ctx.array_sizes[name] = sizes
        elif s.first_word == "FOR":
            m = _FOR_RE.match(s.rest)
            if m and m.group(1).upper() not in params:
                ctx.add_scalar(m.group(1))
        elif (s.first_word and s.first_word not in _KEYWORDS
              and not _is_strvar(s.first_word)
              and s.first_word.upper() not in ctx.arrays
              and s.first_word.upper() not in ctx.udfs
              and s.first_word.upper() not in params
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
    if kw == "RETURN":
        e = rest.strip()
        if not e:
            return 'return "";' if ctx.cur_ret == "str" else "return 0;"
        code, typ = to_c(_expr.parse(e), ctx)
        code = _strip_outer(code)
        if ctx.cur_ret_real and typ == "int":
            code = f"RGC_FROMINT({code})"
        elif not ctx.cur_ret_real and ctx.cur_ret != "str" and typ == "real":
            code = f"RGC_TOINT({code})"
        return f"return {code};"
    if kw == "END" and not rest.strip():
        return "return 0;"
    # bare function call as a statement (GOSUB-style, value discarded)
    if kw and kw.upper() in ctx.udfs:
        code, _ = to_c(_expr.parse(stmt.raw), ctx)
        return f"{_strip_outer(code)};"
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
        lhs = kw + "".join(f"[{_idx(s, ctx)}]" for s in subs)
        real = kw.upper() in ctx.real_arrays
        return f"{lhs} = {_xlate_to(m.group(2), real, ctx)};"
    if kw and kw not in _KEYWORDS:
        m = _RHS_RE.match(rest)
        if m:
            real = _var_is_real(kw.upper(), ctx)
            return f"{kw} = {_xlate_to(m.group(1), real, ctx)};"
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
    if ctx.uses_rrnd:
        parts.append(
            "static rgc_real rgc_rnd(void) {\n"
            "    return RGC_RND_FROM16(plat_rand());\n"
            "}\n")
    f = ctx.funcs
    need_left = bool(f & {"LEFT$", "RIGHT$", "MID$"})
    need_pool = (need_left or ctx.uses_rstr
                 or bool(f & {"UCASE$", "LCASE$", "CHR$", "STR$", "CAT"}))
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
    if ctx.uses_rstr:
        parts.append(
            "static char *rgc_realstr(rgc_real x) {\n"
            "    char *d = rgc_pool[rgc_pi = (rgc_pi + 1) & 3];\n"
            "    int i = 0, k, start; long u; rgc_real ip, frac;\n"
            "    if (x < 0) { d[i++] = '-'; x = RGC_NEG(x); }\n"
            "    x = RGC_ADD(x, RGC_LIT(3L, 0.00005f));   /* round to ~4 dp */\n"
            "    ip = RGC_FLOOR(x); u = (long)RGC_TOINT(ip);\n"
            "    { char t[12]; int j = 0;\n"
            "      do { t[j++] = (char)('0' + (int)(u % 10)); u /= 10; } while (u);\n"
            "      while (j) d[i++] = t[--j]; }\n"
            "    frac = RGC_SUB(x, ip);\n"
            "    if (frac > 0) { start = i; d[i++] = '.';\n"
            "        for (k = 0; k < 4; k++) {\n"
            "            frac = frac * 10;   /* exact: fixed * plain int needs no shift */\n"
            "            ip = RGC_FLOOR(frac); d[i++] = (char)('0' + RGC_TOINT(ip));\n"
            "            frac = RGC_SUB(frac, ip); }\n"
            "        while (i > start + 1 && d[i - 1] == '0') i--;\n"
            "        if (i == start + 1) i = start; }\n"
            "    d[i] = 0; return d;\n"
            "}\n")
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
            if _var_is_real(var.upper(), ctx):
                st = _xlate_to(start, True, ctx)
                en = _xlate_to(end, True, ctx)
                stp = _xlate_to(step, True, ctx) if step else _real_lit("1.0")
                line(f"for ({var} = {st}; {var} <= {en}; "
                     f"{var} = RGC_ADD({var}, {stp})) {{")
            else:
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
        elif isinstance(n, _blk.Select):
            _emit_select(n, ctx, out, indent, line)
        else:
            kind = type(n).__name__
            ln = getattr(getattr(n, "head", None) or getattr(n, "stmt", None),
                         "line", "?")
            raise EmitError(f"line {ln}: {kind} not supported yet")


_SELECT_HEAD_RE = re.compile(r"(?i)^\s*case\s+(.*)$")


def _emit_select(n, ctx: Ctx, out: list[str], indent: int, line) -> None:
    """SELECT CASE expr / CASE v[,v] / CASE ELSE -> an if/else-if chain (not a C
    switch: BASIC case values are arbitrary expressions, e.g. named constants)."""
    m = _SELECT_HEAD_RE.match(n.head.rest)
    if not m:
        raise EmitError(f"line {n.head.line}: malformed SELECT CASE: {n.head.rest!r}")
    code, typ = to_c(_expr.parse(m.group(1)), ctx)
    tid = ctx.next_tmp()
    sel = f"_sel{tid}"
    ctype = {"str": "const char *", "real": "rgc_real"}.get(typ, "int")
    line(f"{{ {ctype} {sel} = {_strip_outer(code)};")
    first = True
    for case_stmt, body in n.cases:
        if case_stmt is None:                 # CASE ELSE
            line("else {" if not first else "{")
        else:
            conds = []
            for v in _split_args(case_stmt.rest):
                vc, vt = to_c(_expr.parse(v), ctx)
                if typ == "str" or vt == "str":
                    ctx.uses_seq = True
                    conds.append(f"rgc_seq({sel}, {_strip_outer(vc)})")
                else:
                    rc = _to_real(_strip_outer(vc), vt, ctx) if typ == "real" else _strip_outer(vc)
                    conds.append(f"{sel} == {rc}")
            kw = "if" if first else "else if"
            line(f"{kw} ({' || '.join(conds)}) {{")
        _emit_nodes(body, ctx, out, indent + 1)
        line("}")
        first = False
    line("}")


def _param_real(fn_upper: str, p: str, ctx: Ctx) -> bool:
    return (fn_upper, p.upper()) in ctx.real_params


def _fn_c_params(fn_upper: str, params: list, ctx: Ctx) -> str:
    cp = []
    for p, is_str in params:
        if is_str:
            cp.append(f"const char *{_mangle_str(p)}")
        elif _param_real(fn_upper, p, ctx):
            cp.append(f"rgc_real {p}")
        else:
            cp.append(f"int {p}")
    return ", ".join(cp) if cp else "void"


def _fn_proto_params(fn_upper: str, params: list, ctx: Ctx) -> str:
    cp = []
    for p, is_str in params:
        cp.append("const char *" if is_str
                  else ("rgc_real" if _param_real(fn_upper, p, ctx) else "int"))
    return ", ".join(cp) if cp else "void"


def _emit_function(fn, ctx: Ctx, out: list[str]) -> None:
    name, params = _parse_fn_header(fn.head.rest)
    u = ctx.udfs[name.upper()]
    ret = u["ret"]
    fu = name.upper()
    ret_real = fu in ctx.udf_real
    out.append(f"static {_c_ret_type(ret, ret_real)} {u['cname']}"
               f"({_fn_c_params(fu, params, ctx)}) {{")
    ctx.cur_ret = ret
    ctx.cur_ret_real = ret_real
    ctx.cur_fn = fu
    ctx.cur_params = {p.upper() for p, _ in params}
    start = len(out)
    _emit_nodes(fn.body, ctx, out, 1)
    # fall-through return only if control can reach the end (last line not a return)
    last = out[-1].strip() if len(out) > start else ""
    if not last.startswith("return "):
        out.append('    return "";' if ret == "str" else "    return 0;")
    out.append("}")
    ctx.cur_ret = "int"
    ctx.cur_ret_real = False
    ctx.cur_fn = ""
    ctx.cur_params = set()


_REAL_RT_CACHE = None


def _real_runtime() -> str:
    """Inline the rgc_real.h runtime (float/fixed backend) into the output, so
    the emitted .c is self-contained like the string helpers."""
    global _REAL_RT_CACHE
    if _REAL_RT_CACHE is None:
        import os
        p = os.path.join(os.path.dirname(__file__), "runtime", "rgc_real.h")
        with open(p) as fh:
            _REAL_RT_CACHE = fh.read()
    return _REAL_RT_CACHE + "\n"


def emit(source: str) -> str:
    statements = [s for s in tokenize(source) if s.first_word != "REM"]
    ctx = Ctx()
    program = _blk.parse_blocks(statements)

    # 1. Register all UDFs first so calls resolve regardless of definition order.
    fn_headers = []
    for fn in program.functions:
        nm, params = _parse_fn_header(fn.head.rest)
        ctx.udfs[nm.upper()] = {"name": nm, "cname": _udf_cname(nm),
                                "ret": _udf_ret(nm), "params": params}
        fn_headers.append((fn, nm, params))

    # 2. Collect globals per scope (params excluded from each function body).
    _collect(list(_iter_stmts(program.main)), ctx)
    for fn, nm, params in fn_headers:
        _collect(list(_iter_stmts(fn.body)), ctx,
                 params={p.upper() for p, _ in params})

    # 2b. Infer numeric types (int vs real) to a fixpoint.
    _infer_types(program, ctx)

    # 3. Emit function definitions (populates ctx with any global refs inside).
    fn_defs: list[str] = []
    for fn in program.functions:
        _emit_function(fn, ctx, fn_defs)
        fn_defs.append("")

    # 4. Emit main from the top-level body.
    body: list[str] = []
    _emit_nodes(program.main, ctx, body, 1)

    # 5. Globals at file scope (built last so emit-time refs are captured).
    gdecls = ""
    int_scalars = [s for s in ctx.scalars if s.upper() not in ctx.real_scalars]
    real_scalars = [s for s in ctx.scalars if s.upper() in ctx.real_scalars]
    if int_scalars:
        gdecls += "static int " + ", ".join(int_scalars) + ";\n"
    if real_scalars:
        gdecls += "static rgc_real " + ", ".join(real_scalars) + ";\n"
    for name, sizes in ctx.array_sizes.items():
        ctype = "rgc_real" if name.upper() in ctx.real_arrays else "int"
        gdecls += f"static {ctype} {name}{sizes};\n"
    for sv in ctx.strings:
        gdecls += f"static char {_mangle_str(sv)}[{STRMAX + 1}];\n"

    protos = "".join(
        f"static {_c_ret_type(ctx.udfs[nm.upper()]['ret'], nm.upper() in ctx.udf_real)} "
        f"{ctx.udfs[nm.upper()]['cname']}"
        f"({_fn_proto_params(nm.upper(), params, ctx)});\n"
        for _, nm, params in fn_headers)

    seed = ("    plat_seed_rand(1);   /* fixed non-zero seed -> deterministic RND */\n"
            if ctx.uses_rnd else "")

    # String helpers emitted inline (NOT <string.h>): not every retro
    # toolchain ships a usable <string.h> (cmoc doesn't), so the transpiler
    # carries its own. rgc_seq returns 1 when equal.
    helpers = _emit_helpers(ctx)

    real_rt = _real_runtime() if ctx.uses_real else ""

    # Faithful BASIC END: draw and return to READY/OS, screen left as-is.
    return (
        '#include "platform.h"\n\n'
        + real_rt
        + helpers
        + (gdecls + "\n" if gdecls else "")
        + (protos + "\n" if protos else "")
        + ("\n".join(fn_defs) + "\n" if fn_defs else "")
        + "int main(void) {\n"
        + "    plat_init();\n"
        + seed
        + "\n".join(body) + "\n"
        + ("" if body and body[-1].strip().startswith("return ") else "    return 0;\n")
        + "}\n"
    )


if __name__ == "__main__":
    import sys
    src = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    sys.stdout.write(emit(src))
