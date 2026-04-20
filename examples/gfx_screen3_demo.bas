' ============================================================
'  gfx_screen3_demo - 256-colour indexed bitmap
'
'  SCREEN 3 is 320x200 with 1 byte per pixel; each byte is a
'  palette index 0..255. Cheaper than SCREEN 2 RGBA (64 KB
'  vs 256 KB per plane) and supports palette cycling / rotation
'  effects for retro demos.
'
'  Entries 0..15 are the C64 palette. Entries 16..255 default
'  to an HSV rainbow + muted/pastel bands + greyscale, so a
'  bare SCREEN 3 has usable colours out of the box. Overwrite
'  any entry with PALETTESET at runtime.
'
'  Keys: SPACE cycle palette, R reset, Q quit
' ============================================================

SCREEN 3
BACKGROUND 11
CLS

' Draw all 256 swatches — 32-wide x 8-tall grid.
FOR I = 0 TO 255
  COLOR I
  SX = (I MOD 32) * 10
  SY = 24 + (I \ 32) * 20
  FILLRECT SX, SY TO SX + 8, SY + 18
NEXT I

COLOR 1
DRAWTEXT 8,   4, "SCREEN 3 - 256 COLOURS", 1
DRAWTEXT 8, 186, "SPACE CYCLE  R RESET  Q QUIT", 1

DIM PAL_SAVE(256, 2)
FOR I = 0 TO 255
  PAL_SAVE(I, 0) = PALETTE(I, 0)
  PAL_SAVE(I, 1) = PALETTE(I, 1)
  PAL_SAVE(I, 2) = PALETTE(I, 2)
NEXT I

CYCLING = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC(" ")) THEN CYCLING = 1 - CYCLING
  IF KEYPRESS(ASC("R")) THEN PALETTERESET

  IF CYCLING = 1 THEN
    ' Rotate entries 16..255 one step in a single engine call —
    ' much cheaper than 240 PALETTESET from BASIC. Swatches retint
    ' on the next composite, no pixels redrawn.
    PALETTEROTATE 16, 255, 1
  END IF

  SLEEP 1
LOOP

PALETTERESET
