"""Apply portability rules to a tokenized rgc-basic source file.

The walker iterates the Statement stream from tokenizer.tokenize, looks
each first_word up in rules.json, and emits a Diagnostic for any
keyword that isn't in the requested tier.

`tier` (the caller's target) determines what passes:

  - tier="portable" — only entries marked "portable" pass. "modern"
    entries error. "conditional" entries warn (work everywhere with
    target-specific gotchas).
  - tier="modern" — almost everything passes. "modern" and "portable"
    silent; "conditional" advisory only.

Keywords with a "param" tier (currently just SCREEN) re-dispatch on
the first arg in `rest` — e.g. SCREEN 4 looks up rules["SCREEN"][
"params"]["4"]. Args parsed leniently: pull the leading integer if
present, else the first space-separated token.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from .tokenizer import Statement


@dataclass
class Diagnostic:
    file: str
    line: int
    col: int
    severity: str   # "error" | "warning"
    code: str       # "E001" / "W001"
    keyword: str
    message: str
    suggestion: str = ""


def load_rules(path: str | Path | None = None) -> dict[str, Any]:
    if path is None:
        path = Path(__file__).parent / "rules.json"
    with open(path, "r", encoding="utf-8") as fp:
        rules = json.load(fp)
    rules.pop("_meta", None)
    return rules


_INT_HEAD_RE = re.compile(r"^\s*(\d+)")


def _resolve_param_tier(rule: dict[str, Any], rest: str) -> tuple[str, str]:
    """For tier='param' rules, look up the parameter-specific tier.

    Returns (tier, note).
    """
    m = _INT_HEAD_RE.match(rest)
    if not m:
        # No parameter — fall back to default tier if provided, else
        # treat as modern so unparseable args are flagged.
        return rule.get("default_tier", "modern"), rule.get("note", "")
    arg = m.group(1)
    params = rule.get("params", {})
    sub = params.get(arg)
    if isinstance(sub, str):
        return sub, rule.get("note", "")
    return rule.get("default_tier", "modern"), rule.get("note", "")


_TOKEN_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\$?")

# Two-word dispatch namespaces — when the first word of a statement is
# one of these, the IMMEDIATE next word is the verb (e.g. SPRITE LOAD,
# IMAGE BLEND, TILE DRAW) and shouldn't be flagged as a standalone
# keyword. Without this skip, "SPRITE LOAD 0, "ship.png"" produces a
# spurious warning because LOAD on its own is conditional-tier.
_TWO_WORD_NAMESPACES = {
    "SPRITE", "IMAGE", "TILE", "TILEMAP", "SHEET",
    "SCROLL", "PALETTE", "SCREEN", "OVERLAY",
    "TIMER", "MAP", "OBJ", "MUSIC",
}


def _check_keyword(kw: str, rule: dict[str, Any], rest: str,
                   stmt: Statement, file: str, tier: str,
                   diags: list[Diagnostic]) -> None:
    """Apply one rule to one keyword occurrence and append a diag if
    the rule's tier conflicts with the caller's tier.
    """
    rule_tier = rule.get("tier")
    note = rule.get("note", "")
    suggest = rule.get("suggest", "")
    if rule_tier == "param":
        rule_tier, note = _resolve_param_tier(rule, rest)

    if tier == "portable":
        if rule_tier == "modern":
            diags.append(Diagnostic(
                file=file, line=stmt.line, col=stmt.col,
                severity="error", code="E001", keyword=kw,
                message=f"{kw} not portable" + (f" — {suggest}" if suggest else ""),
                suggestion=suggest,
            ))
        elif rule_tier == "conditional":
            diags.append(Diagnostic(
                file=file, line=stmt.line, col=stmt.col,
                severity="warning", code="W001", keyword=kw,
                message=f"{kw} portable but target-specific" + (f" — {note}" if note else ""),
                suggestion=suggest,
            ))
    elif tier == "modern":
        if rule_tier == "conditional":
            diags.append(Diagnostic(
                file=file, line=stmt.line, col=stmt.col,
                severity="warning", code="W002", keyword=kw,
                message=f"{kw} target-specific" + (f" — {note}" if note else ""),
                suggestion=suggest,
            ))


def lint(
    statements: Iterable[Statement],
    *,
    file: str,
    tier: str = "portable",
    rules: dict[str, Any] | None = None,
) -> list[Diagnostic]:
    """Walk statements and emit a Diagnostic for every keyword whose
    portability tier conflicts with the caller's tier.

    Both `first_word` and any keyword embedded in `rest` are scanned
    — that catches cases like `R$ = HTTP$(U$)` where the dispatch
    keyword is the variable assignment, not the offending intrinsic.
    Rule lookups are deduplicated per statement so we don't yell
    twice about the same keyword on one line.
    """
    if rules is None:
        rules = load_rules()
    diags: list[Diagnostic] = []

    for stmt in statements:
        seen_in_stmt: set[str] = set()

        # First word — the statement's dispatch keyword, if any.
        if stmt.first_word:
            kw = stmt.first_word
            kw_lookup = kw.rstrip("$")
            rule = rules.get(kw_lookup)
            if rule is not None:
                seen_in_stmt.add(kw_lookup)
                _check_keyword(kw, rule, stmt.rest, stmt, file, tier, diags)

        # Comment lines surface as Statement(first_word="REM"). Don't
        # scan rest for keyword matches — the comment text might
        # mention PLATFORM / HTTP / etc. as English words and we'd
        # spuriously flag them.
        if stmt.first_word == "REM":
            continue

        # Embedded keyword scan — pick up modern intrinsics buried in
        # expressions (HTTP$ on RHS, GETMOUSEX() in conditions, etc.).
        # Skip the immediate next-word after a namespace dispatch so
        # `SPRITE LOAD ...` doesn't trip on LOAD.
        skip_next = stmt.first_word in _TWO_WORD_NAMESPACES
        for m in _TOKEN_RE.finditer(stmt.rest):
            tok = m.group(1).upper()
            if skip_next:
                skip_next = False
                continue
            if tok in seen_in_stmt:
                continue
            rule = rules.get(tok)
            if rule is None:
                continue
            seen_in_stmt.add(tok)
            _check_keyword(tok, rule, stmt.rest[m.end():],
                           stmt, file, tier, diags)

    return diags
