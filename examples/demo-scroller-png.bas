' ============================================================
'  demo-scroller-png.bas — Approach 3: pre-rendered PNG strip
'                          with transparency
'
'  Simplest authoring path. The whole scroller message is baked
'  as one long PNG with gradient fills, outlines, shadows, and
'  any other effects the artist wants. At runtime we just scroll
'  it across the screen like a giant sprite.
'
'  Asset spec (see header comment at top of file for full detail):
'    scroller_strip.png
'      2400 x 40 px, RGBA.
'      Transparent background (alpha = 0 outside the text).
'      Baked colour / gradient / outline / shadow — whatever.
'      Aseprite: New file 2400x40, Color mode: RGB(A), Background:
'      transparent, type your text (scale as needed), apply any
'      effects you like, export PNG (default settings).
'
'  Trade-off: message content is hard-coded in the asset — change
'  text = redraw the PNG. Upside: richest visuals for the lowest
'  code complexity. Perfect for announcement banners that don't
'  change often.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 8, 8, 24
CLS

' LOADSPRITE path is a literal quoted string so the IDE's asset
' auto-preload regex sees it and fetches the PNG into MEMFS
' before the program runs.
LOADSPRITE 0, "scroller_strip.png"

STRIP_W = SPRITEW(0)
STRIP_H = SPRITEH(0)
IF STRIP_W = 0 THEN
  COLORRGB 255, 100, 100
  DRAWTEXT 8, 90, "scroller_strip.png not found"
  DRAWTEXT 8, 106, "(draw a 2400x40 RGBA PNG in Aseprite)"
  SLEEP 3000
  END
END IF

' Scroll state. Start with the strip just off the right edge so
' the text reads in from the side. T advances each frame and
' drives the sine wave for the vertical bounce; scale it to
' control the wobble speed (bigger = faster oscillation).
SX  = -320
T   = 0.0
BASE_Y = 80                ' centre line of the scroller
AMP    = 24                ' pixels of vertical swing (up + down)
FREQ   = 0.05              ' radians per frame — ~0.05 = gentle

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  ' Horizontal scroll + sine bounce. DRAWSPRITE positions the
  ' whole strip each frame; the engine clips to the framebuffer
  ' so negative X reveals later pixels of the strip. The strip
  ' moves as one rigid body — for a "per-letter wave" effect see
  ' demo-scroller-sprites.bas (each character stamped on its own
  ' sine phase).
  YY = BASE_Y + INT( SIN(T) * AMP )
  DRAWSPRITE 0, -SX, YY

  ' Wrap: once the strip has fully exited the left edge, restart
  ' from the right. Add a ~320 px gap between loops so the start
  ' is visibly distinct from the end.
  IF SX > STRIP_W THEN SX = -320

  SX = SX + 2
  T  = T  + FREQ

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 3: PNG strip + sine bounce"

  VSYNC
LOOP

UNLOADSPRITE 0
SCREEN 0
CLS
PRINT "Thanks for watching."
