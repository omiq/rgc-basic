' colaburger_viewer - display raw PETSCII file wrapped at 40 columns.
' Run:  basic -petscii-plain examples/colaburger_viewer.bas
' (-petscii-plain gives strict 1-char/column alignment; no ANSI colour.)

PRINT CHR$(147)

OPEN 1, 1, 0, "examples/colaburger.seq"

L = 0
DO
  GET#1, C$
  IF ST <> 0 THEN EXIT
  IF LEN(C$) = 0 THEN
    ' skip empty reads
  ELSE
    A = ASC(C$)
    IF A = 13 THEN
      PRINT
      L = 0
    ELSE
      PRINT CHR$(A);
      IF A = 20 THEN L = L - 1
      ' Advance column counter for printable bytes only.
      ' Control-code ranges: <32, 127..159 treated as zero-width.
      IF A >= 32 AND (A < 127 OR A >= 160) THEN
        L = L + 1
        IF L >= 40 THEN
          PRINT CHR$(13);
          L = 0
        END IF
      END IF
    END IF
  END IF
LOOP

CLOSE 1
PRINT

' Wait for any key before exiting
DO
  GET K$
  IF K$ <> "" THEN EXIT
  SLEEP 1
LOOP
