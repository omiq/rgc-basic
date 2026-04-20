' ============================================================
'  gfx_palette_load_demo - PALETTELOAD / PALETTESAVE
'
'  PALETTELOAD path$    read 256-entry .pal into live palette
'  PALETTESAVE path$    write live palette to .pal
'
'  Format is plain text: one "R G B A" per line, 0..255
'  decimal. `#` comments + blank lines ignored. JASC-PAL headers
'  are auto-detected and skipped so you can drop in palettes
'  from Paint Shop Pro, Aseprite, etc.
'
'  Only the first N lines of the file retune entries 0..N-1;
'  indices beyond the file's count stay at whatever they were
'  before the load (defaults or previously set values).
'
'  Keys: L load sunset, D defaults, S save live palette, Q quit
' ============================================================

SCREEN 3
BACKGROUND 0
CLS

FOR I = 0 TO 255
  COLOR I
  SX = (I MOD 32) * 10
  SY = 24 + (I \ 32) * 20
  FILLRECT SX, SY TO SX + 8, SY + 18
NEXT I

COLOR 1
DRAWTEXT 8,   4, "PALETTELOAD / PALETTESAVE", 1
DRAWTEXT 8, 186, "L SUNSET  D DEFAULTS  S SAVE  Q QUIT", 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("L")) THEN PALETTELOAD "sunset.pal"
  IF KEYPRESS(ASC("D")) THEN PALETTERESET
  IF KEYPRESS(ASC("S")) THEN PALETTESAVE "out.pal"
  SLEEP 1
LOOP

PALETTERESET
