' ============================================================
'  gfx_blend_demo - IMAGE CREATE RGBA + IMAGE BLEND
'
'  IMAGE CREATE slot, w, h          alloc an RGBA off-screen slot
'  IMAGE BLEND  src, sx, sy, sw, sh TO dst, dx, dy
'                                    Porter-Duff source-over blit
'                                    between two RGBA surfaces. dst=0
'                                    routes to the live SCREEN 2
'                                    framebuffer.
'
'  The demo loads sky.png into the live SCREEN 2 plane as background,
'  then LOADs a second PNG into an off-screen RGBA slot and alpha-
'  composites it over the sky. Any fully-transparent pixels in the
'  sprite PNG stay transparent after the blend; semi-transparent
'  pixels smooth-blend against whatever sky pixel is underneath.
'
'  Keys: SPACE move overlay, Q quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 0, 0, 32
CLS
LOADSCREEN "sky.png"

' off-screen RGBA slot 1 — will hold a second PNG (any RGBA file).
' Falls back to "cat.png"; swap in your own transparent-background PNG.
IMAGE LOAD 1, "sky.png"
IW = 160
IH = 120

X = 40
Y = 60

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN X = X + 10 : IF X > 320 THEN X = -IW

  ' Reset the sky under the overlay so old blends don't pile up.
  LOADSCREEN "sky.png"
  IMAGE BLEND 1, 0, 0, IW, IH TO 0, X, Y

  SLEEP 2
LOOP
