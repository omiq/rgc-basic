' ============================================================
'  gfx_screen4_demo - SCREEN 4 (640x400 RGBA desktop canvas)
'
'  Same RGBA primitives as SCREEN 2 (COLORRGB, BACKGROUNDRGB,
'  LINE, RECT, FILLRECT, CIRCLE, DRAWTEXT, IMAGE LOAD + BLEND,
'  LOADSCREEN), just with a 640x400 canvas so desktop-style UIs
'  (map editors, level tools, HUDs, IDE-ish workspaces) have room
'  for buttons and side panels.
'
'  Everything scales automatically — the render target matches
'  the source plane dims, the iframe window widens, and the
'  coordinate range for every primitive is now 0..639 x 0..399.
'
'  RECT / FILLRECT syntax: x0, y0 TO x1, y1.
' ============================================================

SCREEN 4
BACKGROUNDRGB 24, 24, 40
CLS

' toolbar strip
COLORRGB 60, 60, 96
FILLRECT 0, 0 TO 639, 24
COLORRGB 255, 255, 255
DRAWTEXT 8, 8, "SCREEN 4 - 640x400 RGBA", 1, -1, 0, 2

' left panel
COLORRGB 40, 40, 72
FILLRECT 0, 24 TO 160, 399
COLORRGB 220, 220, 220
DRAWTEXT 8, 36, "TOOLS"
DRAWTEXT 8, 52, "- DRAW"
DRAWTEXT 8, 64, "- ERASE"
DRAWTEXT 8, 76, "- PICK"
DRAWTEXT 8, 88, "- FILL"

' workspace box
COLORRGB 10, 10, 20
FILLRECT 168, 32 TO 631, 391
COLORRGB 100, 100, 140
RECT     168, 32 TO 631, 391

' a smattering of colour blocks to prove the wider canvas works
FOR I = 0 TO 15
  R = 16 + (I MOD 4) * 60
  G = 80 + (I \ 4)   * 40
  B = 200 - I * 10
  COLORRGB R, G, B
  BX = 176 + (I MOD 8) * 56
  BY = 48  + (I \ 8)   * 56
  FILLRECT BX, BY TO BX + 48, BY + 48
NEXT I

COLORRGB 255, 255, 128
DRAWTEXT 176, 370, "640 WIDE CANVAS - MAP EDITOR PORT NEXT", 7, 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 1
LOOP
