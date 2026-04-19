' ============================================================
'  gfx_screen_buffer_demo - AMOS-style multi-plane buffers
'
'  SCREEN BUFFER n        allocate offscreen bitmap plane (2..7)
'  SCREEN DRAW n          retarget BASIC writes to plane n
'  SCREEN SHOW n          retarget the renderer to plane n
'  SCREEN COPY src, dst   blit one plane into another
'  SCREEN SWAP a, b       atomic draw=a, show=b
'  SCREEN FREE n          release a plane (must not be draw/show)
'
'  Slots 0 and 1 are always present: 0 is the live bitmap, 1 is
'  the DOUBLEBUFFER back-buffer. Slots 2..7 are on-heap.
'
'  This demo pre-renders two static scenes into slots 2 and 3
'  (slow path - drawn once) and then flips between them at
'  zero per-frame cost. SPACE to flip, Q to quit.
' ============================================================

SCREEN 1
BACKGROUND 0

' --- slot 2: solid rectangles scene
SCREEN BUFFER 2
SCREEN DRAW 2
CLS
COLOR 10
FOR I = 0 TO 5
  FILLRECT 40 + I * 36, 40 TO 72 + I * 36, 120
NEXT I
COLOR 1
DRAWTEXT 80, 160, "SCENE A - SLOT 2"

' --- slot 3: circles scene
SCREEN BUFFER 3
SCREEN DRAW 3
CLS
COLOR 14
FOR I = 0 TO 5
  FILLCIRCLE 50 + I * 40, 100, 18
NEXT I
COLOR 1
DRAWTEXT 80, 160, "SCENE B - SLOT 3"

' --- start showing slot 2, flipping cost nothing per frame
SCREEN DRAW 0
SCREEN SHOW 2
SHOWING = 2

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN
    IF SHOWING = 2 THEN
      SCREEN SHOW 3 : SHOWING = 3
    ELSE
      SCREEN SHOW 2 : SHOWING = 2
    END IF
  END IF
  VSYNC
LOOP

' Clean up (process teardown would reclaim heap anyway).
SCREEN SHOW 0
SCREEN FREE 2
SCREEN FREE 3
