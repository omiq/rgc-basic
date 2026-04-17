REM =========================================
REM   GFX STRESS TEST - shmup-shaped workload
REM   Many sprite draws + FPS HUD
REM
REM   BASIC interpreter on WASM is ~50x slower
REM   than native, so use smaller NDRAWS for
REM   browser and crank NDRAWS for desktop.
REM =========================================

REM --- knobs (tune for target) ---
NHUES    = 16
NDRAWS   = 120

REM --- per-draw state arrays ---
DIM dx(NDRAWS), dy(NDRAWS)
DIM dvx(NDRAWS), dvy(NDRAWS)
DIM dslot(NDRAWS)

REM --- text-mode background keeps FPS HUD visible in 40x25 cells ---
SCREEN 0
BACKGROUND 0
PRINT CHR$(147)
COLOR 7

REM --- load base sprite, clone to NHUES tinted slots ---
LOADSPRITE 0, "chick.png"
FOR I = 0 TO NHUES - 1
  PH = I * (360 / NHUES)
  R = INT(127 + 127 * SIN(PH * 0.01745))
  G = INT(127 + 127 * SIN((PH + 120) * 0.01745))
  B = INT(127 + 127 * SIN((PH + 240) * 0.01745))
  SPRITEMODIFY 0, 255, R, G, B
  SPRITECOPY 0, I + 1
NEXT
REM Restore base slot white
SPRITEMODIFY 0, 255, 255, 255, 255

REM --- init NDRAWS sprites ---
FOR I = 0 TO NDRAWS - 1
  dslot(I) = 1 + (I MOD NHUES)
  dx(I) = RND(1) * 320 - 16
  dy(I) = RND(1) * 200 - 16
  dvx(I) = (RND(1) - 0.5) * 4
  dvy(I) = (RND(1) - 0.5) * 4
NEXT

REM --- main loop: sprites + FPS HUD in text row 0 ---
T0 = TI
FRAMES = 0
FPS = 0
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
  IF TI - T0 >= 60 THEN
    FPS = FRAMES
    FRAMES = 0
    T0 = TI
  ENDIF
  TEXTAT 0, 0, "FPS=" + STR$(FPS) + "  DRAWS=" + STR$(NDRAWS) + "     "

  K$ = INKEY$()
  IF K$ = CHR$(27) THEN GOTO Done
NEXT

Done:
END
