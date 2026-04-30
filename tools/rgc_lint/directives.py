"""Pre-process source files for the linter / transpiler.

Three concerns folded into one pre-pass:

  1. `#OPTION tier portable` — file-level claim. If present and the
     caller's tier matches, lint runs strict. Otherwise: ignored.

  2. `#IF MODERN` / `#IF RETRO` ... `#END IF` — conditional blocks.
     Lines inside a block matching the caller's tier are kept; the
     other branch is replaced with blank lines so line numbers stay
     stable for diagnostics.

  3. `#INCLUDE "path"` — recursive splice. The included file's lines
     are inlined; line numbers in diagnostics will refer to the
     included file's offset (we re-tokenize per file). v1 tracks the
     active file path through tokenization; the linter walks each
     file separately and concatenates diagnostics.

Block form only — `#IF` / `#END IF`. No `#ELSEIF` / `#ELSE` (yet).
That keeps the preprocessor a 30-line state machine.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


# Match #OPTION tier <name> at start of line, ignoring leading whitespace.
_OPT_TIER_RE = re.compile(r"^\s*#\s*OPTION\s+tier\s+(\w+)\s*$", re.IGNORECASE)
_IF_RE = re.compile(r"^\s*#\s*IF\s+(MODERN|RETRO|PORTABLE)\s*$", re.IGNORECASE)
_END_IF_RE = re.compile(r"^\s*#\s*END\s*IF\s*$", re.IGNORECASE)
_INCLUDE_RE = re.compile(r'^\s*#\s*INCLUDE\s+"([^"]+)"\s*$', re.IGNORECASE)


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


def preprocess(source: str, *, tier: str = "portable",
               base_dir: Path | None = None,
               _seen: set[str] | None = None) -> PreprocessResult:
    """Walk a source string, applying directives.

    `tier` selects which #IF blocks survive.
    `base_dir` is the directory used to resolve #INCLUDE paths.
    `_seen` tracks already-included files to break cycles.
    """
    if _seen is None:
        _seen = set()
    out_lines: list[str] = []
    declared_tier: str | None = None
    includes: list[str] = []

    in_block = False
    block_keep = True

    for raw in source.splitlines():
        m_opt = _OPT_TIER_RE.match(raw)
        if m_opt:
            declared_tier = m_opt.group(1).lower()
            out_lines.append("")
            continue

        m_if = _IF_RE.match(raw)
        if m_if:
            if in_block:
                # Nested #IF — refuse for v1, keep simple.
                out_lines.append(
                    "#REM rgc-lint: nested #IF not supported (v1)"
                )
                continue
            in_block = True
            block_keep = _tier_matches(m_if.group(1), tier)
            out_lines.append("")
            continue

        if _END_IF_RE.match(raw):
            in_block = False
            block_keep = True
            out_lines.append("")
            continue

        m_inc = _INCLUDE_RE.match(raw)
        if m_inc:
            inc_path = m_inc.group(1)
            full = (base_dir / inc_path) if base_dir else Path(inc_path)
            full = full.resolve()
            if str(full) in _seen:
                out_lines.append(
                    f"#REM rgc-lint: skipping already-included {inc_path}"
                )
                continue
            try:
                inc_text = full.read_text(encoding="utf-8")
            except OSError:
                out_lines.append(
                    f"#REM rgc-lint: cannot read INCLUDE {inc_path}"
                )
                continue
            _seen.add(str(full))
            includes.append(str(full))
            sub = preprocess(
                inc_text,
                tier=tier,
                base_dir=full.parent,
                _seen=_seen,
            )
            includes.extend(sub.includes)
            # Splice as a marker so the walker can attribute diags.
            out_lines.append(f"#REM ===== INCLUDED {inc_path} =====")
            out_lines.extend(sub.text.splitlines())
            out_lines.append(f"#REM ===== END INCLUDE {inc_path} =====")
            continue

        if in_block and not block_keep:
            out_lines.append("")
            continue

        out_lines.append(raw)

    return PreprocessResult(
        text="\n".join(out_lines),
        declared_tier=declared_tier,
        includes=includes,
    )


def preprocess_file(path: str, *, tier: str = "portable") -> PreprocessResult:
    p = Path(path).resolve()
    text = p.read_text(encoding="utf-8")
    return preprocess(text, tier=tier, base_dir=p.parent, _seen={str(p)})
