' ============================================================
'  gfx_imagedraw_demo — IMAGE DRAW slot retarget showcase
'
'  IMAGE DRAW redirects every RGBA primitive (LINE, FILLRECT,
'  CIRCLE, DRAWTEXT, PSET, POLYGON) from the live screen into
'  an off-screen IMAGE CREATE surface. `IMAGE DRAW 0` restores
'  the live framebuffer.
'
'  This demo uses it to pre-compose a 512x64 gradient-filled
'  text strip once at startup, then scrolls it left each frame
'  via IMAGE BLEND. Classic demoscene pattern that was awkward
'  before IMAGE DRAW: the glyph gradient is baked INTO the
'  strip's pixels, which a single-pen DRAWTEXT can't produce.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 10, 10, 28
CLS
DOUBLEBUFFER ON

STRIP_W = 1024
STRIP_H = 64

' --- allocate the off-screen canvas --------------------------
IMAGE CREATE 1, STRIP_W, STRIP_H

' --- retarget primitives to the canvas -----------------------
' Every LINE / FILLRECT / DRAWTEXT below writes into slot 1
' instead of the live screen. rgba_w / rgba_h are swapped to
' the slot's 512x64 dimensions for the duration.
IMAGE DRAW 1

' Gradient fill — one LINE per row. Sky blue at top fading to
' deep purple at bottom.
FOR Y = 0 TO STRIP_H - 1
  T = Y / (STRIP_H - 1.0)
  R = INT( 40 + T * 180 )
  G = INT(160 - T * 120 )
  B = INT(255 - T *  60 )
  COLORRGB R, G, B
  LINE 0, Y TO STRIP_W - 1, Y
NEXT

' Drop shadow + main text — stamped INTO the gradient, so the
' text cells inherit the gradient colour row-by-row. A single-
' pen DRAWTEXT can't do this on its own; that's exactly the
' use case IMAGE DRAW was added for.
COLORRGB 0, 0, 0
DRAWTEXT 14 + 2, 18 + 2, "RGC-BASIC 2.1 SCROLL + IMAGE DRAW", 2
COLORRGB 255, 255, 255
DRAWTEXT 14, 18, "RGC-BASIC 2.1 SCROLL + IMAGE DRAW", 2

' --- restore the live framebuffer ----------------------------
IMAGE DRAW 0

SX = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  ' Blit a 320x64 window of the pre-composed strip onto the live
  ' screen at y=80. IMAGE BLEND routes dst=0 to the visible
  ' framebuffer (IMAGE COPY only goes slot->slot).
  IMAGE BLEND 1, SX, 0, 320, STRIP_H TO 0, 0, 80
  ' Wrap: tile the leftover from the strip start so there's no
  ' visible seam when SX + 320 runs past the strip width.
  TAIL = (SX + 320) - STRIP_W
  IF TAIL > 0 THEN
    IMAGE BLEND 1, 0, 0, TAIL, STRIP_H TO 0, 320 - TAIL, 80
  END IF

  SX = SX + 2
  IF SX >= STRIP_W THEN SX = 0

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 180, "Q = quit    IMAGE DRAW baked the gradient INTO the text"

  VSYNC
LOOP

DOUBLEBUFFER OFF
IMAGE FREE 1
SCREEN 0
CLS
PRINT "Thanks for watching."
