"""Extract the canonical keyword/built-in set from basic.c.

basic.c is the single source of truth for what exists in the language.
Everything downstream (rules.json tiers, the language.md docs, the
unknown-keyword lint rule) must agree with it or it has drifted.

Four sources in basic.c are parsed and unioned:

  reserved_words[]      — identifiers that can't be variables: statement
                          verbs, named constants, some functions.
  eval_factor allow-list — the `starts_with_kw("NAME")` chain in
                          eval_factor: every function name the parser
                          accepts in an expression (the authoritative
                          function list — includes names NOT in
                          reserved_words, e.g. GETMOUSEX).
  kconst[]              — named numeric constants (colours, TRUE/FALSE, PI).
  statement dispatch    — the top-level executor's
                          `c == 'X' && starts_with_kw(*p, "NAME")` chain.
                          Catches statements dispatched WITHOUT being in
                          reserved_words[] (e.g. JSONUNPACK). The `c ==`
                          char-guard distinguishes top-level statement
                          verbs from bare sub-verb checks (TO / INTO /
                          ZONE) inside individual handlers.

Each name is classified:
  constant  — in kconst[]
  function  — in the eval_factor allow-list (and not a constant)
  keyword   — everything else (statement verbs)

NOTE on build variants: every name here is parseable in EVERY build
(native / gfx / canvas WASM). Variant gating is runtime-only (handlers
emit "requires basic-gfx" errors), not encoded in these tables, so this
extractor is deliberately variant-agnostic. Variant tagging is a later
enrichment (see docs / CLAUDE.md plan B).

Usage:
    python3 -m tools.rgc_lint.extract_keywords           # one name per line
    python3 -m tools.rgc_lint.extract_keywords --json    # {name: kind}
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# tools/rgc_lint/ -> repo root is two parents up.
_REPO_ROOT = Path(__file__).resolve().parents[2]
_BASIC_C = _REPO_ROOT / "basic.c"

_RESERVED_BLOCK_RE = re.compile(
    r"static\s+const\s+char\s*\*\s*const\s+reserved_words\s*\[\s*\]\s*=\s*\{(.*?)\}\s*;",
    re.DOTALL,
)
_KCONST_BLOCK_RE = re.compile(
    r"kconst\s*\[\s*\]\s*=\s*\{(.*?)\{\s*NULL",
    re.DOTALL,
)
# The eval_factor function-call allow-list: from the "Function call?"
# marker comment to the namebuf read that ends the chain.
_FUNC_BLOCK_RE = re.compile(
    r"/\*\s*Function call\?\s*\*/(.*?)char\s+namebuf",
    re.DOTALL,
)
_STRING_LIT_RE = re.compile(r'"([^"]*)"')
_STARTS_WITH_KW_RE = re.compile(r'starts_with_kw\(\s*\*?p\s*,\s*"([A-Z][A-Z0-9]*)\$?"')
# Top-level statement dispatch: the char-guarded form distinguishes a
# real statement verb from a bare sub-verb check inside a handler.
_STMT_DISPATCH_RE = re.compile(
    r"c\s*==\s*'[A-Z]'\s*&&\s*starts_with_kw\(\s*\*?p\s*,\s*\"([A-Z][A-Z0-9]*)\""
)
_TWO_WORDS_RE = re.compile(
    r'starts_with_two_words\(\s*\*?p\s*,\s*"([A-Z0-9]+)"\s*,\s*"([A-Z0-9]+)"'
)


def _read_basic_c(path: Path | None = None) -> str:
    if path is None:
        path = _BASIC_C
    return path.read_text(encoding="utf-8", errors="replace")


def _block(regex: re.Pattern[str], src: str, what: str) -> str:
    m = regex.search(src)
    if not m:
        raise RuntimeError(
            f"could not locate {what} in basic.c — the source layout "
            f"may have changed; update the regex in extract_keywords.py"
        )
    return m.group(1)


def extract_reserved_words(src: str | None = None) -> set[str]:
    """Names in the reserved_words[] array."""
    src = _read_basic_c() if src is None else src
    return {s.upper() for s in _STRING_LIT_RE.findall(_block(_RESERVED_BLOCK_RE, src, "reserved_words[]"))}


def extract_constants(src: str | None = None) -> set[str]:
    """Names in the kconst[] table."""
    src = _read_basic_c() if src is None else src
    return {s.upper() for s in _STRING_LIT_RE.findall(_block(_KCONST_BLOCK_RE, src, "kconst[] table"))}


def extract_functions(src: str | None = None) -> set[str]:
    """Function names the parser accepts in expressions (eval_factor).

    Single-word forms via starts_with_kw("NAME"); two-word forms via
    starts_with_two_words("A","B") are glued as "AB" to match the
    function_lookup dispatch spelling (e.g. SHEET COLS -> SHEETCOLS).
    """
    src = _read_basic_c() if src is None else src
    block = _block(_FUNC_BLOCK_RE, src, "eval_factor function allow-list")
    names = {m.upper() for m in _STARTS_WITH_KW_RE.findall(block)}
    names |= {(a + b).upper() for a, b in _TWO_WORDS_RE.findall(block)}
    return names


def extract_statement_dispatch(src: str | None = None) -> set[str]:
    """Top-level statement verbs from the executor dispatch chain.

    Picks up statements that aren't reserved words (e.g. JSONUNPACK).
    """
    src = _read_basic_c() if src is None else src
    return {m.upper() for m in _STMT_DISPATCH_RE.findall(src)}


def keyword_kinds(src: str | None = None) -> dict[str, str]:
    """Union of all four sources, each name classified.

    constant  — kconst[]
    function  — eval_factor allow-list (and not a constant)
    keyword   — reserved_words[] / statement-dispatch verb (everything else)
    """
    src = _read_basic_c() if src is None else src
    reserved = extract_reserved_words(src)
    constants = extract_constants(src)
    functions = extract_functions(src)
    statements = extract_statement_dispatch(src)

    kinds: dict[str, str] = {}
    for name in reserved | constants | functions | statements:
        if name in constants:
            kinds[name] = "constant"
        elif name in functions:
            kinds[name] = "function"
        else:
            kinds[name] = "keyword"
    return kinds


def canonical_set(src: str | None = None) -> set[str]:
    """The full union of every name the language defines."""
    return set(keyword_kinds(src).keys())


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if "--json" in argv:
        print(json.dumps(keyword_kinds(), indent=2, sort_keys=True))
    else:
        for kw in sorted(canonical_set()):
            print(kw)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
