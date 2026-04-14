#!/bin/sh
# Run every tests/*.bas file headlessly, skipping the ones that need
# interactive input or are intentional negative tests. Single source of
# truth for the skip list — invoked by both .github/workflows/ci.yml
# (Unix and Windows steps) and the Makefile's `make check` target.
#
# Usage: sh tests/run_bas_suite.sh [path-to-basic-binary]
#   default binary: ./basic (or ./basic.exe on Windows)
#
# Exits non-zero on the first .bas file that exits non-zero.
set -e

cd "$(dirname "$0")/.."

BASIC="${1:-./basic}"
if [ ! -x "$BASIC" ] && [ -x "${BASIC}.exe" ]; then
    BASIC="${BASIC}.exe"
fi

if [ ! -x "$BASIC" ]; then
    echo "run_bas_suite: binary not found or not executable: $BASIC" >&2
    exit 1
fi

for t in tests/*.bas; do
    case "$(basename "$t")" in
        # Interactive: need keyboard input or a real terminal.
        codes-replaced.bas|locate.bas|get_input_loop.bas|get_while_test.bas|kbuffer.bas|border_option_test.bas|gfx_title_test.bas)
            echo "skip (interactive): $t"
            continue
            ;;
        # Negative: expected to fail; covered by other harnesses.
        meta_include_dup_line.bas|meta_include_dup_label.bas|meta_include_circular_a.bas|meta_include_circular_b.bas)
            echo "skip (negative): $t"
            continue
            ;;
    esac
    echo "run: $t"
    "$BASIC" -petscii "$t" >/dev/null
done

echo "run_bas_suite: all .bas tests passed"
