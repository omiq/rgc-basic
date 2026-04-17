REM =========================================
REM   GFX STRESS TEST - shmup-shaped workload
REM   Many sprites + full-bitmap ops + FPS HUD
REM
REM   Canvas renderer: CPU alpha composite per
REM   sprite, scales with pixel count.
REM   Raylib renderer: GPU batches all draws,
REM   scales with sprite count not pixel count.
REM
REM   Run in either:
REM     ./basic-gfx examples/gfx_stress_test.bas
REM     IDE with ?renderer=raylib
REM =========================================

REM --- knobs ---
NSPRITES = 256
NSTARS   = 96

REM --- per-sprite arrays ---
DIM sx(NSPRITES), sy(NSPRITES)
DIM svx(NSPRITES), svy(NSPRITES)
DIM sslot(NSPRITES)

REM --- parallax star arrays ---
DIM stx(NSTARS), sty(NSTARS), stsp(NSTARS)

REM --- load one sprite, clone to many slots with tinted colour ---
LOADSPRITE 0, "chick.png"
FOR I = 0 TO NSPRITES - 1
  REM Hue spin around the ring
  PH = I * (360 / NSPRITES)
  R = INT(127 + 127 * SIN(PH * 0.01745))
  G = INT(127 + 127 * SIN((PH + 120) * 0.01745))
  B = INT(127 + 127 * SIN((PH + 240) * 0.01745))
  SPRITEMODIFY 0, 255, R, G, B
  SPRITECOPY 0, I + 1
  sslot(I) = I + 1
  sx(I) = RND(1) * 320 - 16
  sy(I) = RND(1) * 200 - 16
  svx(I) = (RND(1) - 0.5) * 3
  svy(I) = (RND(1) - 0.5) * 3
  SPRITEMODIFY sslot(I), 255, 255, 255, 255
NEXT

REM Restore slot 0 to white so we don't re-tint on every move
SPRITEMODIFY 0, 255, 255, 255, 255

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

  REM Sprite update + draw
  FOR I = 0 TO NSPRITES - 1
    sx(I) = sx(I) + svx(I)
    sy(I) = sy(I) + svy(I)
    IF sx(I) < -32 THEN sx(I) = 320
    IF sx(I) > 320 THEN sx(I) = -32
    IF sy(I) < -32 THEN sy(I) = 200
    IF sy(I) > 200 THEN sy(I) = -32
    DRAWSPRITE sslot(I), sx(I), sy(I), I
  NEXT

  REM FPS HUD — update once per second
  FRAMES = FRAMES + 1
  IF TI - T0 >= 60 THEN
    FPS = FRAMES
    FRAMES = 0
    T0 = TI
  ENDIF
  TEXTAT 0, 0, "FPS=" + STR$(FPS) + " SPR=" + STR$(NSPRITES)

  REM ESC to quit
  K$ = INKEY$()
  IF K$ = CHR$(27) THEN GOTO 9000
NEXT

9000 END
