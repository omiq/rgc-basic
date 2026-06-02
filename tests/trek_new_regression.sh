#!/bin/sh
# Deterministic regression for examples/trek-new.bas (structured Super Star Trek).
#
# Replaces RND(-1) and RND(-TI) with RND(1) so the default rand() seed is stable,
# then pipes fixed command scripts and diffs terminal output against committed goldens.
#
# Usage (from repo root):
#   sh tests/trek_new_regression.sh
#   sh tests/trek_new_regression.sh path/to/other.bas
#
# Refresh goldens after an intentional behaviour change:
#   UPDATE_GOLDEN=1 sh tests/trek_new_regression.sh
#
# Requires: ./basic built, python3 (sed transform only).

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="${1:-$ROOT/examples/trek-new.bas}"
BIN="$ROOT/basic"
FIX="$ROOT/tests/fixtures/trek_new"
WORK="$(mktemp "${TMPDIR:-/tmp}/trek-new-reg.XXXXXX.bas")"
trap 'rm -f "$WORK"' EXIT

if [ ! -x "$BIN" ]; then
  echo "trek_new_regression: missing $BIN (run make)" >&2
  exit 1
fi
if [ ! -f "$SRC" ]; then
  echo "trek_new_regression: no such file: $SRC" >&2
  exit 1
fi

sed -e 's/RND(-1)/RND(1)/g' -e 's/RND(-TI)/RND(1)/g' "$SRC" > "$WORK"

fail=0
for tag in A B C; do
  IN="$FIX/input_${tag}.txt"
  GOLD="$FIX/golden_${tag}.txt"
  OUT="$(mktemp "${TMPDIR:-/tmp}/trek-new-out.XXXXXX.txt")"
  if [ ! -f "$IN" ]; then
    echo "trek_new_regression: missing $IN" >&2
    exit 1
  fi
  "$BIN" -petscii "$WORK" < "$IN" > "$OUT" 2>&1
  ec=$?
  if [ "$ec" -ne 0 ]; then
    echo "scenario $tag: basic exited $ec" >&2
    fail=1
    rm -f "$OUT"
    continue
  fi
  if [ "${UPDATE_GOLDEN:-0}" = 1 ]; then
    cp "$OUT" "$GOLD"
    echo "scenario $tag: updated $GOLD"
  elif [ ! -f "$GOLD" ]; then
    echo "scenario $tag: missing golden $GOLD" >&2
    fail=1
  elif ! diff -q "$GOLD" "$OUT" >/dev/null; then
    echo "scenario $tag: FAIL (output differs from $GOLD)" >&2
    diff -u "$GOLD" "$OUT" | head -40 >&2
    fail=1
  else
    echo "scenario $tag: OK"
  fi
  rm -f "$OUT"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "trek_new_regression: all scenarios passed"
