' ============================================================
'  gfx_scrollzone_demo — SCROLL ZONE + SCROLL LINE showcase
'
'  Three simultaneous effects running over one still image:
'    1. SCROLL ZONE 1 at the top strip  — continuous left scroll
'       (classic demo "message bar" feel, rest of screen static).
'    2. SCROLL LINE per row across the middle band — sine-wave
'       water ripple, each raster line shifted by a different dx.
'    3. SCROLL ZONE 2 at the bottom     — opposite-direction
'       scroll, showcasing independent zone offsets.
'
'  All three layers share ONE painted bitmap; the engine applies
'  per-frame per-row offsets at composite time. No IMAGE COPY
'  bookkeeping, no per-pixel BASIC loops.
'
'  Keys: Q = quit,  SPACE = pause/resume the animation
' ============================================================

SCREEN 2
BACKGROUNDRGB 0, 0, 0
CLS

' --- paint a reference image once ----------------------------
' Fill every row with a vertical gradient, then overlay 16 thin
' vertical stripes across the whole 320x200 plane. Single-row
' paints (200 LINE calls) and 16 FILLRECTs = instant; per-pixel
' loops (64 000 calls) would stall the first few seconds and
' leave most of the image unpainted if you paused early.
FOR Y = 0 TO 199
  R = (Y * 3)       MOD 256
  G = (Y * 5 + 40)  MOD 256
  B = (Y * 7 + 80)  MOD 256
  COLORRGB R, G, B
  LINE 0, Y TO 319, Y
NEXT

' Vertical stripes across the full height — without these a pure
' row-gradient looks static under horizontal scroll (each row is
' one colour, shifting it sideways changes nothing visible).
' 16 stripes × 20 px spacing × 4 px wide gives unmistakable
' horizontal motion when the zones pan.
FOR I = 0 TO 15
  SX = I * 20
  R = (I * 17) MOD 256
  G = (I * 29) MOD 256
  B = (I * 53) MOD 256
  COLORRGB R, G, B
  FILLRECT SX, 0 TO SX + 3, 199
NEXT

' Labels — drawn ON TOP of the stripes/gradient. The zones beneath
' still carry their full pattern, so the scroll + ripple effects
' are visible THROUGH the labelled rows. Bright yellow text shows
' against any background colour, drop-shadow for the rows where
' the gradient gets bright.
COLORRGB 0, 0, 0
DRAWTEXT 4 + 2, 12 + 2,  "ZONE 1 SCROLLS LEFT", 2
DRAWTEXT 4 + 2, 92 + 2,  "LINE WARP (SINE RIPPLE)", 2
DRAWTEXT 4 + 2, 172 + 2, "ZONE 2 SCROLLS RIGHT", 2
COLORRGB 255, 255, 180
DRAWTEXT 4, 12,  "ZONE 1 SCROLLS LEFT", 2
DRAWTEXT 4, 92,  "LINE WARP (SINE RIPPLE)", 2
DRAWTEXT 4, 172, "ZONE 2 SCROLLS RIGHT", 2

' --- declare the two scroll zones ----------------------------
' Zone ids 1..7; slot 0 reserved for "no zone". y + h pick the
' affected rows. SCROLL ZONE preserves its running dx when resized
' so we can re-declare each frame if we like; here we only declare
' once at startup.
SCROLL ZONE 1, 0, 40
SCROLL ZONE 2, 160, 40

T = 0
PAUSED = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN
    IF PAUSED = 0 THEN PAUSED = 1 ELSE PAUSED = 0
  END IF

  IF PAUSED = 0 THEN
    ' Advance the two zone offsets. Offsets are additive, so we
    ' pass a per-frame delta (not an absolute value). Wrap is
    ' handled by the compositor — modular across rgba_w.
    SCROLL ZONE 1, -2     ' 2 pixels left per frame
    SCROLL ZONE 2, +3     ' 3 pixels right per frame

    ' Per-scanline sine ripple across rows 80..119. Wavelength
    ' ~25 rows (0.25 rad/row), phase advances with T so the wave
    ' travels vertically. Amplitude 8 px.
    FOR Y = 80 TO 119
      SCROLL LINE Y, INT( SIN((Y * 0.25) + T) * 8 )
    NEXT

    T = T + 0.10
  END IF

  VSYNC
LOOP

' Tidy up: wipe every zone + per-line offset so the next program
' run doesn't inherit our scroll state. SCROLL RESET covers both.
SCROLL RESET
SCREEN 0
CLS
PRINT "Thanks for watching."
