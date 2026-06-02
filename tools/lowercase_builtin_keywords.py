#!/usr/bin/env python3
"""Lowercase RGC-BASIC built-in keywords/functions in a .bas file (token-aware).

Preserves: double-quoted strings, apostrophe comments, UDF names (FUNCTION ...),
and identifiers that look like game variables (ALL_CAPS or DIM/FOR bindings).

Usage: python3 tools/lowercase_builtin_keywords.py examples/trek-new.bas
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_builtin_names() -> set[str]:
    spec = json.loads((ROOT / "spec.json").read_text())
    names: set[str] = set()
    for entry in spec["keywords"]:
        if entry["kind"] in ("keyword", "function", "constant"):
            names.add(entry["name"].upper())
    return names


def collect_udfs(text: str) -> dict[str, str]:
    """Map upper name -> canonical spelling."""
    udfs: dict[str, str] = {}
    for m in re.finditer(r"^FUNCTION\s+(\w+)\s*\(", text, re.MULTILINE | re.IGNORECASE):
        name = m.group(1)
        udfs[name.upper()] = name
    return udfs


def strip_strings_and_comments(text: str) -> str:
    """Replace string/comment bodies with spaces so preserve scans skip them."""
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            out.append(" ")
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    out.extend("  ")
                    i += 2
                    continue
                if text[i] == '"':
                    out.append(" ")
                    i += 1
                    break
                out.append(" ")
                i += 1
            continue
        if c == "'":
            while i < n and text[i] not in "\n\r":
                out.append(" " if text[i] not in "\n\r" else text[i])
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def collect_preserve_vars(text: str, udfs: dict[str, str]) -> set[str]:
    code = strip_strings_and_comments(text)
    preserve: set[str] = set()
    for m in re.finditer(r"\b([A-Z][A-Z0-9_]*)\s*=", code):
        preserve.add(m.group(1))
    for m in re.finditer(r"\bFOR\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code, re.IGNORECASE):
        preserve.add(m.group(1).upper())
    for m in re.finditer(r"\bDIM\s+([^:\n]+)", code, re.IGNORECASE):
        chunk = m.group(1)
        for part in re.split(r",", chunk):
            part = part.strip()
            m2 = re.match(r"([A-Za-z_][A-Za-z0-9_]*)(\s*\(|$)", part)
            if m2:
                preserve.add(m2.group(1).upper())
    for m in re.finditer(r"\bDEF\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", code, re.IGNORECASE):
        preserve.add(m.group(1).upper())
    for m in re.finditer(r"\b([A-Z][A-Z0-9_]*)\s*:\s*$", code, re.MULTILINE):
        if m.group(1).upper() not in udfs:
            preserve.add(m.group(1))
    # State constants and well-known temps
    for m in re.finditer(r"\bST_[A-Z0-9_]+\b", text):
        preserve.add(m.group(0))
    preserve.update(
        {
            "TI",
            "N",
            "I",
            "J",
            "K",
            "L",
            "A",
            "B",
            "C",
            "D",
            "E",
            "F",
            "G",
            "H",
            "P",
            "Q",
            "R",
            "S",
            "T",
            "U",
            "V",
            "W",
            "X",
            "Y",
            "Z",
        }
    )
    return preserve


def transform(text: str, builtins: set[str], udfs: dict[str, str], preserve: set[str]) -> str:
    out: list[str] = []
    i = 0
    n = len(text)

    def emit_lower(ident: str, suffix: str) -> None:
        up = ident.upper()
        if up in udfs:
            out.append(udfs[up] + suffix)
            return
        if up in preserve and ident.isupper():
            out.append(ident + suffix)
            return
        if up in builtins:
            out.append(ident.lower() + suffix)
            return
        out.append(ident + suffix)

    while i < n:
        c = text[i]
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                if text[i] == "\\" and i + 1 < n:
                    out.append(text[i : i + 2])
                    i += 2
                    continue
                out.append(text[i])
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c == "'":
            j = i
            while j < n and text[j] not in "\n\r":
                j += 1
            out.append(text[i:j])
            i = j
            continue
        if c == "#":
            j = i + 1
            while j < n and (text[j].isalnum() or text[j] == "_"):
                j += 1
            raw = text[i:j]
            body = raw[1:]
            if body.upper() in builtins:
                out.append("#" + body.lower())
            else:
                out.append(raw)
            i = j
            continue
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)(\$?)", text[i:])
        if m:
            emit_lower(m.group(1), m.group(2))
            i += len(m.group(0))
            continue
        out.append(c)
        i += 1

    return "".join(out)


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "examples/trek-new.bas")
    text = path.read_text()
    builtins = load_builtin_names()
    udfs = collect_udfs(text)
    preserve = collect_preserve_vars(text, udfs)
    new_text = transform(text, builtins, udfs, preserve)
    if new_text != text:
        path.write_text(new_text)
        print(f"Updated {path}")
    else:
        print(f"No changes {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
