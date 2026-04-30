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

    # Materialise once — we need two passes: first to detect mixed
    # numbered/unnumbered lines, then the per-statement keyword walk.
    statements = list(statements)

    # Mixed line-numbering check: classic-BASIC source either uses
    # numeric labels on every code line or none. Mixing the two is
    # almost always an authoring mistake (half-converted source). The
    # transpiler errors on this; the linter mirrors it as E002 so the
    # author sees the issue before transpile time.
    numbered = 0
    unnumbered = 0
    first_unnumbered: Statement | None = None
    first_numbered: Statement | None = None
    for s in statements:
        if s.first_word == "REM" or s.first_word == "":
            continue
        if s.line_num is not None:
            numbered += 1
            if first_numbered is None:
                first_numbered = s
        else:
            unnumbered += 1
            if first_unnumbered is None:
                first_unnumbered = s
    if numbered > 0 and unnumbered > 0:
        anchor = first_unnumbered or first_numbered
        diags.append(Diagnostic(
            file=file,
            line=anchor.line if anchor else 1,
            col=anchor.col if anchor else 1,
            severity="error",
            code="E002",
            keyword="",
            message=(
                f"mixed numbered/unnumbered lines "
                f"({numbered} numbered, {unnumbered} unnumbered) — "
                f"pick one style"
            ),
            suggestion=(
                "either prefix every code line with a number "
                "(`10 PRINT \"X\"`) or use labels exclusively "
                "(`mainloop:` + `GOTO mainloop`)"
            ),
        ))

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

        # GOTO / GOSUB with a numeric-literal target in source that has
        # NO numbered lines — the target can't resolve. (When source is
        # numbered, transpiler preserves the referenced label, so this
        # warning would be a false positive.) Author should either add
        # a numeric label to the destination or convert to label form.
        if (tier == "portable" and
                stmt.first_word in ("GOTO", "GOSUB") and
                re.match(r"^\s*\d+\s*$", stmt.rest or "") and
                numbered == 0):
            diags.append(Diagnostic(
                file=file,
                line=stmt.line,
                col=stmt.col,
                severity="warning",
                code="W003",
                keyword=stmt.first_word,
                message=f"{stmt.first_word} {stmt.rest.strip()} — numeric line-number target won't survive transpile",
                suggestion="convert to a label: `mylabel:` + `" + stmt.first_word + " mylabel`",
            ))

        # Trigonometric / log / exp functions — float results differ
        # between rgc-basic (full IEEE float) and ugBASIC (per-target
        # fixed-point or LUT-based math). Smooth motion math (sine
        # waves for object movement) won't produce identical values.
        # Recommend LUT pattern via #INCLUDE "trig_lut.rbas".
        if tier == "portable" and stmt.rest:
            for fn in ("SIN", "COS", "TAN", "ATN", "LOG", "EXP"):
                if re.search(r"\b" + fn + r"\s*\(", stmt.rest):
                    diags.append(Diagnostic(
                        file=file,
                        line=stmt.line,
                        col=stmt.col,
                        severity="warning",
                        code="W006",
                        keyword=fn,
                        message=f"`{fn}(...)` — trig/log/exp output differs between rgc-basic float math and ugBASIC fixed-point; transpiled retro builds may produce different curves",
                        suggestion=f"for portable smooth-motion math use a precomputed LUT (`#INCLUDE \"trig_lut.rbas\"` + ISIN(deg)) — identical output across rgc-basic native + every ugBASIC target",
                    ))
                    break

        # Float-literal division — ugBASIC truncates integer / float
        # to integer unless the LHS is cast. Transpiler auto-injects
        # (FLOAT) but we still warn so the author understands what's
        # happening (sine waves, scaling math, etc).
        if tier == "portable" and stmt.rest:
            for m in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*/\s*(\d+\.\d+)",
                                 stmt.rest):
                diags.append(Diagnostic(
                    file=file,
                    line=stmt.line,
                    col=stmt.col,
                    severity="warning",
                    code="W005",
                    keyword=m.group(1),
                    message=f"`{m.group(1)} / {m.group(2)}` — ugBASIC integer division would truncate; transpiler auto-injects `(FLOAT)` cast",
                    suggestion=f"prefer explicit `(FLOAT) {m.group(1)} / {m.group(2)}` in source for portability across BASIC dialects",
                ))
                break  # one warning per statement is enough

        # POKE into a CBM-style screen RAM region: classic CBM idiom is
        # `POKE 1024+y*40+x, charcode` to write directly to the C64's
        # video matrix. ugBASIC has its own renderer that tracks a
        # tilemap independently of raw screen RAM — these POKEs run
        # but don't appear on screen.
        #
        # Suggest two alternatives:
        #   1. LOCATE x, y : PRINT CHR$(charcode)  ← idiomatic, portable
        #   2. _addr = base + offset : POKE _addr, val  ← mechanical, if
        #      the user really wants raw memory write (e.g. VIC chip
        #      registers, sound, sprite pointers — addresses outside
        #      the screen-RAM range)
        if tier == "portable" and stmt.first_word == "POKE":
            m = re.match(r"^\s*(\d+)\b", stmt.rest or "")
            if m:
                addr = int(m.group(1))
                # CBM screen-RAM bases:
                #   C64       1024..2023  ($0400..$07E7)  also colour 55296..56295
                #   VIC-20    7680..8191  ($1E00..$1FFF)
                #   Plus/4    3072..4071  ($0C00..$0FE7)
                #   PET      32768..33767 ($8000..$83E7)
                in_screen_ram = (
                    1024 <= addr <= 2023 or
                    7680 <= addr <= 8191 or
                    3072 <= addr <= 4071 or
                    32768 <= addr <= 33767
                )
                in_color_ram = 55296 <= addr <= 56295  # C64 colour RAM
                if in_screen_ram or in_color_ram:
                    region = "colour RAM" if in_color_ram else "screen RAM"
                    diags.append(Diagnostic(
                        file=file,
                        line=stmt.line,
                        col=stmt.col,
                        severity="warning",
                        code="W004",
                        keyword="POKE",
                        message=f"POKE into CBM {region} (${addr:04X}) — ugBASIC's renderer ignores raw {region} writes",
                        suggestion=(
                            "use LOCATE col, row : PRINT CHR$(charcode) "
                            "for portable text output, or stash address "
                            "in a typed variable: `addr = base + offset "
                            ": POKE addr, val` if you really need a "
                            "non-display memory write"
                        ),
                    ))

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
