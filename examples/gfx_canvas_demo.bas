1 REM ===========================================================
2 REM gfx_canvas_demo — PETSCII text + PNG sprite overlay
3 REM Canvas backend: PETSCII chars, color codes, and a LOADSPRITE
4 REM slot drawn once at (100,100) so the screenshot test can
5 REM verify red-sprite output at (104,104).
6 REM Native: ./basic-gfx examples/gfx_canvas_demo.bas
7 REM WASM:   needs gfx_canvas_demo.png beside the .bas
8 REM ===========================================================
10 PRINT CHR$(14)
15 PRINT "{CLR}"
20 PRINT "{WHT}        RGC-BASIC CANVAS DEMO"
30 PRINT "{CYN}     PETSCII + PNG sprite overlay"
35 PRINT ""
40 PRINT "{GRN}grass  {BLU}water  {RED}fire   {YEL}gold"
50 PRINT "{PUR}magic  {WHT}snow   {GREY2}stone  {CYN}sky"
55 PRINT ""
60 PRINT "{YEL}Red 8x8 PNG stamped at (100,100)"
70 PRINT "{GREY2}(canvas Z=50 draws above PETSCII)"
80 LOADSPRITE 0, "gfx_canvas_demo.png"
90 DRAWSPRITE 0, 100, 100, 50
100 SLEEP 120
