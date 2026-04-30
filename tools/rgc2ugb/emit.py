"""Source-to-source emitter: rgc-basic → ugBASIC.

Given a stream of Statement tokens (from the linter's tokenizer), emit
ugBASIC syntax suitable for `ugbc -T <target>` to compile.

Approach: line-level translation, not full AST. BASIC dialects overlap
~70% by keyword surface; only the differing statements need rewriting.
The rewritten source is one line per emitted statement (no `:` packing
back together) so it's easy to read and diff.

Per-statement rules live in `_HANDLERS` — a dict of `first_word → handler
function` that returns one or more output lines. Anything not in
`_HANDLERS` falls through with the raw text preserved verbatim.

Header epilogue / prologue:
  - `REM @include <target>,<target>...` directive at top so ugBASIC
    knows which targets the program is intended for.
  - Optional `BITMAP ENABLE (16)` if the program uses graphics mode.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..rgc_lint.tokenizer import Statement, tokenize
from ..rgc_lint.directives import preprocess


@dataclass
class TranspileResult:
    text: str            # ugBASIC source
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


_SPRITE_LOAD_RE = re.compile(
    r"^\s*(\d+)\s*,\s*\"([^\"]+)\"(?:\s*,\s*(\d+)\s*,\s*(\d+))?\s*$"
)
_SPRITE_DRAW_RE = re.compile(r"^\s*(\d+)\s*,\s*([^,]+)\s*,\s*([^,]+)(?:\s*,\s*([^,]+))?\s*$")
_SLEEP_RE = re.compile(r"^\s*(.+?)\s*$")
_KEYDOWN_RE = re.compile(r"\bKEYDOWN\s*\(\s*([^)]+)\s*\)")
_INKEY_RE = re.compile(r"\bINKEY\$\s*\(\s*\)")
_BACKGROUND_RE = re.compile(r"\bBACKGROUND\b")
_LINE_TO_RE = re.compile(r"^\s*([^,]+)\s*,\s*([^ ]+)\s+TO\s+([^,]+)\s*,\s*([^ ]+)\s*$", re.IGNORECASE)
_ELSE_IF_RE = re.compile(r"^\s*ELSE\s+IF\b", re.IGNORECASE)


def _emit_pass_through(stmt: Statement) -> list[str]:
    """Default: emit the statement verbatim. Used for keywords that
    work the same way in both dialects (PRINT, LET, FOR, etc.)."""
    if stmt.first_word:
        if stmt.rest:
            return [f"{stmt.first_word} {stmt.rest}"]
        return [stmt.first_word]
    return [stmt.raw.strip()]


def _emit_rem(stmt: Statement) -> list[str]:
    return [f"REM {stmt.rest}" if stmt.rest else "REM"]


def _emit_screen(stmt: Statement) -> list[str]:
    """SCREEN 0 → TILEMAP ENABLE (text); SCREEN 1 → BITMAP ENABLE(16).
    SCREEN 2/3/4 are modern-only — should be caught by linter, but
    emit a hint if we get here."""
    arg = stmt.rest.strip().split()[0] if stmt.rest.strip() else "0"
    if arg == "0":
        return ["TILEMAP ENABLE"]
    if arg == "1":
        return ["BITMAP ENABLE (16)"]
    return [f"REM rgc2ugb: SCREEN {arg} not portable to ugBASIC"]


def _emit_sleep(stmt: Statement) -> list[str]:
    """SLEEP n (ticks at 60Hz) → WAIT (n*16) MS. Approximate — 1 tick
    = 16.67 ms; we round down to integer ms for the ugBASIC token."""
    expr = stmt.rest.strip()
    if not expr:
        return ["WAIT 16 MS"]
    # If the arg is a literal integer we can compute. Otherwise just
    # multiply at runtime: WAIT (expr * 16) MS — ugBASIC accepts an
    # integer expression for the count.
    if expr.isdigit():
        return [f"WAIT {int(expr) * 16} MS"]
    return [f"WAIT ({expr}) * 16 MS"]


def _emit_vsync(stmt: Statement) -> list[str]:
    return ["WAIT VBL"]


def _emit_cls(stmt: Statement) -> list[str]:
    if stmt.rest.strip():
        return [f"REM rgc2ugb: CLS rect-form not portable; clearing whole screen",
                "CLS"]
    return ["CLS"]


def _emit_background(stmt: Statement) -> list[str]:
    """BACKGROUND n → PAPER n (ugBASIC convention)."""
    return [f"PAPER {stmt.rest}".rstrip()]


def _emit_loadsprite(stmt: Statement) -> list[str]:
    """LOADSPRITE slot, "file.png" [, tw, th]
    →  _img_N = LOAD IMAGE("file.png")            (single image)
       _img_N = LOAD ATLAS("file.png") FRAME SIZE (tw, th)  (sheet)
       _spr_N = SPRITE(_img_N)
       SPRITE _spr_N ENABLE
    """
    m = _SPRITE_LOAD_RE.match(stmt.rest)
    if not m:
        return [f"REM rgc2ugb: could not parse SPRITE LOAD args: {stmt.rest}"]
    slot, path, tw, th = m.group(1), m.group(2), m.group(3), m.group(4)
    out = []
    if tw and th:
        out.append(f'_img_{slot} = LOAD ATLAS("{path}") FRAME SIZE ({tw},{th})')
    else:
        out.append(f'_img_{slot} = LOAD IMAGE("{path}")')
    out.append(f"_spr_{slot} = SPRITE(_img_{slot})")
    out.append(f"SPRITE _spr_{slot} ENABLE")
    return out


def _emit_drawsprite(stmt: Statement) -> list[str]:
    """DRAWSPRITE slot, x, y [, z [, sx, sy [, sw, sh]]]
    →  SPRITE _spr_<slot> AT x, y
    Z and source-rect args are dropped (ugBASIC sprites don't expose
    them; warn on use).
    """
    parts = [p.strip() for p in stmt.rest.split(",")]
    if len(parts) < 3:
        return [f"REM rgc2ugb: DRAWSPRITE needs slot, x, y — got: {stmt.rest}"]
    slot, x, y = parts[0], parts[1], parts[2]
    extras = ""
    if len(parts) > 3:
        extras = "  REM rgc2ugb: dropped z/source-rect args (not portable)"
    return [f"SPRITE _spr_{slot} AT {x}, {y}{extras}"]


def _emit_unloadsprite(stmt: Statement) -> list[str]:
    slot = stmt.rest.strip()
    return [f"SPRITE _spr_{slot} DISABLE"]


def _emit_spritevisible(stmt: Statement) -> list[str]:
    parts = [p.strip() for p in stmt.rest.split(",")]
    if len(parts) < 2:
        return [f"REM rgc2ugb: SPRITEVISIBLE needs slot, on/off"]
    slot, on = parts[0], parts[1]
    if on in ("0", "OFF", "FALSE"):
        return [f"SPRITE _spr_{slot} DISABLE"]
    return [f"SPRITE _spr_{slot} ENABLE"]


def _emit_sprite_two_word(stmt: Statement) -> list[str]:
    """SPRITE LOAD/DRAW/FREE/FRAME — strip the leading SPRITE namespace
    word and dispatch as if first_word was the verb. Lets the user
    write the canonical two-word form and still get the right
    translation. STAMP is modern-only — caught by linter."""
    rest = stmt.rest.lstrip()
    parts = rest.split(None, 1)
    if not parts:
        return _emit_pass_through(stmt)
    verb = parts[0].upper()
    body = parts[1] if len(parts) > 1 else ""
    fake = Statement(line=stmt.line, col=stmt.col,
                     first_word=verb, rest=body, raw=stmt.raw)
    if verb == "LOAD":
        return _emit_loadsprite(fake)
    if verb == "DRAW":
        return _emit_drawsprite(fake)
    if verb == "FREE":
        return _emit_unloadsprite(fake)
    if verb == "FRAME":
        # SPRITE FRAME slot, n  → no direct ugBASIC equiv yet; stub
        return [f"REM rgc2ugb: SPRITE FRAME deferred (not yet mapped)"]
    return _emit_pass_through(stmt)


def _replace_intrinsics_in_expression(text: str) -> str:
    """Rewrite intrinsic calls embedded in expressions:
       KEYDOWN(code) → KEY STATE(code)
       INKEY$()      → INKEY$  (ugBASIC takes no parens)
    Other intrinsics with same names (RND, INT, ABS, LEN, ...) pass
    through unchanged."""
    text = _KEYDOWN_RE.sub(lambda m: f"KEY STATE({m.group(1)})", text)
    text = _INKEY_RE.sub("INKEY$", text)
    return text


def _rewrite_expression(stmt: Statement) -> list[str]:
    """Pass-through but rewrite intrinsic calls in the expression body.
    Used for assignments and IF conditions."""
    if stmt.first_word:
        body = _replace_intrinsics_in_expression(stmt.rest)
        if body:
            return [f"{stmt.first_word} {body}"]
        return [stmt.first_word]
    return [_replace_intrinsics_in_expression(stmt.raw.strip())]


def _emit_if(stmt: Statement) -> list[str]:
    """Rewrite KEYDOWN / INKEY$ inside the condition before passing
    through. Block IF maps unchanged (ugBASIC also uses IF cond THEN
    [block] ENDIF). ELSE IF / ELSEIF normalised to ELSEIF (one word)
    which both rgc-basic and ugBASIC accept."""
    body = _replace_intrinsics_in_expression(stmt.rest)
    return [f"IF {body}"]


def _emit_else_if(stmt: Statement) -> list[str]:
    body = _replace_intrinsics_in_expression(stmt.rest)
    return [f"ELSEIF {body}"]


def _emit_end_if(stmt: Statement) -> list[str]:
    return ["ENDIF"]


def _emit_assignment_passthrough(stmt: Statement) -> list[str]:
    """First-word looks like an assignment LHS (a variable, no rule).
    Forward as-is but rewrite intrinsic calls inside the RHS."""
    return _rewrite_expression(stmt)


def _rename(target_keyword: str):
    """Factory for handlers that just swap the first_word for a
    different keyword (e.g. FILLRECT → BAR, FILLCIRCLE → FCIRCLE,
    PSET → PLOT). Body text is preserved verbatim — the rgc-basic
    syntax of `FILLRECT x1,y1 TO x2,y2` matches ugBASIC `BAR x1,y1
    TO x2,y2` so no further rewriting needed."""
    def _h(stmt: Statement) -> list[str]:
        if stmt.rest:
            return [f"{target_keyword} {stmt.rest}"]
        return [target_keyword]
    return _h


def _emit_color(stmt: Statement) -> list[str]:
    """COLOR n → INK n (ugBASIC convention; COLOR exists as a token
    but INK is the canonical pen-set verb on every target)."""
    return [f"INK {stmt.rest}".rstrip()]


_HANDLERS = {
    "REM":            _emit_rem,
    "SCREEN":         _emit_screen,
    "SLEEP":          _emit_sleep,
    "VSYNC":          _emit_vsync,
    "CLS":            _emit_cls,
    "COLOR":          _emit_color,
    "COLOUR":         _emit_color,
    "BACKGROUND":     _emit_background,
    "LOADSPRITE":     _emit_loadsprite,
    "DRAWSPRITE":     _emit_drawsprite,
    "UNLOADSPRITE":   _emit_unloadsprite,
    "SPRITEVISIBLE":  _emit_spritevisible,
    "SPRITE":         _emit_sprite_two_word,
    "IF":             _emit_if,
    "ELSEIF":         _emit_else_if,
    "ENDIF":          _emit_end_if,

    # Bitmap primitives — keyword renames (body text passes through):
    "FILLRECT":       _rename("BAR"),
    "RECT":           _rename("BOX"),
    "FILLCIRCLE":     _rename("FCIRCLE"),
    "FILLELLIPSE":    _rename("FELLIPSE"),
    "PSET":           _rename("PLOT"),
}


def _emit_statement(stmt: Statement) -> list[str]:
    kw = stmt.first_word
    if not kw:
        return [stmt.raw.strip()]

    # Two-word ELSE IF: ELSE first_word, "IF cond THEN" in rest.
    if kw == "ELSE" and _ELSE_IF_RE.match(stmt.first_word + " " + stmt.rest):
        body = stmt.rest[2:].lstrip()  # drop the leading IF
        # Treat as ELSEIF cond THEN
        fake = Statement(line=stmt.line, col=stmt.col,
                         first_word="ELSEIF", rest=body, raw=stmt.raw)
        return _emit_else_if(fake)

    # Block END IF: first_word=END, rest begins with IF.
    if kw == "END" and stmt.rest.upper().startswith("IF"):
        return _emit_end_if(stmt)

    handler = _HANDLERS.get(kw)
    if handler is not None:
        return handler(stmt)

    # No specialised handler — pass through but rewrite intrinsic
    # calls inside the expression body so KEYDOWN / INKEY$ get
    # translated even when the surrounding statement is a plain
    # assignment or PRINT.
    return _rewrite_expression(stmt)


def _detect_targets(source: str) -> str:
    """If the source contains `#OPTION target <name>` or no target hint,
    return a sensible default include list. Conservative: assume the
    program targets every 16-colour bitmap-capable platform unless the
    author specifies."""
    m = re.search(r"#\s*OPTION\s+target\s+(\w+)", source, re.IGNORECASE)
    if m:
        return m.group(1).lower()
    return "c64"


def transpile(source: str, *, target: str = "c64",
              emit_include: bool = True) -> TranspileResult:
    """Transpile rgc-basic source to ugBASIC source.

    `target` selects the ugBASIC target hint emitted as the
    `REM @include <target>` directive at the top of the output. The
    transpiler doesn't currently change the body based on target —
    that's a v2 concern (per-target sprite slot caps, palette quirks,
    etc.).

    `emit_include` toggles the leading directive — disable when
    composing transpiled output into a larger program.
    """
    pre = preprocess(source, tier="portable")
    statements = list(tokenize(pre.text))

    out: list[str] = []
    if emit_include:
        out.append(f"REM @include {target}")
        out.append(f"REM transpiled from rgc-basic by rgc2ugb v0")
        out.append("")
    for stmt in statements:
        out.extend(_emit_statement(stmt))

    return TranspileResult(text="\n".join(out) + "\n")
