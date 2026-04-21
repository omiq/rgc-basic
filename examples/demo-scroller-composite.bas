' ============================================================
'  demo-scroller-composite.bas — Approach 2: per-frame RGBA
'                                gradient band + scrolling
'                                white text on top
'
'  No assets. Paints a vertical RGB gradient into a 40-pixel band
'  every frame, then DRAWTEXTs the scroller on top. The text is
'  solid white — the gradient is the decorative layer BEHIND it.
'
'  Why not "gradient through the glyphs"? rgc-basic's DRAWTEXT uses
'  a single-pen OR blend per glyph, and SCREEN BUFFER planes match
'  the screen size (no off-screen canvas wider than 320 px) so we
'  can't pre-composite "wide strip of glyphs filled with gradient"
'  today. The closest we can ship in 2.x is this: a stable gradient
'  layer + live-drawn scroller on top. When `IMAGE DRAW slot` lands
'  in 2.1 (tracked in to-do.md) the composite demo can be upgraded
'  to bake the gradient into the glyphs themselves.
'
'  For now, see demo-scroller-png.bas for "gradient-baked PNG" or
'  demo-scroller-sprites.bas for "per-char colour sprite sheet".
'
'  How it works:
'    * SCREEN 2 (RGBA). BAND_Y..BAND_Y+BAND_H is the strip the
'      gradient + scroller live in.
'    * Each frame: FILLRECT clears the strip to BACKGROUND, then
'      40 LINE ops paint the gradient one row at a time, then two
'      DRAWTEXT passes (shadow + main) stamp the scroller.
'    * 40 LINE calls per frame is well under a millisecond; no
'      need for IMAGE CREATE / GRAB / COPY bookkeeping.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 8, 8, 24
CLS

' DOUBLEBUFFER ON + VSYNC at the end of the loop = atomic frame
' commit. Without this, the per-frame FILLRECT + LINE + DRAWTEXT
' sequence can be visible mid-paint and the strip flashes.
DOUBLEBUFFER ON

BAND_Y = 40
BAND_H = 40

MSG$ = "  * * *   WELCOME TO RGC-BASIC 2.0   * * *   LIVE GRADIENT BAND UNDER A SCROLLING TEXT LAYER.   TRY APPROACH 1 (PALETTE COPPER BARS) OR APPROACH 3 (LONG PNG) FOR DIFFERENT VIBES.   "
LEN_MSG = LEN(MSG$)
SCROLL_X = 320

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  ' Clear the strip only; leave the rest of the frame alone so
  ' later artwork (HUD, sprites) can coexist.
  COLORRGB 8, 8, 24
  FILLRECT 0, BAND_Y TO 319, BAND_Y + BAND_H - 1

  ' Gradient band — one row per index. Sky blue at the top fading
  ' to deep purple at the bottom. Retune R/G/B to taste.
  FOR Y = 0 TO BAND_H - 1
    T = Y / (BAND_H - 1.0)
    R = INT( 40 + T * 180 )
    G = INT(160 - T * 120 )
    B = INT(255 - T *  60 )
    COLORRGB R, G, B
    LINE 0, BAND_Y + Y TO 319, BAND_Y + Y
  NEXT

  ' Drop shadow (dark, offset by 2 px).
  COLORRGB 0, 0, 0
  DRAWTEXT SCROLL_X + 2, BAND_Y + 12 + 2, MSG$, 2

  ' Main scroller — solid bright tint.
  COLORRGB 255, 255, 240
  DRAWTEXT SCROLL_X, BAND_Y + 12, MSG$, 2

  SCROLL_X = SCROLL_X - 2
  IF SCROLL_X < -(LEN_MSG * 16) THEN SCROLL_X = 320

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 2: live gradient band + scroller"

  VSYNC
LOOP

DOUBLEBUFFER OFF
SCREEN 0
CLS
PRINT "Thanks for watching."
