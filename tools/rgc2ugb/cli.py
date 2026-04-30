"""rgc2ugb — rgc-basic → ugBASIC source-to-source transpiler.

Usage:
    python3 -m tools.rgc2ugb.cli --target=c64 input.bas -o out.ugb
    python3 -m tools.rgc2ugb.cli --target=atari --stdout input.bas

Exit codes:
    0  transpiled cleanly
    1  source contained errors that block translation
    2  bad CLI arguments / IO error

Pairs with the linter — recommended workflow is `rgc-lint --tier=portable
file.bas` first, then `rgc2ugb --target=c64 file.bas`. Transpiler will
still emit on a non-portable file, but the result will contain `REM
rgc2ugb: ...` markers where features couldn't be mapped.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .emit import transpile


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="rgc2ugb",
        description="Transpile rgc-basic source to ugBASIC source.",
    )
    ap.add_argument(
        "--target", default="c64",
        help="ugBASIC target name (c64, atari, atarixl, cpc, msx1, "
             "zx, plus4, vic20, ...). Emitted as @include directive.",
    )
    ap.add_argument(
        "-o", "--output", default=None,
        help="output file (default: input.ugb)",
    )
    ap.add_argument(
        "--stdout", action="store_true",
        help="write to stdout instead of a file",
    )
    ap.add_argument("input", help="rgc-basic source (.bas)")
    args = ap.parse_args(argv)

    src_path = Path(args.input)
    if not src_path.exists():
        print(f"rgc2ugb: not found: {args.input}", file=sys.stderr)
        return 2
    try:
        source = src_path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"rgc2ugb: {args.input}: {e}", file=sys.stderr)
        return 2

    result = transpile(source, target=args.target)

    if args.stdout:
        sys.stdout.write(result.text)
    else:
        out_path = Path(args.output) if args.output else src_path.with_suffix(".ugb")
        try:
            out_path.write_text(result.text, encoding="utf-8")
        except OSError as e:
            print(f"rgc2ugb: cannot write {out_path}: {e}", file=sys.stderr)
            return 2
        print(f"rgc2ugb: wrote {out_path}")

    if result.errors:
        for e in result.errors:
            print(f"rgc2ugb: error: {e}", file=sys.stderr)
        return 1
    for w in result.warnings:
        print(f"rgc2ugb: warning: {w}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
