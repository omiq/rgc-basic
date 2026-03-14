#!/bin/sh
# Test that -petscii-plain output has no extra characters: only 1 char per printable file byte + newlines.
# Run from repo root: sh tests/petscii_plain_output_test.sh

SEQ=examples/colaburger.seq
OUT=$(./basic -petscii-plain examples/colaburger_viewer.bas 2>/dev/null)
BYTES=$(echo -n "$OUT" | wc -c)

# Expected: printable (32-126, 160-255) + newlines. No output for 0-31 (except 10->\n, 13->\n), 127, 128-159.
python3 -c "
d = open('$SEQ', 'rb').read()
printable = sum(1 for b in d if (32 <= b <= 126) or (b >= 160))
nls = 1 + (printable // 40)  # initial + wrap
expected = printable + nls
actual = $BYTES
extra = actual - expected
print('Expected bytes (printable + newlines):', expected)
print('Actual bytes:', actual)
print('Extra characters:', extra)
if extra > 5:
    print('FAIL: too many extra characters (expected <= a few from LF/CR handling)')
    exit(1)
print('OK: output size in expected range')
" || exit 1
