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

' off-screen RGBA slot 1 — must be IMAGE CREATE'd as RGBA before
' IMAGE LOAD, otherwise the legacy 1bpp path takes the PNG and
' IMAGE BLEND has no alpha channel to composite with. Any size
' works; LOAD resizes to match the PNG.
' chick.png has an alpha channel so the blend preserves transparency
' around the sprite silhouette instead of compositing a bounding box.
IMAGE CREATE 1, 64, 64
IMAGE LOAD   1, "chick.png"
IW = 32
IH = 32

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
