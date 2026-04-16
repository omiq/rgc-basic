REM chicks_timer.bas
REM 64 chicks loaded once via SPRITECOPY, animated by a TIMER:
REM   - each chick drifts in a random direction, wrapping at screen edges
REM   - colour cycles through hue shifts via SPRITEMODULATE r,g,b
REM   - scale pulses up and down
REM Main loop does nothing — all motion is driven by the timer.

REM --- constants ---
NCHICKS = 63

REM --- per-chick state arrays ---
DIM cx(NCHICKS)    REM x position
DIM cy(NCHICKS)    REM y position
DIM cvx(NCHICKS)   REM x velocity
DIM cvy(NCHICKS)   REM y velocity
DIM cph(NCHICKS)   REM colour phase (0..359)
DIM csc(NCHICKS)   REM scale phase  (0..359)

REM --- load and clone ---
LOADSPRITE 0, "chick.png"
FOR S = 1 TO NCHICKS
  SPRITECOPY 0, S
NEXT S

REM --- randomise starting state ---
FOR S = 0 TO NCHICKS
  cx(S) = RND(1) * 320
  cy(S) = RND(1) * 200
  cvx(S) = (RND(1) - 0.5) * 4
  cvy(S) = (RND(1) - 0.5) * 4
  cph(S) = INT(RND(1) * 360)
  csc(S) = INT(RND(1) * 360)
  DRAWSPRITE S, cx(S), cy(S)
NEXT S

REM --- timer handler: move + modulate all chicks ---
FUNCTION UpdateChicks()
  FOR S = 0 TO NCHICKS
    REM move
    cx(S) = cx(S) + cvx(S)
    cy(S) = cy(S) + cvy(S)
    REM wrap
    IF cx(S) < -32  THEN cx(S) = 320
    IF cx(S) > 320  THEN cx(S) = -32
    IF cy(S) < -32  THEN cy(S) = 200
    IF cy(S) > 200  THEN cy(S) = -32
    REM advance phases
    cph(S) = (cph(S) + 3) MOD 360
    csc(S) = (csc(S) + 2) MOD 360
    REM colour: rotate hue via r/g/b sine waves 120 degrees apart
    r = INT(127 + 127 * SIN(cph(S) * 0.01745))
    g = INT(127 + 127 * SIN((cph(S) + 120) * 0.01745))
    b = INT(127 + 127 * SIN((cph(S) + 240) * 0.01745))
    REM scale: pulse between 0.5 and 1.5
    sc = 0.5 + SIN(csc(S) * 0.01745)
    SPRITEMODULATE S, 255, r, g, b, sc, sc
    DRAWSPRITE S, cx(S), cy(S), S
  NEXT S
END FUNCTION

TIMER 1, 50, UpdateChicks

DO
  SLEEP 1
LOOP
