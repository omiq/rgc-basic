REM =========================================
REM   GFX STRESS TEST - shmup-shaped workload
REM   Many draws + full-bitmap ops + FPS HUD
REM
REM   Canvas renderer: CPU alpha composite per
REM   sprite, scales with pixel count.
REM   Raylib renderer: GPU batches all draws,
REM   scales with draw count not pixel count.
REM
REM   Run in either:
REM     ./basic-gfx examples/gfx_stress_test.bas
REM     IDE with ?renderer=raylib
REM
REM   Note: gfx engine has 64 sprite slots max,
REM   so we clone chick.png into NHUES tinted
REM   slots and draw each many times.
REM =========================================

REM --- knobs ---
NHUES    = 16
NDRAWS   = 200
NSTARS   = 96

REM --- per-draw state arrays (one entry per visible sprite) ---
DIM dx(NDRAWS), dy(NDRAWS)
DIM dvx(NDRAWS), dvy(NDRAWS)
DIM dslot(NDRAWS)

REM --- parallax star arrays ---
DIM stx(NSTARS), sty(NSTARS), stsp(NSTARS)

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
REM Restore base slot
SPRITEMODIFY 0, 255, 255, 255, 255

REM --- init NDRAWS sprites, each references one of the NHUES slots ---
FOR I = 0 TO NDRAWS - 1
  dslot(I) = 1 + (I MOD NHUES)
  dx(I) = RND(1) * 320 - 16
  dy(I) = RND(1) * 200 - 16
  dvx(I) = (RND(1) - 0.5) * 3
  dvy(I) = (RND(1) - 0.5) * 3
NEXT

REM --- init stars for bitmap-layer parallax ---
FOR I = 0 TO NSTARS - 1
  stx(I) = RND(1) * 320
  sty(I) = RND(1) * 200
  stsp(I) = 1 + INT(RND(1) * 3)
NEXT

REM --- bitmap mode for the star field ---
SCREEN 1
BACKGROUND 0
COLOR 1
BITMAPCLEAR

REM --- main loop: stars + sprites + FPS HUD ---
T0 = TI
FRAMES = 0
FPS = 0
FOR L = 0 TO 1 STEP 0

  REM Star field: clear + redraw all pixels (heaviest bitmap op)
  BITMAPCLEAR
  FOR I = 0 TO NSTARS - 1
    stx(I) = stx(I) - stsp(I)
    IF stx(I) < 0 THEN stx(I) = 320
    PSET stx(I), sty(I), 1
  NEXT

  REM Sprite update + draw — NDRAWS draw calls per frame
  FOR I = 0 TO NDRAWS - 1
    dx(I) = dx(I) + dvx(I)
    dy(I) = dy(I) + dvy(I)
    IF dx(I) < -32 THEN dx(I) = 320
    IF dx(I) > 320 THEN dx(I) = -32
    IF dy(I) < -32 THEN dy(I) = 200
    IF dy(I) > 200 THEN dy(I) = -32
    DRAWSPRITE dslot(I), dx(I), dy(I), I
  NEXT

  REM FPS HUD — update once per second
  FRAMES = FRAMES + 1
  IF TI - T0 >= 60 THEN
    FPS = FRAMES
    FRAMES = 0
    T0 = TI
  ENDIF
  TEXTAT 0, 0, "FPS=" + STR$(FPS) + " DRAWS=" + STR$(NDRAWS)

  REM ESC to quit
  K$ = INKEY$()
  IF K$ = CHR$(27) THEN GOTO Done
NEXT

Done:
END
