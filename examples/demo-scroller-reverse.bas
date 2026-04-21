' ============================================================
'  demo-scroller-reverse.bas — Approach 5: REVERSE-VIDEO gradient
'                              scroller (PRINT "{REVERSE ON}"
'                              style, but with a gradient cell)
'
'  No assets. Paints a gradient band, then DRAWTEXTs the scroller
'  in BLACK on top. DRAWTEXT on SCREEN 2 RGBA replaces glyph
'  pixels with the pen colour and leaves non-glyph pixels alone,
'  so black glyphs over a gradient = letter-shaped holes punched
'  through the gradient. Classic Commodore reverse-video look,
'  but the "background" of the cell is a live RGB gradient
'  instead of a flat colour.
'
'  Why this and not "gradient-through-glyphs" (= glyphs coloured
'  with the gradient on black background)? That direction needs
'  per-row/per-pixel glyph tinting. DRAWTEXT has one pen per call,
'  so we can't paint different colours inside different rows of
'  a single glyph. Reverse-video flips the relationship: the
'  gradient fills the cell rect and the glyph shape cuts through
'  it. Same "shaped gradient" feel, achievable today.
'
'  For true "glyph-shaped gradient on black" see:
'    * demo-scroller-png.bas — bake it in Aseprite.
'    * demo-scroller-sprites.bas — per-char sheet, SPRITEMODULATE.
'    * future IMAGE DRAW slot (2.1, tracked in to-do.md).
'
'  How it works:
'    * SCREEN 2 (RGBA) + DOUBLEBUFFER ON for clean commits.
'    * Each frame: FILLRECT clears the strip; 40 LINE ops paint
'      the gradient; COLORRGB 0,0,0 + DRAWTEXT punches the text
'      through the gradient as black letter-shaped holes.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 8, 8, 24
CLS

BAND_Y = 40
BAND_H = 40

MSG$ = "REVERSE-VIDEO GRADIENT SCROLLER - EACH CELL HAS ITS OWN GRADIENT, DRAWTEXT PUNCHES THE LETTER OUT IN BLACK. WELCOME TO RGC-BASIC 2.0. "
LEN_MSG = LEN(MSG$)
' Start with the first letter just on-screen instead of 320 px
' off-screen so paused screenshots show text knockouts straight
' away. Set to 320 if you'd rather the message read in from the
' right edge.
SCROLL_X = 16

' At scale 2, the chargen cell is 16 px wide x 16 px tall. Text
' sits vertically centred in the band via the +12 offset below.
CELL_W = 16
CELL_H = 16
TEXT_Y = BAND_Y + 12

' --- bake the 16x16 gradient cell once into IMAGE slot 1 ------
' Painting 16 LINE ops per cell per frame scales linearly with the
' number of visible cells — fine native, marginal under ASYNCIFY
' in the browser. Cache the gradient into an off-screen RGBA slot
' and blit it per cell each frame instead: one IMAGE COPY = a few
' hundred RGBA memcpys, orders of magnitude cheaper than 16 LINEs
' of interpreter overhead.
'
' IMPORTANT: do this BEFORE DOUBLEBUFFER ON. IMAGE GRAB reads from
' the displayed plane; under DOUBLEBUFFER, primitive writes go to
' the back buffer that isn't shown until the next VSYNC, so a grab
' right after the bake LINE ops would capture a still-empty frame.
IMAGE CREATE 1, CELL_W, CELL_H
FOR Y = 0 TO CELL_H - 1
  T = Y / (CELL_H - 1.0)
  R = INT( 60 + T * 160 )
  G = INT(120 - T *  80 )
  B = INT(255 - T *  60 )
  COLORRGB R, G, B
  LINE 0, TEXT_Y + Y TO CELL_W - 1, TEXT_Y + Y
NEXT
' IMAGE GRAB on the WASM build reads from the last-composited
' render target (browser is single-threaded, so there's no render
' worker to wait on). The paint above hasn't been presented yet —
' VSYNC forces one composite pass so the gradient pixels land in
' the grab source before we copy them into slot 1.
VSYNC
IMAGE GRAB 1, 0, TEXT_Y, CELL_W, CELL_H

' Clear the scratch paint we just used for the bake, THEN flip on
' double-buffering for the main loop.
COLORRGB 8, 8, 24
CLS
DOUBLEBUFFER ON

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Clear the strip each frame so old cells don't bleed into the
  ' next scroll step. Pure black so the cells pop.
  COLORRGB 0, 0, 0
  FILLRECT 0, BAND_Y TO 319, BAND_Y + BAND_H - 1

  ' Stamp the cached gradient tile at each on-screen cell slot.
  ' IMAGE BLEND (not IMAGE COPY) because dst = 0 only routes to
  ' the live RGBA framebuffer through BLEND — COPY needs dst to
  ' be a loaded IMAGE slot. Skip cells fully off-screen.
  FOR I = 0 TO LEN_MSG - 1
    CX = SCROLL_X + I * CELL_W
    IF CX > -CELL_W AND CX < 320 THEN
      IMAGE BLEND 1, 0, 0, CELL_W, CELL_H TO 0, CX, TEXT_Y
    END IF
  NEXT

  ' Punch the glyphs through the per-cell gradients. Black pen
  ' replaces glyph pixels with (0, 0, 0); non-glyph pixels in each
  ' cell keep the gradient from the blit above.
  COLORRGB 0, 0, 0
  DRAWTEXT SCROLL_X, TEXT_Y, MSG$, 2

  SCROLL_X = SCROLL_X - 2
  IF SCROLL_X < -(LEN_MSG * CELL_W) THEN SCROLL_X = 320

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 5: per-cell reverse-video gradient"

  VSYNC
LOOP

IMAGE FREE 1

DOUBLEBUFFER OFF
SCREEN 0
CLS
PRINT "Thanks for watching."
