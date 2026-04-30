"""rgc-basic tokenizer for the linter and (later) transpiler.

Goal: split a .bas source file into statement-level tokens with line/col
tracking, with comments and string literals stripped so the linter only
sees keywords and arguments.

This isn't a full parser — it's a coarse line-walker that finds keyword
boundaries, splits lines on `:`, and records each statement's first
token (the dispatch keyword) plus the rest of the line as raw text.
That's enough for portability checks; the transpiler will need a deeper
walk later but can grow on top of this.

Line numbering is 1-based to match BASIC editor conventions and
diagnostic output.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterator


@dataclass
class Statement:
    """One statement-level chunk extracted from the source.

    `first_word` is the upper-cased dispatch keyword (e.g. "PRINT",
    "SCREEN", "SPRITE"). `rest` is whatever followed up to the next `:`
    or end-of-line, with leading whitespace trimmed. Comments / string
    literals are preserved verbatim in `rest` because rules may need to
    inspect arguments (e.g. `SCREEN 4`'s `4`).

    `line` and `col` point at the position of `first_word` in the
    original source — used for diagnostics.
    """

    line: int
    col: int
    first_word: str
    rest: str
    raw: str  # whole statement chunk before splitting


_KW_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\$?")


def _strip_comment(line: str) -> str:
    """Remove trailing REM / `'` comment.

    Tracks whether we're inside a "string" literal so a comment marker
    inside quotes is preserved. PETSCII brace tokens (`{RED}`) don't
    confuse the scanner because they only appear inside string
    literals already.
    """
    out_chars = []
    in_string = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_string:
            out_chars.append(c)
            if c == '"':
                in_string = False
            elif c == "\\" and i + 1 < len(line):
                # backslash escape — copy escape too
                out_chars.append(line[i + 1])
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            in_string = True
            out_chars.append(c)
            i += 1
            continue
        if c == "'":
            break
        # REM keyword: word boundary either side
        if c in ("R", "r") and line[i:i + 3].upper() == "REM" and (
            i == 0 or not line[i - 1].isalnum()
        ) and (i + 3 == len(line) or not line[i + 3].isalnum()):
            break
        out_chars.append(c)
        i += 1
    return "".join(out_chars)


def _split_statements(line_no: int, raw_line: str) -> Iterator[Statement]:
    """Split one source line on top-level `:` separators.

    Inside string literals the colon is preserved (BASIC strings can
    contain colons). Multi-statement lines (`A=1 : B=2 : PRINT A+B`)
    each become a separate Statement so the linter can flag the right
    one specifically.
    """
    line = _strip_comment(raw_line)
    if not line.strip():
        return
    chunks: list[tuple[int, str]] = []
    in_string = False
    start = 0
    i = 0
    while i < len(line):
        c = line[i]
        if in_string:
            if c == '"':
                in_string = False
            elif c == "\\" and i + 1 < len(line):
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c == ":":
            chunks.append((start, line[start:i]))
            start = i + 1
        i += 1
    chunks.append((start, line[start:]))

    for col_offset, chunk in chunks:
        text = chunk.lstrip()
        leading_ws = len(chunk) - len(text)
        if not text:
            continue
        m = _KW_RE.match(text)
        if not m:
            # statement starts with a non-identifier (e.g. label `:` only,
            # a `?` shorthand for PRINT, etc.). Yield with first_word
            # blank — caller can decide what to do.
            yield Statement(
                line=line_no,
                col=col_offset + leading_ws + 1,
                first_word="",
                rest=text,
                raw=chunk,
            )
            continue
        kw = m.group(0).upper()
        rest = text[m.end():].lstrip()
        # `?` in BASIC = PRINT shorthand. Normalise so rules.json only
        # needs one entry.
        if kw == "":
            kw = "PRINT"
        yield Statement(
            line=line_no,
            col=col_offset + leading_ws + 1,
            first_word=kw,
            rest=rest,
            raw=chunk,
        )


def tokenize(source: str) -> Iterator[Statement]:
    """Walk a full source string, yielding one Statement per top-level
    statement (split on `:` within a line, plus per-line splitting).
    """
    for idx, raw_line in enumerate(source.splitlines(), start=1):
        # Strip line numbers ("10 PRINT 'X'") if present so the first
        # word of the statement is the actual keyword, not a digit.
        m = re.match(r"\s*(\d+)\s+", raw_line)
        if m:
            raw_line = raw_line[m.end():]
        yield from _split_statements(idx, raw_line)


def tokenize_file(path: str) -> list[Statement]:
    with open(path, "r", encoding="utf-8") as fp:
        return list(tokenize(fp.read()))
