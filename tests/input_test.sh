#!/bin/sh
# Headless INPUT regression: pipe each .in through the interpreter, compare
# stdout to .expected. The interpreter's INPUT is fgets-based (reads stdin),
# so this is the oracle for INPUT semantics (the emit_c rgc_input mirrors it).
set -e
cd "$(dirname "$0")/.."
BASIC=./basic
fail=0
for bas in tests/input/*.bas; do
  name=$(basename "$bas" .bas)
  got=$("$BASIC" "$bas" < "tests/input/$name.in" 2>&1 | tr -d '\r')
  want=$(cat "tests/input/$name.expected" | tr -d '\r')
  if [ "$got" = "$want" ]; then
    echo "  ok:   $name"
  else
    echo "  FAIL: $name"; echo "    want: [$want]"; echo "    got:  [$got]"; fail=1
  fi
done
[ "$fail" = 0 ] && echo "==> input: all pass" || { echo "==> input: FAILURES"; exit 1; }
