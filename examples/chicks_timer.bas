REM chicks_timer.bas
REM 64 chicks, each with unique hue + random size set at startup.
REM Colour baked via SPRITEMODIFY+SPRITECOPY, size set via SPRITEMODIFY scale.
REM No per-frame modulate — all sprites go via Canvas2D fast path.
REM Best practice: bake colour with SPRITEMODIFY before SPRITECOPY for best performance.

REM --- constants ---
NCHICKS = 63

REM --- per-chick state arrays ---
DIM cx(NCHICKS)    REM x position
DIM cy(NCHICKS)    REM y position
DIM cvx(NCHICKS)   REM x velocity
DIM cvy(NCHICKS)   REM y velocity

REM --- load and clone with baked hue + random scale ---
LOADSPRITE 0, "chick.png"
FOR S = 0 TO NCHICKS
  REM spread hue evenly across 360 degrees, bake into each slot
  ph = S * (360 / (NCHICKS + 1))
  r = INT(127 + 127 * SIN(ph * 0.01745))
  g = INT(127 + 127 * SIN((ph + 120) * 0.01745))
  b = INT(127 + 127 * SIN((ph + 240) * 0.01745))
  SPRITEMODIFY 0, 255, r, g, b
  SPRITECOPY 0, S
  REM random scale 0.5 to 1.5, set after copy (not baked, used at draw time)
  sc = 0.5 + RND(1)
  SPRITEMODIFY S, 255, 255, 255, 255, sc
NEXT S

REM restore slot 0 to default
SPRITEMODIFY 0, 255, 255, 255, 255

REM --- randomise starting positions and velocities ---
FOR S = 0 TO NCHICKS
  cx(S) = RND(1) * 320
  cy(S) = RND(1) * 200
  cvx(S) = (RND(1) - 0.5) * 4
  cvy(S) = (RND(1) - 0.5) * 4
  DRAWSPRITE S, cx(S), cy(S), S
NEXT S

REM --- timer handler: move all chicks ---
FUNCTION UpdateChicks()
  FOR S = 0 TO NCHICKS
    cx(S) = cx(S) + cvx(S)
    cy(S) = cy(S) + cvy(S)
    IF cx(S) < -32  THEN cx(S) = 320
    IF cx(S) > 320  THEN cx(S) = -32
    IF cy(S) < -32  THEN cy(S) = 200
    IF cy(S) > 200  THEN cy(S) = -32
    DRAWSPRITE S, cx(S), cy(S), S
  NEXT S
END FUNCTION

TIMER 1, 50, UpdateChicks

DO
  SLEEP 1
LOOP
