"""rgc-lint command-line entry.

Usage:
    python3 -m tools.rgc_lint.cli --tier=portable file1.bas [file2.bas ...]
    python3 -m tools.rgc_lint.cli --tier=portable --json file.bas
    python3 -m tools.rgc_lint.cli --strict --tier=portable file.bas

Exit codes:
    0  all files clean
    1  one or more files had errors
    2  bad CLI arguments / IO error
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .directives import preprocess_file
from .tokenizer import tokenize
from .walker import Diagnostic, lint, load_rules


def _format_text(diags: list[Diagnostic]) -> str:
    if not diags:
        return ""
    out = []
    for d in diags:
        out.append(
            f"{d.file}:{d.line}:{d.col}: {d.severity}: {d.message}"
        )
    return "\n".join(out)


def _format_json(file: str, tier: str, diags: list[Diagnostic]) -> str:
    return json.dumps({
        "file": file,
        "tier": tier,
        "errors": [d.__dict__ for d in diags if d.severity == "error"],
        "warnings": [d.__dict__ for d in diags if d.severity == "warning"],
    }, indent=2)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="rgc-lint",
        description="Portability linter for rgc-basic source files.",
    )
    ap.add_argument(
        "--tier", choices=["portable", "modern"], default="portable",
        help="target tier: portable (default) or modern",
    )
    ap.add_argument(
        "--strict", action="store_true",
        help="warnings count as errors for exit code purposes",
    )
    ap.add_argument(
        "--json", action="store_true",
        help="emit JSON diagnostics (one report per file, NDJSON)",
    )
    ap.add_argument(
        "files", nargs="+",
        help="rgc-basic source files (.bas)",
    )
    args = ap.parse_args(argv)

    rules = load_rules()
    total_errors = 0
    total_warnings = 0

    for path in args.files:
        p = Path(path)
        if not p.exists():
            print(f"rgc-lint: not found: {path}", file=sys.stderr)
            return 2
        try:
            pre = preprocess_file(path, tier=args.tier)
        except OSError as e:
            print(f"rgc-lint: {path}: {e}", file=sys.stderr)
            return 2

        # If file declares a tier and it doesn't match, lint anyway but
        # with the file's stated tier (so a "portable" file authored
        # for portable always gets validated as such).
        effective_tier = pre.declared_tier or args.tier
        statements = list(tokenize(pre.text))
        diags = lint(statements, file=path, tier=effective_tier, rules=rules)

        n_err = sum(1 for d in diags if d.severity == "error")
        n_warn = sum(1 for d in diags if d.severity == "warning")
        total_errors += n_err
        total_warnings += n_warn

        if args.json:
            print(_format_json(path, effective_tier, diags))
        else:
            text = _format_text(diags)
            if text:
                print(text)

    if not args.json:
        if total_errors or total_warnings:
            print(
                f"rgc-lint: {total_errors} error(s), {total_warnings} warning(s)"
            )
        else:
            print("rgc-lint: clean")

    if total_errors > 0:
        return 1
    if args.strict and total_warnings > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
