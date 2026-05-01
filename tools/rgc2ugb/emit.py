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


# ugBASIC's lex is case-sensitive: keywords match uppercase only, and
# the identifier rule is `[a-z_][A-Za-z0-9_]*` — must start with
# lowercase. ALL-CAPS source (rgc-basic / classic BASIC convention)
# collides catastrophically: `INIT` reads as `IN` keyword + stray
# `I`+`T`. Fix: lowercase any token not in this set during emit.
_KEEP_UPPERCASE = frozenset({
    "PRINT", "INPUT", "LET", "REM", "IF", "THEN", "ELSE", "ELSEIF",
    "ENDIF", "END", "FOR", "NEXT", "STEP", "TO", "WHILE", "WEND",
    "DO", "LOOP", "UNTIL", "EXIT", "GOTO", "GOSUB", "RETURN", "ON",
    "STOP", "DIM", "AS", "READ", "DATA", "RESTORE", "CLR", "CLS",
    "AND", "OR", "NOT", "XOR", "MOD",
    "RND", "INT", "ABS", "SGN", "SIN", "COS", "TAN", "SQR", "EXP",
    "LOG", "CHR", "STR", "VAL", "LEN", "LEFT", "RIGHT", "MID",
    "INSTR", "UCASE", "LCASE", "STRING", "TRIM", "LTRIM", "RTRIM",
    "ASC", "TAB", "SPC", "HEX", "DEC", "TI", "INKEY",
    "SCREEN", "BITMAP", "TILEMAP", "ENABLE", "DISABLE",
    "EMPTY", "TILE", "EMPTYTILE",
    "PARALLEL", "SPAWN", "CALL",
    "COLOR", "COLOUR", "INK", "PAPER", "BORDER", "BACKGROUND",
    "LOCATE", "SLEEP", "WAIT", "VBL", "MS", "CYCLES",
    "BAR", "BOX", "CIRCLE", "FCIRCLE", "ELLIPSE", "FELLIPSE",
    "PLOT", "LINE", "DRAW", "DRAWTEXT", "PSET", "PRESET",
    "FILLRECT", "FILLCIRCLE", "FILLELLIPSE", "RECT",
    "POKE", "PEEK", "MEMSET", "MEMCPY",
    "SPRITE", "SPRITES", "AT", "KEY", "STATE", "JOY", "JOYSTICK",
    "FIRE", "KEYDOWN", "KEYUP", "KEYPRESS",
    "IMAGE", "ATLAS", "FRAME", "SIZE", "LOAD", "SAVE",
    "WIDTH", "HEIGHT",
    "PROCEDURE", "PROC", "CONST", "DEF", "DEFINE", "FN", "FUNCTION",
    "SHARED", "GLOBAL", "BYTE", "WORD", "DWORD", "POSITION",
    "FLOAT", "DOUBLE", "ADDRESS", "SIGNED", "UNSIGNED",
    "SCREEN_WIDTH", "SCREEN_HEIGHT", "OPTION", "INCLUDE",
    "PETSCII", "LOWER", "UPPER",
    "BLACK", "WHITE", "RED", "CYAN", "PURPLE", "GREEN", "BLUE",
    "YELLOW", "ORANGE", "BROWN", "PINK",
    "TRUE", "FALSE", "PI",
    # ugBASIC v1.18 additions
    "MAX", "MIN", "FLASH", "TRIANGLE", "BITMAPADDRESS",
    "RESET", "ERROR", "CHAIN",
    "BEGIN", "COPPER", "MOVE", "STORE",
    "NUMBER", "MSPRITE",
    "ARRAY", "CHECK", "GET", "PUT", "REU",
})


def _lowercase_identifiers(line: str) -> str:
    """Lowercase tokens not in _KEEP_UPPERCASE. String literals pass
    through verbatim. Used to make rgc-basic ALL-CAPS identifiers
    (variables, labels) compatible with ugBASIC's case-sensitive
    `[a-z_]...` identifier rule."""
    out = []
    in_string = False
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if in_string:
            out.append(c)
            if c == '"':
                in_string = False
            elif c == "\\" and i + 1 < n:
                out.append(line[i + 1])
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            if j < n and line[j] == "$":
                j += 1
            tok = line[i:j]
            strip_dollar = tok.rstrip("$")
            if strip_dollar.upper() in _KEEP_UPPERCASE:
                out.append(strip_dollar.upper() + ("$" if tok.endswith("$") else ""))
            else:
                out.append(tok.lower())
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


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

# Detect integer / float-literal division and inject (FLOAT) cast.
# Without the cast ugBASIC's integer-first arithmetic truncates the
# division before the float multiplication. Pattern: identifier / N.M.
_FLOAT_DIV_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*/\s*(\d+\.\d+)")


def _inject_float_cast(text: str) -> str:
    return _FLOAT_DIV_RE.sub(lambda m: f"(FLOAT) {m.group(1)} / {m.group(2)}", text)
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


# PETSCII brace-token table — mirrors basic.c's `token_map[]`. Used
# to expand `{NAME}` and `{number}` braces in string literals into
# CHR$(N) splices so ugBASIC sees concrete control / colour bytes.
_PETSCII_TOKENS = {
    "WHITE": 5, "RED": 28, "CYAN": 159, "PURPLE": 156,
    "GREEN": 30, "BLUE": 31, "YELLOW": 158, "ORANGE": 129,
    "BROWN": 149, "PINK": 150, "BLACK": 144,
    "WHT": 5, "BLK": 144, "CYN": 159, "PUR": 156,
    "GRN": 30, "BLU": 31, "YEL": 158,
    "GRAY1": 151, "GREY1": 151, "DARKGREY": 151, "DARKGRAY": 151,
    "GRAY2": 152, "GREY2": 152, "GREY": 152, "GRAY": 152,
    "GRAY3": 155, "GREY3": 155, "LIGHTGREY": 155, "LIGHTGRAY": 155,
    "LIGHTGREEN": 153, "LIGHT GREEN": 153,
    "LIGHTBLUE": 154, "LIGHT BLUE": 154,
    "LIGHT-RED": 150,
    "HOME": 19, "DOWN": 17, "UP": 145, "LEFT": 157, "RIGHT": 29,
    "DEL": 20, "DELETE": 20, "INS": 148, "INST": 148, "INSERT": 148,
    "CLR": 147, "CLEAR": 147, "SPACE": 32, "RETURN": 13,
    "SHIFT RETURN": 141,
    "CURSOR UP": 145, "CURSOR DOWN": 17,
    "CURSOR LEFT": 157, "CURSOR RIGHT": 29,
    "CRSR UP": 145, "CRSR DOWN": 17,
    "CRSR LEFT": 157, "CRSR RIGHT": 29,
    "RVS": 18, "RVS ON": 18, "RVSON": 18, "REVERSE ON": 18,
    "RVS OFF": 146, "RVSOFF": 146, "REVERSE OFF": 146,
    "F1": 133, "F2": 137, "F3": 134, "F4": 138,
    "F5": 135, "F6": 139, "F7": 136, "F8": 140,
    "PI": 126,
}


def _parse_brace_token(body):
    """Resolve a `{...}` body to a control byte, or None on miss.

    Numeric forms: {147}, {$93}, {0x93}, {%10010011}.
    """
    t = body.strip().upper()
    if t in _PETSCII_TOKENS:
        return _PETSCII_TOKENS[t]
    if t.isdigit():
        n = int(t)
        return n if 0 <= n <= 255 else None
    if re.match(r"^\$[0-9A-F]+$", t):
        n = int(t[1:], 16)
        return n if 0 <= n <= 255 else None
    if re.match(r"^0X[0-9A-F]+$", t):
        n = int(t[2:], 16)
        return n if 0 <= n <= 255 else None
    if re.match(r"^%[01]+$", t):
        n = int(t[1:], 2)
        return n if 0 <= n <= 255 else None
    return None


def _expand_braces_in_line(line):
    """Walk `line` and expand `{NAME}` / `{number}` brace tokens
    inside string literals to `+ CHR$(N) +` concats. Tokens that
    don't resolve are passed through verbatim so the user sees the
    literal `{...}` in the output rather than silent loss."""
    out = []
    i = 0
    n = len(line)
    in_string = False
    while i < n:
        c = line[i]
        if not in_string:
            if c == '"':
                in_string = True
            out.append(c)
            i += 1
            continue
        if c == '"':
            in_string = False
            out.append(c)
            i += 1
            continue
        if c == "{":
            close = line.find("}", i + 1)
            if close < 0:
                out.append(c)
                i += 1
                continue
            body = line[i + 1:close]
            val = _parse_brace_token(body)
            if val is None:
                out.append(line[i:close + 1])
                i = close + 1
                continue
            out.append(f'" + CHR$({val}) + "')
            i = close + 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(c)
            out.append(line[i + 1])
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


_temp_counter = 0


def _next_temp(prefix: str) -> str:
    """Per-transpile counter for synthesised temp variables (POKE
    address stash, future MID$/LEFT$ scalar extracts, etc.). Reset
    at the top of each transpile() call so output is deterministic."""
    global _temp_counter
    _temp_counter += 1
    return f"_{prefix}_{_temp_counter}"


def _split_top_level_args(text: str) -> list[str]:
    """Split text at top-level commas (respect parens and strings)."""
    parts = []
    depth = 0
    in_string = False
    start = 0
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if in_string:
            if c == '"':
                in_string = False
            elif c == "\\" and i + 1 < n:
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            in_string = True
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append(text[start:i])
            start = i + 1
        i += 1
    parts.append(text[start:])
    return [p.strip() for p in parts]


_SIMPLE_ADDR_RE = re.compile(r"^\s*[A-Za-z_][A-Za-z0-9_]*(\$|\([^)]*\))?\s*$")


def _emit_poke(stmt: Statement) -> list[str]:
    """POKE auto-fix: ugBASIC's POKE expects a typed address as its
    first argument. Literal-led arithmetic (e.g. `POKE 1024+y*40+x, v`)
    triggers `unexpected Integer` because the parser can't infer the
    address type from a leading int literal. Stash complex address
    expressions in a synthesised temp variable so ugBASIC's type
    inference sees a normal var read."""
    args = _split_top_level_args(stmt.rest)
    if len(args) != 2:
        return [f"POKE {stmt.rest}"]
    addr, val = args
    if _SIMPLE_ADDR_RE.match(addr):
        return [f"POKE {addr}, {val}"]
    tmp = _next_temp("poke_addr")
    return [
        f"{tmp} = {addr}",
        f"POKE {tmp}, {val}",
    ]


def _emit_textat(stmt: Statement) -> list[str]:
    """TEXTAT col, row, expr$  →  LOCATE col, row : PRINT expr$;

    Trailing `;` suppresses the newline so absolute-position HUD-
    style output doesn't scroll. ugBASIC has no TEXTAT primitive —
    splitting into LOCATE+PRINT preserves the rgc-basic intent."""
    args = _split_top_level_args(stmt.rest)
    if len(args) < 3:
        return [f"REM rgc2ugb: TEXTAT needs col, row, expr — got: {stmt.rest}"]
    col = args[0]
    row = args[1]
    expr = ",".join(args[2:])
    return [
        f"LOCATE {col}, {row}",
        f"PRINT {expr};",
    ]


def _emit_option(stmt: Statement) -> list[str]:
    """Bare `OPTION ...` is rgc-basic interpreter syntax for the
    same thing as the `#OPTION ...` preprocessor directive. The
    preprocess step only strips the hash form; this handler swallows
    the bare form into a `REM` so ugBASIC sees a comment, not a
    stray identifier. CHARSET / PALETTE / COLUMNS / etc. all decay
    this way — they're rgc-basic-only and have no ugBASIC analogue."""
    return [f"REM rgc2ugb: OPTION {stmt.rest} (rgc-basic-only, ignored on retro)"]


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


_empty_tile_emitted = False


def _emit_cls(stmt: Statement) -> list[str]:
    """ugBASIC TILEMAP-mode CLS fills with EMPTY TILE (default
    glyph, often non-blank). Inject `EMPTY TILE = 32` (space) once
    before the first CLS so the screen actually clears to blanks
    the way rgc-basic / CBM-BASIC programmers expect."""
    global _empty_tile_emitted
    out = []
    if not _empty_tile_emitted:
        out.append("EMPTY TILE = 32")
        _empty_tile_emitted = True
    if stmt.rest.strip():
        out.append("REM rgc2ugb: CLS rect-form not portable; clearing whole screen")
    out.append("CLS")
    return out


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
    """Rewrite intrinsic calls + auto-fix integer/float-literal
    division so ugBASIC doesn't truncate to integer.

    Rewrites:
      KEYDOWN(code) → KEY STATE(code)
      INKEY$()      → INKEY$  (ugBASIC takes no parens)
      X / 3.14      → (FLOAT) X / 3.14  (force float division)

    Other intrinsics with the same names (RND, INT, ABS, LEN, …)
    pass through unchanged."""
    text = _inject_float_cast(text)
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


# Match the FUNCTION header: `FUNCTION name(p1, p2)` or `FUNCTION name()`
# or `FUNCTION name`. Captures name + optional comma-separated param list.
_FUNCTION_HEADER_RE = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\s*(.*?)\s*\)\s*)?$",
    re.IGNORECASE,
)


def _emit_function(stmt: Statement) -> list[str]:
    """`FUNCTION name(p1, p2)` → `PROCEDURE name[p1, p2]`.
    `FUNCTION name()` → `PROCEDURE name` (drop empty params per ugBASIC
    convention; calls still use `name[]`)."""
    m = _FUNCTION_HEADER_RE.match(stmt.rest or "")
    if not m:
        # Couldn't parse — leave a marker REM so the author sees it.
        return [f"REM rgc2ugb: malformed FUNCTION header: {stmt.rest}"]
    name, params = m.group(1), (m.group(2) or "").strip()
    if params:
        return [f"PROCEDURE {name}[{params}]"]
    return [f"PROCEDURE {name}"]


def _emit_end_function(stmt: Statement) -> list[str]:
    return ["END PROC"]


# TIMER statement forms (rgc-basic native):
#   TIMER N, MS, CALLBACK   -- register periodic callback
#   TIMER STOP N            -- pause (callback no longer fires)
#   TIMER CLEAR N           -- destroy
#
# ugBASIC has no TIMER. We map registrations to PARALLEL PROCEDURE
# blocks (hoisted to the prologue) plus a `_timer_N_active` flag the
# proc body checks at each iteration. STOP and CLEAR both flip the
# flag false, causing the parallel proc to exit at its next yield.
# CLEAR is functionally equivalent to STOP in ugBASIC because the
# scheduler reaps the proc on EXIT.
_TIMER_REG_RE = re.compile(
    r"^\s*(\d+)\s*,\s*(\d+)\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*$"
)
_TIMER_CTRL_RE = re.compile(
    r"^\s*(STOP|CLEAR)\s+(\d+)\s*$",
    re.IGNORECASE,
)


def _emit_timer(stmt: Statement) -> list[str]:
    """Emit the call-site lines for a TIMER statement.

    The PARALLEL PROCEDURE definition itself is hoisted into the
    prologue by transpile() — see _collect_timers / _emit_timer_procs.
    Here we only emit the activation (`_timer_N_active = TRUE` +
    `SPAWN _timer_N`) or the deactivation flag flip for STOP/CLEAR.
    """
    rest = stmt.rest or ""
    # Control form first (TIMER STOP N / TIMER CLEAR N).
    cm = _TIMER_CTRL_RE.match(rest)
    if cm:
        _verb, tid = cm.group(1), cm.group(2)
        return [f"_timer_{tid}_active = FALSE"]
    # Registration form (TIMER N, MS, CALLBACK).
    rm = _TIMER_REG_RE.match(rest)
    if rm:
        tid = rm.group(1)
        return [
            f"_timer_{tid}_active = TRUE",
            f"SPAWN _timer_{tid}",
        ]
    # Unrecognised — leave a marker so author sees the issue.
    return [f"REM rgc2ugb: malformed TIMER: {rest}"]


def _collect_timers(statements):
    """Walk source for TIMER N, MS, CB registrations. Returns a list
    of (timer_id, interval_ms, callback_name) in source order. Used
    to hoist PARALLEL PROCEDURE definitions into the program prologue.

    Multiple registrations of the same id with different params:
    first wins, later occurrences silently ignored at hoist time
    (the per-statement emit still flips the flag and SPAWNs, which
    is harmless if the proc already exists)."""
    seen: dict[str, tuple[str, str, str]] = {}
    order: list[tuple[str, str, str]] = []
    for s in statements:
        if s.first_word != "TIMER":
            continue
        m = _TIMER_REG_RE.match(s.rest or "")
        if not m:
            continue
        tid, ms, cb = m.group(1), m.group(2), m.group(3)
        if tid in seen:
            continue
        seen[tid] = (tid, ms, cb)
        order.append((tid, ms, cb))
    return order


def _emit_timer_procs(timers) -> list[str]:
    """For each registered timer id, emit a PARALLEL PROCEDURE that
    waits the configured interval and calls the user FUNCTION (now a
    PROCEDURE post-rewrite). The body checks `_timer_N_active` at the
    top + after the WAIT so STOP/CLEAR takes effect promptly without
    racing the in-flight callback."""
    if not timers:
        return []
    out: list[str] = []
    for tid, ms, cb in timers:
        # Lowercase callback name here — hoisted lines bypass the
        # post-emit pipeline that normally case-folds identifiers.
        cb_lc = cb.lower()
        out.append(f"_timer_{tid}_active = FALSE")
        out.append(f"PARALLEL PROCEDURE _timer_{tid}")
        out.append(f"  DO")
        out.append(f"    IF _timer_{tid}_active = FALSE THEN EXIT")
        out.append(f"    WAIT {ms} MS")
        out.append(f"    IF _timer_{tid}_active = FALSE THEN EXIT")
        out.append(f"    {cb_lc}[]")
        out.append(f"  LOOP")
        out.append(f"END PROC")
    return out


# User-defined function names (lowercased, since identifiers are
# lowercased downstream) — populated by transpile() before per-line
# emit so the call-site rewriter knows which `name(args)` forms to
# convert to `name[args]`. Built-ins like CHR$/INT/SIN keep parens.
_user_function_names: set[str] = set()


def _collect_function_names(statements) -> set[str]:
    names: set[str] = set()
    for s in statements:
        if s.first_word != "FUNCTION":
            continue
        m = _FUNCTION_HEADER_RE.match(s.rest or "")
        if m:
            names.add(m.group(1).lower())
    return names


def _rewrite_user_function_calls(line: str, names: set[str]) -> str:
    """Convert `name(args)` → `name[args]` for every name in the user-
    defined function set. Leaves built-in calls (CHR$(), INT(), etc.)
    untouched. String literals pass through verbatim. Tracks paren
    depth so nested commas don't confuse the boundary detection."""
    if not names:
        return line
    out = []
    i = 0
    n = len(line)
    in_string = False
    while i < n:
        c = line[i]
        if in_string:
            out.append(c)
            if c == '"':
                in_string = False
            elif c == "\\" and i + 1 < n:
                out.append(line[i + 1])
                i += 2
                continue
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            tok = line[i:j]
            # Allow optional whitespace between the identifier and `(`
            # — the upstream `_rewrite_expression` joins first_word and
            # rest with a single space, so a standalone-call statement
            # like `OnTick()` arrives here as `ontick ()`.
            paren_pos = j
            while paren_pos < n and line[paren_pos] == " ":
                paren_pos += 1
            if tok.lower() in names and paren_pos < n and line[paren_pos] == "(":
                # Find matching close-paren, respecting nested ().
                depth = 1
                k = paren_pos + 1
                while k < n and depth > 0:
                    if line[k] == "(":
                        depth += 1
                    elif line[k] == ")":
                        depth -= 1
                    k += 1
                if depth == 0:
                    inner = line[paren_pos + 1:k - 1]
                    out.append(tok)
                    out.append("[")
                    out.append(inner)
                    out.append("]")
                    i = k
                    continue
            out.append(tok)
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


_HANDLERS = {
    "REM":            _emit_rem,
    "OPTION":         _emit_option,
    "POKE":           _emit_poke,
    "TEXTAT":         _emit_textat,
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
    "FUNCTION":       _emit_function,
    "TIMER":          _emit_timer,

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

    # Label statements (`LBL:`) — emit with trailing colon so ugBASIC
    # parses them as goto-targets. Bare identifier without colon would
    # be a syntax error in ugBASIC.
    if stmt.is_label:
        return [f"{kw}:"]

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

    # Block END FUNCTION: rgc-basic FUNCTION terminator → ugBASIC END PROC.
    if kw == "END" and stmt.rest.upper().startswith("FUNCTION"):
        return _emit_end_function(stmt)

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
              emit_include: bool = True,
              base_dir=None) -> TranspileResult:
    """Transpile rgc-basic source to ugBASIC source.

    `target` selects the ugBASIC target hint emitted as the
    `REM @include <target>` directive at the top of the output. The
    transpiler doesn't currently change the body based on target —
    that's a v2 concern (per-target sprite slot caps, palette quirks,
    etc.).

    `emit_include` toggles the leading directive — disable when
    composing transpiled output into a larger program.

    `base_dir` is passed through to preprocess as the directory used
    to resolve #INCLUDE paths. Native rgc-basic preprocess uses the
    filesystem directly; the IDE worker uses a TS-side resolver
    instead.
    """
    global _temp_counter, _empty_tile_emitted
    _temp_counter = 0
    _empty_tile_emitted = False
    pre = preprocess(source, tier="portable", base_dir=base_dir)
    statements = list(tokenize(pre.text))

    errors: list[str] = []
    warnings: list[str] = []

    # ---- Numeric line label handling --------------------------------
    # Mixed numbered/unnumbered code lines is an error: ugBASIC accepts
    # numeric labels but conflating numbered + unnumbered statements is
    # a clear authoring mistake (classic-BASIC source half-converted).
    # Comment-only and blank lines don't count toward the mix.
    numbered = 0
    unnumbered = 0
    for s in statements:
        if s.first_word == "REM" or s.first_word == "":
            continue
        if s.line_num is not None:
            numbered += 1
        else:
            unnumbered += 1
    if numbered > 0 and unnumbered > 0:
        errors.append(
            "mixed numbered/unnumbered lines — pick one style "
            f"(found {numbered} numbered, {unnumbered} unnumbered)"
        )

    # Collect numeric labels referenced by GOTO/GOSUB/THEN/ON/RESTORE.
    # Only referenced labels are preserved on output — unreferenced
    # numeric prefixes drop, keeping output clean and avoiding
    # ugBASIC label-collision warnings.
    referenced: set[int] = _collect_numeric_refs(statements)

    # Collect user-defined FUNCTION names so call sites `name(args)`
    # can be rewritten to ugBASIC's `name[args]`. ugBASIC procedure
    # scoping is local-by-default; emit `GLOBAL "*"` once at the top
    # so the procs see caller-side variables, matching rgc-basic's
    # global-by-default semantics.
    user_fn_names = _collect_function_names(statements)

    # Collect TIMER registrations so PARALLEL PROCEDURE blocks can be
    # hoisted into the prologue (ugBASIC needs the proc defined before
    # SPAWN can reach it; emitting them at top is the simplest way to
    # guarantee that, regardless of where the original TIMER call was
    # in source).
    timers = _collect_timers(statements)

    out: list[str] = []
    if emit_include:
        out.append(f"REM @include {target}")
        out.append(f"REM transpiled from rgc-basic by rgc2ugb v0")
        out.append("")
    # GLOBAL "*" is needed when EITHER user FUNCTIONs OR TIMERs are
    # used — TIMER's hoisted PARALLEL PROCEDUREs are also procs and
    # need caller-side variable visibility.
    if user_fn_names or timers:
        out.append('GLOBAL "*"')
    for ln in _emit_timer_procs(timers):
        out.append(ln)
    for stmt in statements:
        emitted = list(_emit_statement(stmt))
        for i, line in enumerate(emitted):
            # Pipeline:
            #   1. _expand_braces_in_line — splice {NAME}/{number}
            #      PETSCII tokens into `+ CHR$(N) +` concats.
            #   2. _lowercase_identifiers — case-fix per ugBASIC's
            #      `[a-z_]...` identifier rule.
            #   3. _rewrite_user_function_calls — convert paren call
            #      sites of user-defined FUNCTIONs to bracket form.
            cooked = _lowercase_identifiers(_expand_braces_in_line(line))
            cooked = _rewrite_user_function_calls(cooked, user_fn_names)
            # Prepend numeric label only on the first emitted output
            # line of the source statement, only when referenced.
            if i == 0 and stmt.line_num is not None and stmt.line_num in referenced:
                cooked = f"{stmt.line_num} {cooked}"
            out.append(cooked)

    return TranspileResult(text="\n".join(out) + "\n",
                           errors=errors, warnings=warnings)


# Match GOTO/GOSUB/THEN/ELSE-IF-THEN/RESTORE references. Captures any
# numeric token immediately following the keyword. ON x GOTO N1,N2,N3
# also matches via list-walker below.
_REF_AFTER_KW_RE = re.compile(
    r"\b(?:GOTO|GOSUB|THEN|RESTORE)\s+(\d+)",
    re.IGNORECASE,
)
_ON_GOTO_RE = re.compile(
    r"\bON\b.*?\b(?:GOTO|GOSUB)\s+([\d ,]+)",
    re.IGNORECASE,
)


def _collect_numeric_refs(statements) -> set[int]:
    """Walk every statement's text and gather numeric labels referenced
    by control-flow keywords. Used to decide which numeric line labels
    survive on output."""
    refs: set[int] = set()
    for s in statements:
        text = s.rest if s.first_word != "REM" else ""
        # Direct GOTO/GOSUB/THEN/RESTORE <num>
        for m in _REF_AFTER_KW_RE.finditer(text):
            refs.add(int(m.group(1)))
        # ON x GOTO/GOSUB n1,n2,n3
        for m in _ON_GOTO_RE.finditer(text):
            for tok in m.group(1).split(","):
                tok = tok.strip()
                if tok.isdigit():
                    refs.add(int(tok))
        # First-word-is-GOTO/GOSUB form: rest may start with bare number.
        if s.first_word in ("GOTO", "GOSUB") and text:
            head = text.split(None, 1)[0].rstrip(",")
            if head.isdigit():
                refs.add(int(head))
    return refs
