' ============================================================
'  gfx_color_per_stamp_demo - SCREEN 1 per-pixel 16-colour
'
'  Before 1.12, SCREEN 1 had one global bitmap_fg register read
'  once per composite. Changing COLOR between stamps retinted
'  the WHOLE plane on the next frame - causing "flashing" when
'  the loop cycled colours.
'
'  Now every set-pixel stamps the current COLOR into a companion
'  colour plane. Each stamp keeps its own colour.
'
'  Keys: Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
CLS

COLOR 2  : FILLCIRCLE  60, 100, 20                 ' red
COLOR 5  : FILLCIRCLE 120, 100, 20                 ' green
COLOR 6  : FILLCIRCLE 180, 100, 20                 ' blue
COLOR 7  : FILLCIRCLE 240, 100, 20                 ' yellow

COLOR 1  : RECT  8,  8 TO 311, 50
COLOR 14 : DRAWTEXT 12, 20, "PER-STAMP COLOUR", 2

COLOR 10 : LINE  0, 160 TO 319, 160
COLOR 13 : LINE  0, 170 TO 319, 170
COLOR 3  : LINE  0, 180 TO 319, 180
COLOR 4  : LINE  0, 190 TO 319, 190

COLOR 1  : DRAWTEXT  8, 140, "Q QUIT", 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 1
LOOP
