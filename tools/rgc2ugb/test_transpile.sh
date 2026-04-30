#!/bin/sh
# Snapshot test for rgc2ugb. For every tests/portable/X.bas that has a
# matching tests/transpile/X.expected.ugb, transpile the .bas and diff
# the output against the snapshot. Any mismatch fails.
#
# Run from repo root: sh tools/rgc2ugb/test_transpile.sh
# Update snapshots: UPDATE=1 sh tools/rgc2ugb/test_transpile.sh

set -e
cd "$(dirname "$0")/../.."

FAIL=0
for src in tests/portable/*.bas; do
    base=$(basename "$src" .bas)
    expected="tests/transpile/${base}.expected.ugb"
    if [ ! -f "$expected" ]; then
        continue
    fi
    actual=$(python3 -m tools.rgc2ugb.cli --stdout --target=c64 "$src" 2>/dev/null)
    if [ -n "${UPDATE:-}" ]; then
        printf '%s' "$actual" > "$expected"
        echo "  upd:  $expected"
        continue
    fi
    if [ "$actual" = "$(cat "$expected")" ]; then
        echo "  ok:   $src -> $expected"
    else
        echo "  FAIL: $src vs $expected"
        tmp=$(mktemp)
        printf '%s\n' "$actual" > "$tmp"
        diff "$tmp" "$expected" || true
        rm -f "$tmp"
        FAIL=$((FAIL + 1))
    fi
done

if [ "$FAIL" -gt 0 ]; then
    echo "==> rgc2ugb: $FAIL snapshot failure(s)"
    exit 1
fi
echo "==> rgc2ugb: all transpile snapshots match"
