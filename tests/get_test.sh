#!/bin/sh
# Rigorous GET tests: verify no trailing chars, no duplicates when piping input.
# Run: sh tests/get_test.sh
set -e
cd "$(dirname "$0")/.."
BASIC="./basic"
[ -x ./basic ] || { make || exit 1; }

run_get() {
    # $1 = input to pipe (newline is auto-appended to trigger Enter)
    # $2 = expected LII$ value (what "GOT:" should show)
    # $3 = optional: max lines of output to capture (default 20)
    local input="$1"
    local expected="$2"
    local maxlines="${3:-20}"
    local out
    out=$(printf '%s\n' "$input" | $BASIC -petscii tests/get_input_loop.bas 2>/dev/null | head -n "$maxlines")
    local got
    got=$(echo "$out" | grep "^GOT:" | head -1 | sed 's/^GOT://' | tr -d ' \t')
    if [ "$got" != "$expected" ]; then
        echo "FAIL: input='$input' expected GOT:$expected got GOT:$got"
        echo "Full output:"
        echo "$out"
        return 1
    fi
    # Check for trailing character bug: after "GOT:xxx" there must not be an extra
    # char on the next line that matches the last input char (e.g. "s" after "sls")
    local linecount
    linecount=$(echo "$out" | wc -l)
    local gotline
    gotline=$(echo "$out" | grep -n "^GOT:" | head -1)
    if [ -n "$gotline" ]; then
        local linenum
        linenum=$(echo "$gotline" | cut -d: -f1)
        local nextline
        nextline=$(echo "$out" | sed -n "$((linenum+1))p")
        # Trailing char bug: next line is a single char that was in our input
        if [ -n "$nextline" ] && [ ${#nextline} -eq 1 ]; then
            local lastchar
            lastchar=$(printf '%s' "$input" | tail -c 2 | head -c 1)
            if [ "$nextline" = "$lastchar" ]; then
                echo "FAIL: trailing char bug - '$lastchar' leaked to next line after GOT"
                echo "Full output:"
                echo "$out"
                return 1
            fi
        fi
    fi
    return 0
}

echo "GET test 1: single char A"
run_get "A" "A" || exit 1

echo "GET test 2: three chars ABC"
run_get "ABC" "ABC" || exit 1

echo "GET test 3: sls (trek command)"
run_get "sls" "SLS" || exit 1

echo "GET test 4: xxx (user's repro)"
run_get "xxx" "XXX" || exit 1

echo "GET test 5: single char then Enter"
run_get "X" "X" || exit 1

echo "GET test 6: max length SRS"
run_get "SRS" "SRS" || exit 1

echo "GET test 7: NAV"
run_get "NAV" "NAV" || exit 1

echo "GET test 8: WHILE K$<>Q loop (user pattern)"
# WHILE GET loop: printf "AB\nQ\n" - expect A, B, then DONE
out=$(printf 'AB\nQ\n' | $BASIC -petscii tests/get_while_test.bas 2>/dev/null)
if ! echo "$out" | grep -q "A"; then echo "FAIL: missing A"; echo "$out"; exit 1; fi
if ! echo "$out" | grep -q "B"; then echo "FAIL: missing B"; echo "$out"; exit 1; fi
if ! echo "$out" | grep -q "DONE"; then echo "FAIL: missing DONE"; echo "$out"; exit 1; fi

echo "GET test 9: via pty (simulates real terminal - catches echo/trailing bugs)"
# Use script -q -c to run with a pseudo-TTY; some environments don't have script
if command -v script >/dev/null 2>&1; then
    pty_out=$(script -q -c 'printf "sls\n" | '"$BASIC"' -petscii tests/get_input_loop.bas' /dev/null 2>/dev/null)
    if ! echo "$pty_out" | grep -q "^GOT:SLS"; then
        echo "FAIL: pty test - expected GOT:SLS"
        echo "$pty_out"
        exit 1
    fi
    # Critical: no trailing 's' on line after GOT:SLS
    lines_after_got=$(echo "$pty_out" | sed -n '/^GOT:SLS/,$p' | tail -n +2)
    for line in $lines_after_got; do
        if [ "${#line}" -eq 1 ] && [ "$line" = "s" ]; then
            echo "FAIL: pty test - trailing 's' bug detected"
            echo "$pty_out"
            exit 1
        fi
    done
    # Also test WHILE/GET loop with pty
    pty_while=$(script -q -c 'printf "AB\nQ\n" | '"$BASIC"' -petscii tests/get_while_test.bas' /dev/null 2>/dev/null)
    if ! echo "$pty_while" | grep -q "DONE"; then
        echo "FAIL: pty WHILE test - expected DONE"
        echo "$pty_while"
        exit 1
    fi
else
    echo "Skipping pty test (script not available)"
fi

echo "GET test 10: kbuffer.bas with piped input (each char on new line)"
# text.txt: abc, def, ghi, Q - each char printed on own line (Q exits without printing)
out=$( $BASIC -petscii tests/kbuffer.bas < tests/text.txt 2>/dev/null )
if ! echo "$out" | grep -q "^a$"; then echo "FAIL: kbuffer expected 'a' on own line"; echo "$out"; exit 1; fi
if ! echo "$out" | grep -q "^b$"; then echo "FAIL: kbuffer expected 'b' on own line"; exit 1; fi
if ! echo "$out" | grep -q "^i$"; then echo "FAIL: kbuffer expected 'i' on own line"; exit 1; fi

echo "All GET tests passed."
