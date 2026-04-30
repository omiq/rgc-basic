#!/bin/sh
# Smoke-test the linter against tests/portable/*.bas (all must lint clean)
# and tests/non-portable/*.bas (each must produce at least one error).
#
# Run from the repo root: sh tools/rgc_lint/test_lint.sh
# Exits non-zero on the first unexpected outcome.

set -e

cd "$(dirname "$0")/../.."

LINT="python3 -m tools.rgc_lint.cli --tier=portable"

echo "==> tests/portable/ (must lint clean)"
PORTABLE_FAIL=0
for f in tests/portable/*.bas; do
    if ! $LINT "$f" >/dev/null 2>&1; then
        echo "  FAIL: $f did NOT lint clean"
        $LINT "$f" || true
        PORTABLE_FAIL=$((PORTABLE_FAIL + 1))
    else
        echo "  ok:   $f"
    fi
done

echo "==> tests/non-portable/ (each must report at least one error)"
NONPORT_FAIL=0
for f in tests/non-portable/*.bas; do
    if $LINT "$f" >/dev/null 2>&1; then
        echo "  FAIL: $f linted clean but should have errored"
        NONPORT_FAIL=$((NONPORT_FAIL + 1))
    else
        echo "  ok:   $f errored as expected"
    fi
done

if [ "$PORTABLE_FAIL" -ne 0 ] || [ "$NONPORT_FAIL" -ne 0 ]; then
    echo "==> rgc-lint: $PORTABLE_FAIL portable failure(s), $NONPORT_FAIL non-portable failure(s)"
    exit 1
fi
echo "==> rgc-lint: all linter tests passed"
