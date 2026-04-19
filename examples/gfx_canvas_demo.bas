' ============================================================
'  gfx_canvas_demo - PETSCII text + PNG sprite overlay
'  Canvas backend: PETSCII chars, colour codes, and one LOADSPRITE
'  slot drawn at (100,100). The screenshot regression test checks
'  for red-sprite pixels around (104,104).
'   Native: ./basic-gfx examples/gfx_canvas_demo.bas
'   WASM:   needs gfx_canvas_demo.png beside the .bas
' ============================================================

PRINT CHR$(14)                      ' lowercase/uppercase charset
PRINT "{CLR}"
PRINT "{WHT}        RGC-BASIC CANVAS DEMO"
PRINT "{CYN}     PETSCII + PNG sprite overlay"
PRINT
PRINT "{GRN}grass  {BLU}water  {RED}fire   {YEL}gold"
PRINT "{PUR}magic  {WHT}snow   {GREY2}stone  {CYN}sky"
PRINT
PRINT "{YEL}Red 8x8 PNG stamped at (100,100)"
PRINT "{GREY2}(canvas Z=50 draws above PETSCII)"

LOADSPRITE 0, "gfx_canvas_demo.png"
DRAWSPRITE  0, 100, 100, 50

SLEEP 120
