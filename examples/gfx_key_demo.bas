' ============================================================
'  GFX KEY DEMO - poll host keyboard via PEEK and move a character
'  Run:  ./basic-gfx examples/gfx_key_demo.bas
'
'  PEEK(GFX_KEY_BASE + n) reads key_state[n]: 1 while key is held.
'  GFX_KEY_BASE = 56320 ($DC00). For letters, n is the uppercase
'  ASCII code (W=87, A=65, S=83, D=68, ESC=27). This matches Raylib
'  / basic-gfx and the canvas wasmGfxKeyIndex().
' ============================================================

SCR = 1024
COL = 55296
X   = 20
Y   = 12
C   = 1

KW  = 87 : KA = 65 : KS = 83 : KD = 68 : KESC = 27

' Clear screen to spaces, set colour to light blue (14)
FOR I = 0 TO 999
  POKE SCR + I, 32
  POKE COL + I, 14
NEXT I

' Draw initial @
POKE SCR + Y * 40 + X, 0
POKE COL + Y * 40 + X, C

DO
  IF PEEK(56320 + KESC) <> 0 THEN EXIT

  NX = X : NY = Y
  IF PEEK(56320 + KW) <> 0 THEN NY = Y - 1
  IF PEEK(56320 + KS) <> 0 THEN NY = Y + 1
  IF PEEK(56320 + KA) <> 0 THEN NX = X - 1
  IF PEEK(56320 + KD) <> 0 THEN NX = X + 1
  IF NX < 0  THEN NX = 0
  IF NX > 39 THEN NX = 39
  IF NY < 0  THEN NY = 0
  IF NY > 24 THEN NY = 24

  IF NX <> X OR NY <> Y THEN
    POKE SCR + Y * 40 + X, 32         ' erase old
    X = NX : Y = NY
    POKE SCR + Y * 40 + X, 0          ' draw new
  END IF

  SLEEP 1
LOOP
