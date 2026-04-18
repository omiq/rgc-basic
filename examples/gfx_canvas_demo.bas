1 REM ===========================================================
2 REM gfx_canvas_demo — PETSCII text + PNG sprite overlay
3 REM Canvas backend: PETSCII chars, color codes, and a single
4 REM LOADSPRITE slot updated each frame to animate the overlay.
5 REM Native: ./basic-gfx examples/gfx_canvas_demo.bas
6 REM WASM:   needs gfx_canvas_demo.png beside the .bas
7 REM ===========================================================
10 PRINT CHR$(14)
15 PRINT "{CLR}"
20 PRINT "{WHT}        RGC-BASIC CANVAS DEMO"
30 PRINT "{CYN}     PETSCII + PNG sprite overlay"
35 PRINT ""
40 PRINT "{GRN}grass  {BLU}water  {RED}fire   {YEL}gold"
50 PRINT "{PUR}magic  {WHT}snow   {GREY2}stone  {CYN}sky"
55 PRINT ""
60 PRINT "{YEL}Red 8x8 PNG bounces across the text"
70 PRINT "{GREY2}(canvas Z=50 draws above PETSCII)"
80 LOADSPRITE 0, "gfx_canvas_demo.png"
90 X = 20 : Y = 60 : DX = 3 : DY = 2
100 FOR I=1 TO 600
110 DRAWSPRITE 0, X, Y, 50
120 X = X + DX : Y = Y + DY
130 IF X < 4 OR X > 308 THEN DX = -DX
140 IF Y < 56 OR Y > 184 THEN DY = -DY
150 NEXT I
160 PRINT ""
170 PRINT "{GRN}Demo complete."
180 SLEEP 120
