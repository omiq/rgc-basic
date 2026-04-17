REM =========================================
REM   GFX STRESS TEST - shmup-shaped workload
REM   Runs for BENCH_JIFFIES ticks, then prints
REM   final FPS. No per-frame HUD — isolates
REM   raw interpreter + render throughput.
REM
REM   BENCH_JIFFIES is in 1/60 second units.
REM   600 = 10 seconds at 60Hz.
REM =========================================

NHUES          = 16
NDRAWS         = 120
BENCH_JIFFIES  = 600

DIM dx(NDRAWS), dy(NDRAWS)
DIM dvx(NDRAWS), dvy(NDRAWS)
DIM dslot(NDRAWS)

SCREEN 0
BACKGROUND 0
PRINT CHR$(147)
COLOR 7
PRINT "Stress test: "; NDRAWS; " sprites for 10s..."

LOADSPRITE 0, "chick.png"
FOR I = 0 TO NHUES - 1
  PH = I * (360 / NHUES)
  R = INT(127 + 127 * SIN(PH * 0.01745))
  G = INT(127 + 127 * SIN((PH + 120) * 0.01745))
  B = INT(127 + 127 * SIN((PH + 240) * 0.01745))
  SPRITEMODIFY 0, 255, R, G, B
  SPRITECOPY 0, I + 1
NEXT
SPRITEMODIFY 0, 255, 255, 255, 255

FOR I = 0 TO NDRAWS - 1
  dslot(I) = 1 + (I MOD NHUES)
  dx(I) = RND(1) * 320 - 16
  dy(I) = RND(1) * 200 - 16
  dvx(I) = (RND(1) - 0.5) * 4
  dvy(I) = (RND(1) - 0.5) * 4
NEXT

T0 = TI
FRAMES = 0

REM Fixed-duration hot loop — no TEXTAT inside
FOR L = 0 TO 1 STEP 0
  FOR I = 0 TO NDRAWS - 1
    dx(I) = dx(I) + dvx(I)
    dy(I) = dy(I) + dvy(I)
    IF dx(I) < -32 THEN dx(I) = 320
    IF dx(I) > 320 THEN dx(I) = -32
    IF dy(I) < -32 THEN dy(I) = 200
    IF dy(I) > 200 THEN dy(I) = -32
    DRAWSPRITE dslot(I), dx(I), dy(I), I
  NEXT
  FRAMES = FRAMES + 1
  IF TI - T0 >= BENCH_JIFFIES THEN GOTO Report
  K$ = INKEY$()
  IF K$ = CHR$(27) THEN GOTO Report
NEXT

Report:
ELAPSED_S = (TI - T0) / 60
FPS = FRAMES / ELAPSED_S
PRINT
PRINT "-------------------------"
PRINT "FRAMES : "; FRAMES
PRINT "SECONDS: "; ELAPSED_S
PRINT "FPS    : "; FPS
PRINT "DRAWS/S: "; FRAMES * NDRAWS / ELAPSED_S
PRINT "-------------------------"
PRINT "Press any key."
FOR W = 0 TO 1 STEP 0
  K$ = INKEY$()
  IF K$ <> "" THEN GOTO Done
NEXT

Done:
END
