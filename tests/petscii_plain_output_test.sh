#!/bin/sh
# Test that -petscii-plain output has no extra characters: only 1 char per printable file byte + newlines.
# Run from repo root: sh tests/petscii_plain_output_test.sh

SEQ=examples/colaburger.seq
OUT=$(./basic -petscii-plain examples/colaburger_viewer.bas 2>/dev/null)
CHARS=$(echo -n "$OUT" | wc -m)

# Expected: one Unicode character per printable PETSCII byte (32-126, 160-255) + newlines.
# Use wc -m (character count) not wc -c (byte count) because PETSCII graphics map to
# multi-byte UTF-8 (box-drawing, block elements, card suits, etc.).
python3 -c "
d = open('$SEQ', 'rb').read()
printable = sum(1 for b in d if (32 <= b <= 126) or (b >= 160))
nls = 1 + (printable // 40)  # initial + wrap
expected = printable + nls
actual = $CHARS
extra = actual - expected
print('Expected chars (printable + newlines):', expected)
print('Actual chars:', actual)
print('Extra characters:', extra)
if abs(extra) > 5:
    print('FAIL: too many extra characters (expected <= a few from LF/CR handling)')
    exit(1)
print('OK: output size in expected range')
" || exit 1
