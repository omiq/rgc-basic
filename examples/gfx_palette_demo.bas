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
'  Animation runs continuously — palette entry 2 hot-cycles
'  through an RGB sweep and every swatch / text pixel that was
'  drawn with COLOR 2 retints next frame without being redrawn.
'
'  Keys: SPACE pause / resume, R reset palette, Q quit
' ============================================================

SCREEN 1
BACKGROUND 0

' Draw 16 swatches with the default palette (8-wide × 2-tall grid).
' `\` is integer divide (classic BASIC / QBasic-style).
FOR I = 0 TO 15
  SX = 8  + (I MOD 8) * 38
  SY = 12 + (I \ 8)   * 38
  COLOR I
  FILLRECT SX, SY TO SX + 32, SY + 32
  COLOR 1
  DRAWTEXT SX + 2, SY + 38, STR$(I), 1
NEXT I

COLOR 14
DRAWTEXT 8, 130, "SPACE PAUSE  R RESET  Q QUIT", 1

T = 0
PAUSED = 0
DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("R")) THEN PALETTERESET
  IF KEYPRESS(ASC(" ")) THEN PAUSED = 1 - PAUSED

  IF PAUSED = 0 THEN
    ' Hot-cycle entry 2 (red). Each frame advances T; the swatch
    ' and any text pixel drawn in COLOR 2 retints on the next
    ' composite without being redrawn.
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
