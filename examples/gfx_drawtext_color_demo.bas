' ============================================================
'  gfx_drawtext_color_demo - DRAWTEXT per-call fg / bg colour
'
'  DRAWTEXT x, y, text$                           pen = current COLOR
'  DRAWTEXT x, y, text$, scale                    legacy scale form
'  DRAWTEXT x, y, text$, fg, bg                   per-call colours
'  DRAWTEXT x, y, text$, fg, bg, font_slot        font slot (reserved)
'  DRAWTEXT x, y, text$, fg, bg, font_slot, scale full extended form
'
'  bg = -1 keeps paper transparent. bg >= 0 paints a solid rect of
'  that palette index before the glyphs stamp, so text reads cleanly
'  over whatever was already drawn.
' ============================================================

SCREEN 1
BACKGROUND 6
CLS

DRAWTEXT  8,  12, "TRANSPARENT PAPER"
DRAWTEXT  8,  28, "RED ON BLACK", 2, 0
DRAWTEXT  8,  44, "WHITE ON BLUE (SCALED)", 1, 6, 0, 2
DRAWTEXT  8,  80, "YELLOW BANNER", 7, 11
DRAWTEXT  8,  96, "CYAN ACCENT",   3, 0
DRAWTEXT  8, 112, "ORIGINAL COLOR STILL 1", 1, -1

COLOR 1
DRAWTEXT  8, 186, "Q QUIT"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 1
LOOP
