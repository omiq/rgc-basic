#!/bin/sh
# Headless conformance corpus runner.
#
# Runs every conformance/**/*.bas with --json-status and treats a non-zero
# exit (runtime error = 1, ASSERT failure = 2) as a test failure. The scripts
# use ASSERT to gate expected behaviour, so this is a regression gate that both
# rgc-basic CI and external adopters (Haversack) can run against the same
# corpus — no drift between what rgc-basic tests and what tools rely on.
#
# This is intentionally separate from examples/ and tests/*.bas: those include
# interactive gfx / music / RPG demos that can't run headlessly. Conformance
# scripts are short, headless, and assert on known output.
#
# Usage: sh conformance/run.sh [path-to-basic-binary]
#   default binary: ./basic (or ./basic.exe on Windows)
set -e

cd "$(dirname "$0")/.."

BASIC="${1:-./basic}"
if [ ! -x "$BASIC" ] && [ -x "${BASIC}.exe" ]; then
    BASIC="${BASIC}.exe"
fi
if [ ! -x "$BASIC" ]; then
    echo "conformance/run.sh: binary not found or not executable: $BASIC" >&2
    exit 1
fi

fails=0
total=0
for t in conformance/*/*.bas; do
    [ -e "$t" ] || continue
    total=$((total + 1))
    # Capture basic's own exit code (not the pipeline's) — run to temp files.
    # if-guard so `set -e` doesn't abort the loop on a failing test.
    if "$BASIC" --json-status "$t" >/tmp/conf_out.$$ 2>/tmp/conf_err.$$; then
        code=0
    else
        code=$?
    fi
    status=$(tail -1 /tmp/conf_out.$$ 2>/dev/null || true)
    err=$(cat /tmp/conf_err.$$ 2>/dev/null || true)
    rm -f /tmp/conf_out.$$ /tmp/conf_err.$$
    if [ "$code" -eq 0 ]; then
        echo "ok   $t  $status"
    else
        echo "FAIL $t  (exit $code)  $status"
        [ -n "$err" ] && echo "$err" | sed 's/^/       /'
        fails=$((fails + 1))
    fi
done

echo "conformance: $((total - fails))/$total passed"
[ "$fails" -eq 0 ] || exit 1
