"""Unit tests for normalize_keywords_line — the Python port of basic.c's
crunched-keyword whitespace restorer. Keep these in sync with basic.c.

Run from repo root: python3 -m tools.rgc_lint.test_normalize
Exits non-zero on first failing case.
"""

from __future__ import annotations

import sys

from .normalize import normalize_keywords_line as N

# (input, expected) pairs. Expected values mirror what basic.c produces.
CASES = [
    # control-flow splits
    ("IFA<1THENB=2", "IF A<1 THEN B=2"),
    ("FORI=1TO9", "FOR I=1 TO 9"),
    ("NEXTI", "NEXT I"),
    ("GOTO410", "GOTO 410"),
    ("GOSUB800", "GOSUB 800"),
    # AND/OR/XOR split ONLY when BOTH neighbours are non-identifier chars.
    # A digit counts as an identifier char, so digit-glued operators are
    # left alone — `4AND` stays `4AND` (matches basic.c; such crunch simply
    # doesn't parse, by design).
    ("IFR1>4ANDR1<10THENX=1", "IF R1>4ANDR1<10 THEN X=1"),
    ("IFA>8ORB=1THENGOTO90", "IF A>8ORB=1 THEN GOTO 90"),
    ("A=6XOR3", "A=6XOR3"),          # digit-glued XOR: not split
    # ...but they DO split between non-identifier chars:
    ("(X)AND(Y)", "(X) AND (Y)"),
    # must NOT split: keyword embedded in a longer identifier
    ("FOREACH V IN A", "FOREACH V IN A"),
    ("PLATFORM$", "PLATFORM$"),
    ("WORD=3", "WORD=3"),            # OR inside WORD must stay
    ("D(7)=0", "D(7)=0"),
    # FOR splits unconditionally when followed by a non-space char — so
    # `FORMAT` becomes `FOR MAT`. A documented CBM quirk: you can't name a
    # variable FORMAT in crunched source. The interpreter does the same.
    ("FORMAT=1", "FOR MAT=1"),
    # PRINT is deliberately NOT normalised — PRINTLN stays one token so the
    # unknown-keyword rule can still flag it.
    ("PRINTLN X", "PRINTLN X"),
    ("PRINTI", "PRINTI"),
    # strings are left untouched
    ('PRINT "IFA NEXTI FORI"', 'PRINT "IFA NEXTI FORI"'),
    # GOTO's internal TO must not be re-split
    ("GOTO 100", "GOTO 100"),
    # MOD guards on isalpha (NOT is_ident_char) — so unlike AND/OR/XOR it
    # DOES split between digits: 5MOD2 -> 5 MOD 2.
    ("A=5MOD2", "A=5 MOD 2"),
    ("AMOD2", "AMOD2"),              # alpha-prev: not split (MOD inside ident)
]


def main() -> int:
    failed = 0
    for src, want in CASES:
        got = N(src)
        if got != want:
            failed += 1
            print(f"  FAIL: {src!r}\n    want {want!r}\n    got  {got!r}")
    if failed:
        print(f"==> normalize: {failed}/{len(CASES)} case(s) failed")
        return 1
    print(f"==> normalize: all {len(CASES)} cases passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
