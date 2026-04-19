' ============================================================
'  gfx_bitmap_demo - hi-res bitmap (SCREEN 1, 320x200)
'  PSET/PRESET/LINE, shape primitives, DRAWTEXT, raw POKE.
' ============================================================

SCREEN 1
BACKGROUND 0

' --- grid backdrop ---
COLOR 11
FOR X = 0 TO 319 STEP 20
  LINE X, 0 TO X, 199
NEXT X
FOR Y = 0 TO 199 STEP 20
  LINE 0, Y TO 319, Y
NEXT Y

' --- sine wave (one pass) ---
COLOR 7
FOR X = 0 TO 319
  Y = 100 + INT(40 * SIN(X * 0.04))
  PSET X, Y
NEXT X

' --- concentric circles ---
COLOR 1
FOR R = 8 TO 64 STEP 8
  CIRCLE 60, 60, R
NEXT R

' --- filled shape trio ---
COLOR 2 : FILLRECT     128,  24 TO 168,  56
COLOR 4 : FILLCIRCLE   200,  40, 20
COLOR 5 : FILLTRIANGLE 236,  60, 276, 20, 312, 60

' --- outlined + filled ellipse pair ---
COLOR 8 : ELLIPSE     184, 120, 40, 16
COLOR 3 : FILLELLIPSE 184, 150, 28, 10

' --- raw POKE: four pixels at top-left via bitmap RAM ---
POKE 8192, 255 : POKE 8193, 255
POKE 8232, 255 : POKE 8233, 255

' --- star scatter with PSET ---
FOR I = 1 TO 40
  PSET INT(RND(1) * 320), INT(RND(1) * 60)
NEXT I

' --- labels ---
COLOR 1
DRAWTEXT 8, 182, "SCREEN 1 BITMAP DEMO"
DRAWTEXT 8, 190, "PSET LINE CIRCLE RECT ..."

SLEEP 600
