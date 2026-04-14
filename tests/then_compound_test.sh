#!/bin/sh
# Regression: IF cond THEN <stmt-with-comma-args> : <stmt> must run the
# trailing : stmt. Wraps tests/then_compound_test.bas which prints PASS
# only if every case behaves correctly; this script grep-checks for it.
set -e
cd "$(dirname "$0")/.."
BASIC="./basic"
[ -x "$BASIC" ] || { make || exit 1; }

OUT=$("$BASIC" tests/then_compound_test.bas 2>&1)
echo "$OUT"
echo "$OUT" | grep -q "^PASS$" || {
    echo "then_compound_test: FAIL — expected PASS line in output" >&2
    exit 1
}
echo "then_compound_test: ok"
