' ============================================================
'  GFX INKEY$ DEMO - non-blocking keypress input
'  Run:  ./basic-gfx -petscii examples/gfx_inkey_demo.bas
'
'  INKEY$() returns a 1-char string when a key is waiting, or ""
'  if none. Letters may be upper or lower case - UCASE$ matches WASD.
'  Compare gfx_key_demo.bas which uses PEEK(56320+n) with n as the
'  uppercase-ASCII key code (W=87, A=65, S=83, D=68, ESC=27).
' ============================================================

SCR = 1024
COL = 55296
X   = 20
Y   = 12
C   = 1

BACKGROUND 6
COLOR 14
PRINT "{CLR}{WHITE}INKEY$ DEMO (WASD moves, ESC exits)"

' Draw initial @ at (X, Y)
POKE SCR + Y * 40 + X, 0
POKE COL + Y * 40 + X, C

DO
  K$ = INKEY$()
  IF K$ = "" THEN
    SLEEP 1
  ELSE
    K = ASC(UCASE$(K$))
    IF K = 27 THEN EXIT

    NX = X : NY = Y
    IF K = 87 THEN NY = Y - 1      ' W
    IF K = 83 THEN NY = Y + 1      ' S
    IF K = 65 THEN NX = X - 1      ' A
    IF K = 68 THEN NX = X + 1      ' D
    IF NX < 0  THEN NX = 0
    IF NX > 39 THEN NX = 39
    IF NY < 0  THEN NY = 0
    IF NY > 24 THEN NY = 24

    IF NX <> X OR NY <> Y THEN
      POKE SCR + Y * 40 + X, 32    ' erase
      X = NX : Y = NY
      POKE SCR + Y * 40 + X, 0     ' redraw
    END IF
  END IF
LOOP
