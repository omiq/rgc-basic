"""Group the flat `Statement` stream into a nested block tree.

The tokenizer emits a flat list of statements (one per `:`-separated chunk).
This module folds the structured-BASIC block keywords
(FUNCTION/END FUNCTION, FOR/NEXT, WHILE/WEND, DO/LOOP, SELECT/CASE/END SELECT,
block IF/ELSEIF/ELSE/END IF) into a tree the C emitter can walk recursively.

It groups *every* block kind so the structure is complete; the emitter decides
which node kinds it can currently lower (others raise at codegen, not here).
Expression/condition contents are left as raw strings on the `Statement` — the
expr AST (`expr.py`) parses those at emit time.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .tokenizer import Statement


# ---- node types -------------------------------------------------------------

@dataclass
class Line:
    """A single non-block statement (assignment, CLS, PRINT, call, RETURN...)."""
    stmt: Statement


@dataclass
class For:
    head: Statement          # FOR i = a TO b [STEP s]
    body: list = field(default_factory=list)


@dataclass
class While:
    head: Statement          # WHILE cond
    body: list = field(default_factory=list)


@dataclass
class Do:
    head: Statement          # DO [WHILE|UNTIL cond]
    tail: Statement | None   # LOOP [WHILE|UNTIL cond]
    body: list = field(default_factory=list)


@dataclass
class IfSingle:
    """Single-line IF cond THEN stmt — lowered exactly as the old walker did."""
    stmt: Statement


@dataclass
class IfBlock:
    head: Statement                       # IF cond THEN  (nothing after THEN)
    body: list = field(default_factory=list)
    elifs: list = field(default_factory=list)   # [(Statement elseif, body), ...]
    else_body: list | None = None


@dataclass
class Select:
    head: Statement                       # SELECT CASE expr  (rest = 'case expr')
    cases: list = field(default_factory=list)   # [(Statement|None case, body), ...]
                                                # None = CASE ELSE


@dataclass
class Function:
    head: Statement                       # FUNCTION name(params)
    body: list = field(default_factory=list)


@dataclass
class Program:
    main: list = field(default_factory=list)
    functions: list = field(default_factory=list)


class BlockError(Exception):
    pass


# ---- keyword helpers --------------------------------------------------------

def _rest_upper(s: Statement) -> str:
    return (s.rest or "").strip().upper()


def is_block_if(s: Statement) -> bool:
    """IF ... THEN with nothing after THEN = block IF. Trailing THEN only."""
    if s.first_word != "IF":
        return False
    r = _rest_upper(s)
    return r.endswith("THEN")


def _end_kind(s: Statement) -> str | None:
    """END / ENDIF etc -> the kind being closed ('FUNCTION'|'SELECT'|'IF')."""
    if s.first_word == "END":
        return _rest_upper(s).split()[0] if s.rest.strip() else ""
    if s.first_word in ("ENDIF", "ENDSELECT", "ENDFUNCTION"):
        return s.first_word[3:]
    return None


# ---- parser -----------------------------------------------------------------

class _Parser:
    def __init__(self, stmts: list[Statement]) -> None:
        self.s = stmts
        self.i = 0

    def peek(self) -> Statement | None:
        return self.s[self.i] if self.i < len(self.s) else None

    def next(self) -> Statement:
        st = self.s[self.i]
        self.i += 1
        return st

    # body terminators: a callable telling parse_body to stop *before* a stmt.
    def parse_program(self) -> Program:
        prog = Program()
        while self.peek():
            st = self.peek()
            if st.first_word == "FUNCTION":
                prog.functions.append(self.parse_function())
            else:
                prog.main.append(self.parse_statement())
        return prog

    def parse_function(self) -> Function:
        head = self.next()
        fn = Function(head=head)
        fn.body = self.parse_body(self._is_end_function)
        end = self.peek()
        if end is None:
            raise BlockError(f"line {head.line}: FUNCTION without END FUNCTION")
        self.next()  # consume END FUNCTION
        return fn

    def parse_statement(self):
        st = self.peek()
        kw = st.first_word
        if kw == "FOR":
            return self.parse_for()
        if kw == "WHILE":
            return self.parse_while()
        if kw == "DO":
            return self.parse_do()
        if kw == "SELECT":
            return self.parse_select()
        if is_block_if(st):
            return self.parse_if()
        if kw == "IF":
            return IfSingle(self.next())
        if kw == "FUNCTION":
            raise BlockError(f"line {st.line}: nested FUNCTION not allowed")
        # stray terminators reaching here = unbalanced source
        if kw in ("NEXT", "WEND", "LOOP", "CASE", "ELSE", "ELSEIF") \
                or _end_kind(st) is not None:
            raise BlockError(f"line {st.line}: unexpected {kw!r}")
        return Line(self.next())

    def parse_body(self, stop) -> list:
        body = []
        while True:
            st = self.peek()
            if st is None or stop(st):
                return body
            body.append(self.parse_statement())

    def parse_for(self) -> For:
        head = self.next()
        node = For(head=head)
        node.body = self.parse_body(lambda s: s.first_word == "NEXT")
        if self.peek() is None:
            raise BlockError(f"line {head.line}: FOR without NEXT")
        self.next()
        return node

    def parse_while(self) -> While:
        head = self.next()
        node = While(head=head)
        node.body = self.parse_body(lambda s: s.first_word == "WEND")
        if self.peek() is None:
            raise BlockError(f"line {head.line}: WHILE without WEND")
        self.next()
        return node

    def parse_do(self) -> Do:
        head = self.next()
        node = Do(head=head, tail=None)
        node.body = self.parse_body(lambda s: s.first_word == "LOOP")
        if self.peek() is None:
            raise BlockError(f"line {head.line}: DO without LOOP")
        node.tail = self.next()
        return node

    def parse_select(self) -> Select:
        head = self.next()             # rest = 'case <expr>'
        node = Select(head=head)
        # skip to first CASE
        cur_case = None
        cur_body: list = []
        started = False
        while True:
            st = self.peek()
            if st is None:
                raise BlockError(f"line {head.line}: SELECT without END SELECT")
            if _end_kind(st) == "SELECT":
                self.next()
                break
            if st.first_word == "CASE":
                if started:
                    node.cases.append((cur_case, cur_body))
                started = True
                cur_case = None if _rest_upper(st) == "ELSE" else st
                self.next()
                cur_body = []
            else:
                if not started:
                    # statements between SELECT and first CASE — ignore blanks/REM
                    self.next()
                    continue
                cur_body.append(self.parse_statement())
        if started:
            node.cases.append((cur_case, cur_body))
        return node

    def parse_if(self) -> IfBlock:
        head = self.next()
        node = IfBlock(head=head)
        node.body = self.parse_body(self._if_stop)
        # ELSEIF* then optional ELSE
        while True:
            st = self.peek()
            if st is None:
                raise BlockError(f"line {head.line}: IF without END IF")
            if st.first_word == "ELSEIF":
                ei = self.next()
                ei_body = self.parse_body(self._if_stop)
                node.elifs.append((ei, ei_body))
            elif st.first_word == "ELSE":
                self.next()
                node.else_body = self.parse_body(self._if_stop)
            elif _end_kind(st) == "IF":
                self.next()
                break
            else:
                raise BlockError(f"line {head.line}: malformed IF block near "
                                 f"line {st.line}")
        return node

    @staticmethod
    def _if_stop(s: Statement) -> bool:
        return (s.first_word in ("ELSE", "ELSEIF")
                or _end_kind(s) == "IF")

    @staticmethod
    def _is_end_function(s: Statement) -> bool:
        return _end_kind(s) == "FUNCTION"


def parse_blocks(stmts: list[Statement]) -> Program:
    return _Parser(stmts).parse_program()
