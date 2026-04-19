' ============================================================
'  GFX JIFFY CLOCK DEMO - smooth player + sine-wave enemy
'  Run:  ./basic-gfx -petscii examples/gfx_jiffy_game_demo.bas
'  Canvas WASM: TI is wall-clock jiffies; loop on SLEEP 1 (no TI bucket wait).
'  Controls: hold W/A/S/D to move, ESC to quit.
' ============================================================

SCR     = 1024
COL     = 55296
W       = 40
H       = 25
KEYBASE = 56320

BACKGROUND 6
COLOR 14
PRINT "{CLR}{WHITE}JIFFY CLOCK DEMO  (WASD MOVE, ESC QUITS)"
PRINT "{CYAN}PLAYER IS '@'   ENEMY IS 'X' (SINE WAVE)"

' Player / enemy state
PX = 5  : PY = 12 : PCOL = 1
EX0 = 20 : EY = 12 : ECOL = 2
AMP    = 4
PERIOD = 180
ECH    = 160
EX     = EX0
LXE    = EX

' Initial draw
POKE SCR + PY * W + PX, 0
POKE COL + PY * W + PX, PCOL
POKE SCR + EY * W + EX, ECH
POKE COL + EY * W + EX, ECOL

DO
  IF PEEK(KEYBASE + 27) <> 0 THEN EXIT

  T = TI
  SLEEP 1

  ' Enemy: phase from jiffy clock TI (no MOD operator, so subtract the quotient)
  Q  = INT(T / PERIOD)
  PH = T - Q * PERIOD
  EX = EX0 + INT(AMP * SIN(6.28318 * (PH / PERIOD)))
  IF EX < 0  THEN EX = 0
  IF EX > 39 THEN EX = 39

  ' Player: poll keys every frame
  NX = PX : NY = PY
  IF PEEK(KEYBASE + 87) <> 0 THEN NY = PY - 1
  IF PEEK(KEYBASE + 83) <> 0 THEN NY = PY + 1
  IF PEEK(KEYBASE + 65) <> 0 THEN NX = PX - 1
  IF PEEK(KEYBASE + 68) <> 0 THEN NX = PX + 1
  IF NX < 0  THEN NX = 0
  IF NX > 39 THEN NX = 39
  IF NY < 2  THEN NY = 2
  IF NY > 24 THEN NY = 24

  IF NX <> PX OR NY <> PY THEN
    POKE SCR + PY * W + PX, 32         ' erase old
    PX = NX : PY = NY
  END IF
  POKE SCR + PY * W + PX, 0            ' redraw player
  POKE COL + PY * W + PX, PCOL

  POKE SCR + EY * W + EX, ECH          ' redraw enemy
  POKE COL + EY * W + EX, ECOL
  IF EX <> LXE THEN POKE SCR + EY * W + LXE, 32

  ' HUD under the banner (rows 2-3)
  TEXTAT 0, 2, "TI$=" + TI$ + "  "
  TEXTAT 0, 3, "TI=" + STR$(TI) + "    "

  LXE = EX
LOOP
