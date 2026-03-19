#!/bin/sh
# Test user's GET/WHILE pattern with various keypress combinations.
# Verifies predicted vs actual output for: WHILE K$<>"Q" ... IF K$<>"" THEN PRINT K$ ... GET K$ ... WEND
set -e
cd "$(dirname "$0")/.."
BASIC="./basic"
[ -x ./basic ] || { make || exit 1; }

# Run and capture output (first 30 lines)
run() {
    printf '%s' "$1" | $BASIC -petscii tests/get_while_test.bas 2>/dev/null | head -30
}

# Test 1: Q only - should exit immediately, print DONE
echo "Test 1: Q (exit)"
out=$(run "Q")
exp="DONE"
if ! echo "$out" | grep -q "^DONE"; then
    echo "FAIL: expected DONE, got: $out"
    exit 1
fi

# Test 2: A then Q - should print A, then DONE (no newline between in same line for A)
echo "Test 2: A, Q"
out=$(run "AQ")
if ! echo "$out" | grep -q "A"; then
    echo "FAIL: expected A in output, got: $out"
    exit 1
fi
if ! echo "$out" | grep -q "DONE"; then
    echo "FAIL: expected DONE, got: $out"
    exit 1
fi

# Test 3: A, Enter, Q - A printed, Enter yields CHR$(13) printed (CR or newline), then Q exits
echo "Test 3: A, Enter, Q"
out=$(run "A
Q")
if ! echo "$out" | grep -q "A"; then
    echo "FAIL: expected A, got: $out"
    exit 1
fi
if ! echo "$out" | grep -q "DONE"; then
    echo "FAIL: expected DONE, got: $out"
    exit 1
fi

# Test 4: AB Enter Q - should show A, B, then newline from Enter, then DONE
echo "Test 4: AB, Enter, Q"
out=$(run "AB
Q")
echo "$out" | head -5

# Test 5: Enter Enter Q - two Enters, then Q
echo "Test 5: Enter Enter Q"
out=$(run "

Q")
if ! echo "$out" | grep -q "DONE"; then
    echo "FAIL: expected DONE, got: $out"
    exit 1
fi

# Test 6: sls Enter Q (trek-style)
echo "Test 6: sls Enter Q"
out=$(run "sls
Q")
if ! echo "$out" | grep -q "s"; then
    echo "FAIL: expected s, got: $out"
    exit 1
fi
if ! echo "$out" | grep -q "DONE"; then
    echo "FAIL: expected DONE, got: $out"
    exit 1
fi

echo "All get_while_keys tests passed."
