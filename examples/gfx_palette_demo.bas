' ============================================================
'  gfx_palette_demo - writable 16-entry palette
'
'  PALETTESET i, r, g, b [, a]        retune palette entry
'  PALETTESETHEX i, "#RRGGBB[AA]"     hex form
'  PALETTERESET                       restore C64 defaults
'  PALETTE(i, chan)                   read channel (0=R 1=G 2=B 3=A)
'  PALETTEHEX$(i)                     "#RRGGBB" or "#RRGGBBAA"
'
'  The live table feeds both SCREEN 1 rendering and SCREEN 2
'  COLOR n -> RGBA translation, so changes appear next frame.
'
'  Keys: SPACE animate, R reset, Q quit
' ============================================================

SCREEN 1
BACKGROUND 0

' Draw 16 swatches with the default palette (8-wide × 2-tall grid).
FOR I = 0 TO 15
  COL = I - INT(I / 8) * 8         ' I MOD 8 — column
  ROW = INT(I / 8)                 ' 0 or 1 — row
  SX  = 8  + COL * 38
  SY  = 12 + ROW * 38
  COLOR I
  FILLRECT SX, SY TO SX + 32, SY + 32
  COLOR 1
  DRAWTEXT SX + 2, SY + 38, STR$(I), 1
NEXT I

COLOR 14
DRAWTEXT 8, 130, PALETTEHEX$(2), 1
DRAWTEXT 8, 145, "SPACE ANIMATE  R RESET  Q QUIT", 1

T = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("R")) THEN PALETTERESET
  IF KEYDOWN(ASC(" ")) THEN
    ' Hot-cycle entry 2 (red) through the spectrum. Next frame the red
    ' swatch updates to the new RGB without any redraw.
    T = T + 4
    IF T > 359 THEN T = 0
    RA = ABS((T MOD 360) - 180)                ' triangular 0..180..0
    GA = ABS(((T + 120) MOD 360) - 180)
    BA = ABS(((T + 240) MOD 360) - 180)
    PALETTESET 2, INT(RA * 255 / 180), INT(GA * 255 / 180), INT(BA * 255 / 180)
  END IF
  SLEEP 1
LOOP

PALETTERESET
