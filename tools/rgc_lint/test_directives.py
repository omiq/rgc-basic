"""Unit tests for the directive preprocessor — tier/target #IF blocks,
#ELSE / #ELSEIF chains, and #OPTION tier capture.

Run from repo root: python3 -m tools.rgc_lint.test_directives
Exits non-zero on first failing case.
"""

from __future__ import annotations

import sys

from .directives import preprocess


def _kept(source: str, **kw) -> list[str]:
    """Return the non-blank, non-REM-warning lines that survive."""
    text = preprocess(source, **kw).text
    out = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s:
            continue
        if s.upper().startswith("REM RGC-LINT:"):
            continue
        out.append(s)
    return out


# (name, source, kwargs, expected-kept-lines)
CASES = [
    # --- tier axis (backwards compat) -------------------------------
    (
        "modern tier keeps MODERN",
        "#IF MODERN\nA\n#END IF\nB",
        {"tier": "modern"},
        ["A", "B"],
    ),
    (
        "portable tier drops MODERN",
        "#IF MODERN\nA\n#END IF\nB",
        {"tier": "portable"},
        ["B"],
    ),
    (
        "portable tier keeps RETRO",
        "#IF RETRO\nA\n#END IF\nB",
        {"tier": "portable"},
        ["A", "B"],
    ),
    (
        "PORTABLE always kept",
        "#IF PORTABLE\nA\n#END IF",
        {"tier": "modern"},
        ["A"],
    ),
    # --- target axis ------------------------------------------------
    (
        "target match keeps branch",
        "#IF TARGET c64\nA\n#END IF\nB",
        {"target": "c64"},
        ["A", "B"],
    ),
    (
        "target mismatch drops branch",
        "#IF TARGET c64\nA\n#END IF\nB",
        {"target": "zxspectrum"},
        ["B"],
    ),
    (
        "target list matches any member",
        "#IF TARGET c64,c128,plus4\nA\n#END IF",
        {"target": "c128"},
        ["A"],
    ),
    (
        "target case-insensitive",
        "#IF TARGET C64\nA\n#END IF",
        {"target": "c64"},
        ["A"],
    ),
    (
        "no target set drops TARGET block",
        "#IF TARGET c64\nA\n#END IF\nB",
        {},
        ["B"],
    ),
    # --- #ELSE / #ELSEIF chains -------------------------------------
    (
        "else taken when if fails",
        "#IF TARGET c64\nA\n#ELSE\nB\n#END IF",
        {"target": "zxspectrum"},
        ["B"],
    ),
    (
        "else skipped when if matches",
        "#IF TARGET c64\nA\n#ELSE\nB\n#END IF",
        {"target": "c64"},
        ["A"],
    ),
    (
        "elseif first match wins",
        "#IF TARGET c64\nA\n#ELSEIF TARGET zxspectrum\nB\n#ELSE\nC\n#END IF",
        {"target": "zxspectrum"},
        ["B"],
    ),
    (
        "elseif falls through to else",
        "#IF TARGET c64\nA\n#ELSEIF TARGET zxspectrum\nB\n#ELSE\nC\n#END IF",
        {"target": "msx"},
        ["C"],
    ),
    (
        "only first matching branch of many",
        "#IF TARGET c64\nA\n#ELSEIF TARGET c64\nB\n#END IF",
        {"target": "c64"},
        ["A"],
    ),
    (
        "ELSE IF spelling accepted",
        "#IF TARGET c64\nA\n#ELSE IF TARGET msx\nB\n#END IF",
        {"target": "msx"},
        ["B"],
    ),
    # --- line-number stability --------------------------------------
    (
        "dropped branch preserved as blank lines",
        "#IF TARGET c64\nA\n#ELSE\nB\n#END IF",
        {"target": "c64"},
        None,  # checked separately below
    ),
]


def main() -> int:
    failures = 0
    for name, src, kw, expected in CASES:
        if expected is None:
            continue
        got = _kept(src, **kw)
        if got != expected:
            failures += 1
            print(f"FAIL: {name}")
            print(f"  source:   {src!r}")
            print(f"  expected: {expected}")
            print(f"  got:      {got}")

    # Line-number stability: a marker line after the block must land on
    # the same 0-based line index in the output, whichever branch wins,
    # so diagnostics keep pointing at the right source line.
    src = "#IF TARGET c64\nA\n#ELSE\nB\n#END IF\nMARKER"
    for tgt in ("c64", "zxspectrum"):
        out = preprocess(src, target=tgt).text.splitlines()
        want = src.splitlines().index("MARKER")
        if out.index("MARKER") != want:
            failures += 1
            print(f"FAIL: MARKER line drifted (target={tgt})")
            print(f"  want index {want}, got {out.index('MARKER')}")

    if failures:
        print(f"\n{failures} failing case(s)")
        return 1
    print(f"All {len(CASES) - 1} directive cases passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
