' ============================================================
'  demo-scroller-palette.bas — Approach 1: SCREEN 3 copper bars
'                              + palette rotation
'
'  No assets. SCREEN 3 gives us a 256-entry palette with all draw
'  operations storing indices rather than RGB. We paint a 40-pixel-
'  tall horizontal band as a gradient using indices 16..31 (one
'  row per index), then DRAWTEXT the scroller in a non-rotating
'  index on top. Each frame PALETTEROTATE shifts indices 16..31,
'  so the bars appear to travel vertically behind the text while
'  the text itself stays a solid colour.
'
'  Why rotate the band, not the text pen? PALETTEROTATE cycles the
'  whole lookup table at once. If every text pixel used the same
'  index, rotation would change them all together — a flash, not a
'  scroll. Different-index-per-row is what produces motion, which
'  is why the raster-bar stripe has to be painted row-by-row.
'  Classic C64 demos did the same thing without needing a raster
'  interrupt.
'
'  Keys: Q = quit
' ============================================================

SCREEN 3
BACKGROUND 0
CLS

' --- build a 16-step gradient in palette slots 16..31 ---------
' Cyan -> bright blue -> hot pink. Tune the R/G/B curves below to
' match your mood; 16 entries is enough for a smooth band.
FOR I = 0 TO 15
  T = I / 15.0
  R = INT( 60 + T * 180 )
  G = INT(220 - T * 200 )
  B = INT(255 - T *  40 )
  PALETTESET 16 + I, R, G, B
NEXT

' --- text-band geometry ---------------------------------------
' y0 = top of the band; 16 rows tall (one per palette index in the
' rotating range). Sits around vertical centre so ascenders and
' descenders on the scale-2 chargen fit inside.
BAND_Y = 82
BAND_H = 16

MSG$ = "  * * *   WELCOME TO RGC-BASIC 2.0   * * *   MUSIC STREAMING, MOD / XM / S3M / IT, VU METERS, 9 BUNDLED TRACKS, SCREEN 4 HI-RES, --VERSION FLAG, AND MORE.   PRESS 1..9 TO LOAD + PLAY A TRACK.   THANKS FOR PLAYING.  "
LEN_MSG = LEN(MSG$)

SCROLL_X = 320

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  ' Paint the rotating gradient band. Each scanline uses a
  ' different palette index, so PALETTEROTATE makes the bars move
  ' vertically. Drawing the whole strip every frame is cheap —
  ' BAND_H * 320 LINE ops.
  FOR Y = 0 TO BAND_H - 1
    COLOR 16 + Y
    LINE 0, BAND_Y + Y TO 319, BAND_Y + Y
  NEXT

  ' Rotate the band. 1 = one row per frame; larger = faster.
  PALETTEROTATE 16, 31, 1

  ' Drop shadow (palette index 0 = pure black by default).
  COLOR 0
  DRAWTEXT SCROLL_X + 2, BAND_Y - 4 + 2, MSG$, 2

  ' Text pen: palette index 1 (C64 white), OUTSIDE the rotating
  ' range so it stays a solid colour while the band moves behind.
  COLOR 1
  DRAWTEXT SCROLL_X, BAND_Y - 4, MSG$, 2

  ' Scroll state. 16 px per glyph at scale 2 (8x8 chargen * 2).
  SCROLL_X = SCROLL_X - 2
  IF SCROLL_X < -(LEN_MSG * 16) THEN SCROLL_X = 320

  ' Legend.
  COLOR 1
  DRAWTEXT 4, 190, "Q = quit   approach 1: copper bars + palette rotation"

  VSYNC
LOOP

PALETTERESET
SCREEN 0
CLS
PRINT "Thanks for watching."
