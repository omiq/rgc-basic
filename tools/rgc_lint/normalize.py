"""Keyword whitespace normalisation — a faithful Python port of
basic.c's `normalize_keywords_line`.

Classic CBM BASIC listings crunch whitespace, gluing control-flow
keywords to their operands:

    IFB3<1THENIFE>10ORD(7)=0THEN GOTO 890
  ->
    IF B3<1 THEN IF E>10 OR D(7)=0 THEN GOTO 890

The interpreter restores the spaces before parsing (basic.c:1352). The
linter's tokenizer must apply the SAME pass, or it reads `NEXTI` as an
unknown keyword `NEXTI` instead of `NEXT I` and false-flags legitimate
crunched source (e.g. examples/trek.bas).

Only this fixed keyword set is split: IF, FOR, GOTO, GOSUB, NEXT, THEN,
TO, AND, OR, MOD, XOR. PRINT/POKE/etc. are deliberately NOT split — so
`PRINTLN` stays a single token and the unknown-keyword rule still
catches it as the hallucination it is. Keep this port in lock-step with
basic.c; the drift test guards the keyword *set*, not this routine, so
any future change to normalize_keywords_line must be mirrored here.

Transformation is applied only outside quoted strings.
"""

from __future__ import annotations


def _is_ident_char(c: str) -> bool:
    return c.isalnum() or c == "$" or c == "_"


def _at(s: str, i: int) -> str:
    """Char at i, or '' (acts like C's '\\0' sentinel for boundary checks)."""
    return s[i] if 0 <= i < len(s) else ""


def normalize_keywords_line(text: str) -> str:
    """Insert CBM-style whitespace around glued keywords.

    Faithful port of basic.c normalize_keywords_line(). Operates on one
    source line's content (after any leading line number is stripped).
    """
    out: list[str] = []
    in_string = False
    i = 0
    n = len(text)

    def prev_out_needs_space(skip_paren_only: bool = False) -> None:
        # Append a separating space before a keyword if the last emitted
        # char isn't already a separator. `skip_paren_only` mirrors the
        # operator branches (AND/OR/MOD/XOR/TO) which only guard against
        # space and '(' (not ':').
        if out:
            prev = out[-1]
            if skip_paren_only:
                if not prev.isspace() and prev != "(":
                    out.append(" ")
            else:
                if not prev.isspace() and prev != ":" and prev != "(":
                    out.append(" ")

    while i < n:
        c = text[i]

        if c == '"':
            in_string = not in_string
            out.append(c)
            i += 1
            continue

        if not in_string:
            c1 = text[i].upper()
            c2 = _at(text, i + 1).upper()
            c3 = _at(text, i + 2).upper()
            c4 = _at(text, i + 3).upper()

            # IF followed immediately by identifier/digit without space.
            if c1 == "I" and c2 == "F":
                nxt = _at(text, i + 2)
                prev = _at(text, i - 1)
                prev_ident = i > 0 and (prev.isalnum() or prev == "$" or prev == "_")
                if not prev_ident and nxt != "" and not nxt.isspace() and nxt != ":":
                    prev_out_needs_space()
                    out.append("IF")
                    i += 2
                    out.append(" ")
                    continue

            # FOR followed immediately by identifier/digit (but not FOREACH).
            if c1 == "F" and c2 == "O" and c3 == "R":
                nxt = _at(text, i + 3)
                prev = _at(text, i - 1)
                prev_ident = i > 0 and (prev.isalnum() or prev == "$" or prev == "_")
                is_foreach = (
                    _at(text, i + 3).upper() == "E"
                    and _at(text, i + 4).upper() == "A"
                    and _at(text, i + 5).upper() == "C"
                    and _at(text, i + 6).upper() == "H"
                    and not (_at(text, i + 7).isalnum() or _at(text, i + 7) == "_")
                )
                if (not prev_ident and not is_foreach and nxt != ""
                        and not nxt.isspace() and nxt != ":"):
                    prev_out_needs_space()
                    out.append("FOR")
                    i += 3
                    out.append(" ")
                    continue

            # GOTO followed immediately by digit.
            if c1 == "G" and c2 == "O" and c3 == "T" and c4 == "O":
                nxt = _at(text, i + 4)
                if nxt != "" and not nxt.isspace() and nxt != ":":
                    prev_out_needs_space()
                    out.append("GOTO")
                    i += 4
                    out.append(" ")
                    continue

            # GOSUB followed immediately by digit.
            if (c1 == "G" and c2 == "O" and c3 == "S" and c4 == "U"
                    and _at(text, i + 4).upper() == "B"):
                nxt = _at(text, i + 5)
                if nxt != "" and not nxt.isspace() and nxt != ":":
                    prev_out_needs_space()
                    out.append("GOSUB")
                    i += 5
                    out.append(" ")
                    continue

            # NEXT followed immediately by identifier.
            if c1 == "N" and c2 == "E" and c3 == "X" and c4 == "T":
                nxt = _at(text, i + 4)
                prev_out_needs_space()
                out.append("NEXT")
                i += 4
                if nxt != "" and not nxt.isspace() and nxt != ":":
                    out.append(" ")
                continue

            # THEN.
            if c1 == "T" and c2 == "H" and c3 == "E" and c4 == "N":
                prev_out_needs_space()
                out.append("THEN")
                i += 4
                while i < n and text[i].isspace():
                    i += 1
                if i < n and text[i] != "" and text[i] != ":" and not text[i].isspace():
                    out.append(" ")
                continue

            # TO inside numeric ranges: 1TO9 -> 1 TO 9, never split GOTO.
            if c1 == "T" and c2 == "O":
                if i >= 2:
                    g = _at(text, i - 2).upper()
                    o = _at(text, i - 1).upper()
                    if g == "G" and o == "O":
                        pass  # GOTO's TO — fall through
                    else:
                        # previous non-space char
                        prev_ns = " "
                        j = i
                        while j > 0:
                            j -= 1
                            if not text[j].isspace():
                                prev_ns = text[j]
                                break
                        # next non-space char after TO
                        j = i + 2
                        while j < n and text[j].isspace():
                            j += 1
                        next_ns = _at(text, j)
                        if ((prev_ns.isdigit() or prev_ns == ")")
                                and (next_ns.isdigit() or next_ns == "+" or next_ns == "-")):
                            prev_out_needs_space(skip_paren_only=True)
                            out.append("TO")
                            i += 2
                            if (next_ns != "" and not next_ns.isspace()
                                    and next_ns != ":" and next_ns != ")"):
                                out.append(" ")
                            continue

            # AND / OR / MOD / XOR infix operators without spaces.
            if c1 == "A" and c2 == "N" and c3 == "D":
                prev_in = _at(text, i - 1) if i > 0 else " "
                next_in = _at(text, i + 3)
                if not _is_ident_char(prev_in) and not _is_ident_char(next_in):
                    prev_out_needs_space(skip_paren_only=True)
                    out.append("AND")
                    i += 3
                    if i < n and not text[i].isspace() and text[i] != ")":
                        out.append(" ")
                    continue

            if c1 == "O" and c2 == "R":
                prev_in = _at(text, i - 1) if i > 0 else " "
                next_in = _at(text, i + 2) if _at(text, i + 2) != "" else " "
                if not _is_ident_char(prev_in) and not _is_ident_char(next_in):
                    prev_out_needs_space(skip_paren_only=True)
                    out.append("OR")
                    i += 2
                    if i < n and not text[i].isspace() and text[i] != ")":
                        out.append(" ")
                    continue

            if c1 == "M" and c2 == "O" and _at(text, i + 2).upper() == "D":
                prev_in = _at(text, i - 1) if i > 0 else " "
                next_in = _at(text, i + 3) if _at(text, i + 3) != "" else " "
                if not prev_in.isalpha() and not next_in.isalpha():
                    prev_out_needs_space(skip_paren_only=True)
                    out.append("MOD")
                    i += 3
                    if i < n and not text[i].isspace() and text[i] != ")":
                        out.append(" ")
                    continue

            if c1 == "X" and c2 == "O" and _at(text, i + 2).upper() == "R":
                prev_in = _at(text, i - 1) if i > 0 else " "
                next_in = _at(text, i + 3)
                if not _is_ident_char(prev_in) and not _is_ident_char(next_in):
                    prev_out_needs_space(skip_paren_only=True)
                    out.append("XOR")
                    i += 3
                    if i < n and not text[i].isspace() and text[i] != ")":
                        out.append(" ")
                    continue

        out.append(c)
        i += 1

    return "".join(out)
