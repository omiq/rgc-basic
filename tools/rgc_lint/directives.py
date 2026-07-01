"""Pre-process source files for the linter / transpiler.

Three concerns folded into one pre-pass:

  1. `#OPTION tier portable` — file-level claim. If present and the
     caller's tier matches, lint runs strict. Otherwise: ignored.

  2. `#IF <cond>` / `#ELSEIF <cond>` / `#ELSE` ... `#END IF` —
     conditional blocks. The first branch whose condition matches the
     caller wins; every other branch is replaced with blank lines so
     line numbers stay stable for diagnostics.

     Conditions come in two flavours:
       - tier:   `MODERN` / `RETRO` / `PORTABLE` (the coarse axis)
       - target: `TARGET <id[,id...]>` (a specific machine, matched
                 against the caller's `target`, e.g. `c64`, `zxspectrum`)

  3. `#INCLUDE "path"` — recursive splice. The included file's lines
     are inlined; line numbers in diagnostics will refer to the
     included file's offset (we re-tokenize per file). v1 tracks the
     active file path through tokenization; the linter walks each
     file separately and concatenates diagnostics.

Block form only — no nesting (v1). `#ELSE IF` is accepted as a spelling
of `#ELSEIF`. When `target` is unset (the linter's default) a
`TARGET` condition never matches, so lint checks the portable `#ELSE`
fallback branch.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


# Match #OPTION tier <name> at start of line, ignoring leading whitespace.
_OPT_TIER_RE = re.compile(r"^\s*#\s*OPTION\s+tier\s+(\w+)\s*$", re.IGNORECASE)
# #IF / #ELSEIF capture the raw condition text after the keyword.
_IF_RE = re.compile(r"^\s*#\s*IF\s+(.+?)\s*$", re.IGNORECASE)
_ELSEIF_RE = re.compile(r"^\s*#\s*ELSE\s*IF\s+(.+?)\s*$", re.IGNORECASE)
_ELSE_RE = re.compile(r"^\s*#\s*ELSE\s*$", re.IGNORECASE)
_END_IF_RE = re.compile(r"^\s*#\s*END\s*IF\s*$", re.IGNORECASE)
_INCLUDE_RE = re.compile(r'^\s*#\s*INCLUDE\s+"([^"]+)"\s*$', re.IGNORECASE)
_TARGET_COND_RE = re.compile(r"^TARGET\s+(.+)$", re.IGNORECASE)


@dataclass
class PreprocessResult:
    text: str
    declared_tier: str | None  # from #OPTION tier — None if not stated
    includes: list[str]        # ordered list of included file paths


def _tier_matches(block: str, tier: str) -> bool:
    """Decide whether a block's lines should be kept for the given
    caller tier.

    Mapping:
      block=MODERN, tier=modern   -> keep
      block=MODERN, tier=portable -> drop (modern-only feature)
      block=RETRO,  tier=modern   -> drop (modern build doesn't need
                                     the retro fallback)
      block=RETRO,  tier=portable -> keep
      block=PORTABLE, *           -> always keep
    """
    block_u = block.upper()
    tier_u = tier.lower()
    if block_u == "PORTABLE":
        return True
    if block_u == "MODERN":
        return tier_u == "modern"
    if block_u == "RETRO":
        return tier_u == "portable"
    return True


def _cond_matches(cond: str, target: str | None, tier: str) -> bool:
    """Evaluate an #IF / #ELSEIF condition for the given caller.

    Two condition flavours:
      - `TARGET c64` / `TARGET c64,c128,plus4` — matches when `target`
        equals one of the listed ids (case-insensitive). When `target`
        is None (lint default) a TARGET condition never matches.
      - a bare tier keyword (MODERN / RETRO / PORTABLE) — delegated to
        `_tier_matches`.
    """
    cond = cond.strip()
    m = _TARGET_COND_RE.match(cond)
    if m:
        if not target:
            return False
        ids = [x.strip().lower() for x in m.group(1).split(",") if x.strip()]
        return target.lower() in ids
    return _tier_matches(cond, tier)


def preprocess(source: str, *, tier: str = "portable",
               target: str | None = None,
               base_dir: Path | None = None,
               _seen: set[str] | None = None) -> PreprocessResult:
    """Walk a source string, applying directives.

    `tier` selects which tier `#IF` blocks survive.
    `target` selects which `#IF TARGET <id>` blocks survive (None =
    lint default: TARGET blocks drop, the `#ELSE` fallback is kept).
    `base_dir` is the directory used to resolve #INCLUDE paths.
    `_seen` tracks already-included files to break cycles.
    """
    if _seen is None:
        _seen = set()
    out_lines: list[str] = []
    declared_tier: str | None = None
    includes: list[str] = []

    in_block = False       # inside an #IF ... #END IF chain
    branch_taken = False   # some branch in this chain already matched
    keep_current = True    # keep lines in the current branch

    for raw in source.splitlines():
        # Chain-control directives are evaluated even inside a dropped
        # branch, so the #IF/#ELSEIF/#ELSE/#END IF state stays correct.
        # #ELSEIF / #ELSE IF — must be checked before #ELSE and #IF.
        m_elseif = _ELSEIF_RE.match(raw)
        if m_elseif:
            if not in_block:
                out_lines.append("REM rgc-lint: #ELSEIF without #IF")
                continue
            if branch_taken:
                keep_current = False
            else:
                keep_current = _cond_matches(m_elseif.group(1), target, tier)
                branch_taken = branch_taken or keep_current
            out_lines.append("")
            continue

        if _ELSE_RE.match(raw):
            if not in_block:
                out_lines.append("REM rgc-lint: #ELSE without #IF")
                continue
            keep_current = not branch_taken
            branch_taken = True
            out_lines.append("")
            continue

        m_if = _IF_RE.match(raw)
        if m_if:
            if in_block:
                # Nested #IF — refuse for v1, keep simple.
                out_lines.append(
                    "REM rgc-lint: nested #IF not supported (v1)"
                )
                continue
            in_block = True
            keep_current = _cond_matches(m_if.group(1), target, tier)
            branch_taken = keep_current
            out_lines.append("")
            continue

        if _END_IF_RE.match(raw):
            in_block = False
            branch_taken = False
            keep_current = True
            out_lines.append("")
            continue

        # Dropped branch: everything else (including #OPTION / #INCLUDE)
        # is suppressed, replaced by a blank line to keep numbering.
        if in_block and not keep_current:
            out_lines.append("")
            continue

        m_opt = _OPT_TIER_RE.match(raw)
        if m_opt:
            declared_tier = m_opt.group(1).lower()
            out_lines.append("")
            continue

        m_inc = _INCLUDE_RE.match(raw)
        if m_inc:
            inc_path = m_inc.group(1)
            full = (base_dir / inc_path) if base_dir else Path(inc_path)
            full = full.resolve()
            if str(full) in _seen:
                out_lines.append(
                    f"REM rgc-lint: skipping already-included {inc_path}"
                )
                continue
            try:
                inc_text = full.read_text(encoding="utf-8")
            except OSError:
                out_lines.append(
                    f"REM rgc-lint: cannot read INCLUDE {inc_path}"
                )
                continue
            _seen.add(str(full))
            includes.append(str(full))
            sub = preprocess(
                inc_text,
                tier=tier,
                target=target,
                base_dir=full.parent,
                _seen=_seen,
            )
            includes.extend(sub.includes)
            # Splice as a marker so the walker can attribute diags.
            out_lines.append(f"REM ===== INCLUDED {inc_path} =====")
            out_lines.extend(sub.text.splitlines())
            out_lines.append(f"REM ===== END INCLUDE {inc_path} =====")
            continue

        out_lines.append(raw)

    return PreprocessResult(
        text="\n".join(out_lines),
        declared_tier=declared_tier,
        includes=includes,
    )


def preprocess_file(path: str, *, tier: str = "portable",
                    target: str | None = None) -> PreprocessResult:
    p = Path(path).resolve()
    text = p.read_text(encoding="utf-8")
    return preprocess(text, tier=tier, target=target,
                      base_dir=p.parent, _seen={str(p)})
