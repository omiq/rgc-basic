"""RGC-BASIC expression parser -> AST (shared linter + transpiler front end).

This is option B: a real recursive-descent expression parser that replaces
the regex string-munging the emitter used for Tier-1/2. It is context-free
(no knowledge of which names are arrays vs functions, no C) so BOTH the
linter and the C emitter can consume the same tree:

  - the transpiler walks the AST -> C (with a Ctx to resolve arrays/funcs/types);
  - the linter can walk it for structural checks (undeclared, type, arity).

Grammar (low -> high precedence), matching BASIC:

  or   := and  ( OR  and )*
  and  := not  ( AND not )*
  not  := NOT not | rel
  rel  := add ( (= | <> | < | > | <= | >=) add )*
  add  := mul ( (+ | -) mul )*
  mul  := unary ( (* | / | MOD) unary )*
  unary:= - unary | primary
  primary := NUMBER | STRING | NAME ( '(' args ')' )? | '(' or ')'

`NAME(args)` is parsed as a generic Apply node; whether it is an array
index or a function call is resolved by the consumer (it needs context).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field


# ---- AST -------------------------------------------------------------------

@dataclass
class Num:
    value: str

@dataclass
class Str:
    value: str          # includes the surrounding quotes

@dataclass
class Var:
    name: str           # may end in '$' (string var)

@dataclass
class Apply:
    name: str           # array ref OR function call — consumer resolves
    args: list = field(default_factory=list)

@dataclass
class Unary:
    op: str
    operand: object

@dataclass
class Binary:
    op: str             # + - * / MOD = <> < > <= >= AND OR
    left: object
    right: object


class ParseError(Exception):
    pass


# ---- Lexer -----------------------------------------------------------------

_TOKEN_RE = re.compile(r"""
      (?P<ws>\s+)
    | (?P<num>\d+\.\d+|\.\d+|\d+)
    | (?P<str>"[^"]*")
    | (?P<name>[A-Za-z_]\w*\$?)
    | (?P<op><<|>>|<=|>=|<>|[-+*/\\^=<>(),])
""", re.VERBOSE)

_KEYWORD_OPS = {"AND", "OR", "NOT", "MOD"}


def _lex(s: str):
    toks = []
    i = 0
    while i < len(s):
        m = _TOKEN_RE.match(s, i)
        if not m:
            raise ParseError(f"bad token at {s[i:]!r}")
        i = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        val = m.group()
        if kind == "name" and val.upper() in _KEYWORD_OPS:
            toks.append(("kw", val.upper()))
        else:
            toks.append((kind, val))
    toks.append(("eof", ""))
    return toks


# ---- Parser ----------------------------------------------------------------

class _Parser:
    def __init__(self, toks):
        self.toks = toks
        self.p = 0

    def peek(self):
        return self.toks[self.p]

    def next(self):
        t = self.toks[self.p]
        self.p += 1
        return t

    def expect(self, kind, val=None):
        k, v = self.peek()
        if k != kind or (val is not None and v != val):
            raise ParseError(f"expected {val or kind}, got {v!r}")
        return self.next()

    def _is(self, kind, val=None):
        k, v = self.peek()
        return k == kind and (val is None or v == val)

    def _is_kw(self, *names):
        k, v = self.peek()
        return k == "kw" and v in names

    def parse_or(self):
        node = self.parse_and()
        while self._is_kw("OR"):
            self.next()
            node = Binary("OR", node, self.parse_and())
        return node

    def parse_and(self):
        node = self.parse_not()
        while self._is_kw("AND"):
            self.next()
            node = Binary("AND", node, self.parse_not())
        return node

    def parse_not(self):
        if self._is_kw("NOT"):
            self.next()
            return Unary("NOT", self.parse_not())
        return self.parse_rel()

    def parse_rel(self):
        node = self.parse_shift()
        while self._is("op") and self.peek()[1] in ("=", "<>", "<", ">", "<=", ">="):
            op = self.next()[1]
            node = Binary(op, node, self.parse_shift())
        return node

    def parse_shift(self):
        node = self.parse_add()
        while self._is("op") and self.peek()[1] in ("<<", ">>"):
            op = self.next()[1]
            node = Binary(op, node, self.parse_add())
        return node

    def parse_add(self):
        node = self.parse_mul()
        while self._is("op") and self.peek()[1] in ("+", "-"):
            op = self.next()[1]
            node = Binary(op, node, self.parse_mul())
        return node

    def parse_mul(self):
        node = self.parse_unary()
        while (self._is("op") and self.peek()[1] in ("*", "/", "\\")) or self._is_kw("MOD"):
            op = self.next()[1]
            node = Binary(op, node, self.parse_unary())
        return node

    def parse_unary(self):
        if self._is("op", "-"):
            self.next()
            return Unary("-", self.parse_unary())
        return self.parse_power()

    def parse_power(self):
        # '^' binds tighter than unary minus and is right-associative.
        node = self.parse_primary()
        if self._is("op", "^"):
            self.next()
            return Binary("^", node, self.parse_unary())
        return node

    def parse_primary(self):
        k, v = self.peek()
        if k == "num":
            self.next(); return Num(v)
        if k == "str":
            self.next(); return Str(v)
        if k == "op" and v == "(":
            self.next()
            node = self.parse_or()
            self.expect("op", ")")
            return node
        if k == "name":
            self.next()
            if self._is("op", "("):
                self.next()
                args = []
                if not self._is("op", ")"):
                    args.append(self.parse_or())
                    while self._is("op", ","):
                        self.next()
                        args.append(self.parse_or())
                self.expect("op", ")")
                return Apply(v, args)
            return Var(v)
        raise ParseError(f"unexpected {v!r}")


def parse(s: str):
    """Parse a BASIC expression/condition string into an AST."""
    p = _Parser(_lex(s))
    node = p.parse_or()
    if not p._is("eof"):
        raise ParseError(f"trailing input: {p.peek()[1]!r}")
    return node
