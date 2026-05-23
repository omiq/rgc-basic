#!/bin/sh
# Run the headless conformance corpus against the basic-wasm build, via the
# node runner (tests/run-wasm.js). Mirror of conformance/run.sh (which uses the
# native ./basic) so the SAME corpus gates both build targets — no drift.
#
# Needs: node on PATH + a built web/basic.js (run `make basic-wasm` first).
#
# Usage: sh conformance/run-wasm.sh
set -e

cd "$(dirname "$0")/.."

if ! command -v node >/dev/null 2>&1; then
    echo "conformance/run-wasm.sh: node not found on PATH" >&2
    exit 1
fi
if [ ! -f web/basic.js ]; then
    echo "conformance/run-wasm.sh: web/basic.js missing — run 'make basic-wasm'" >&2
    exit 1
fi

fails=0
total=0
for t in conformance/*/*.bas; do
    [ -e "$t" ] || continue
    total=$((total + 1))
    if node tests/run-wasm.js "$t" >/tmp/confw_out.$$ 2>/tmp/confw_err.$$; then
        code=0
    else
        code=$?
    fi
    status=$(tail -1 /tmp/confw_out.$$ 2>/dev/null || true)
    err=$(cat /tmp/confw_err.$$ 2>/dev/null || true)
    rm -f /tmp/confw_out.$$ /tmp/confw_err.$$
    if [ "$code" -eq 0 ]; then
        echo "ok   $t  $status"
    else
        echo "FAIL $t  (exit $code)  $status"
        [ -n "$err" ] && echo "$err" | sed 's/^/       /'
        fails=$((fails + 1))
    fi
done

echo "wasm-conformance: $((total - fails))/$total passed"
[ "$fails" -eq 0 ] || exit 1
