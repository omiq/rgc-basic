1 REM =========================================================
2 REM gfx_antialias_demo — ANTIALIAS ON/OFF toggle
3 REM
4 REM Upscales a 32x32 ship to 4x (128x128) so the filter-mode
5 REM difference is obvious. Press SPACE to flip between POINT
5 REM (crisp pixels, retro) and BILINEAR (smoothed). Current mode
6 REM is printed on screen.
7 REM
8 REM Keys: SPACE toggle, Q quit
9 REM =========================================================
10 SPRITE LOAD 0, "ship.png"
20 REM scale x4 — big enough that filter choice matters
30 SPRITEMODULATE 0, 255, 255, 255, 255, 4, 4
40 AA = 0
50 ANTIALIAS OFF
60 REM --- main loop ---
70 IF KEYDOWN(ASC("Q")) THEN END
80 IF KEYPRESS(ASC(" ")) THEN GOSUB 190
90 CLS
100 REM big scaled ship in the middle
110 DRAWSPRITE 0, 96, 36, 10
120 REM labels
130 DRAWTEXT 8,   8, "ANTIALIAS TEST"
140 IF AA = 1 THEN DRAWTEXT 8, 24, "MODE: ON  (BILINEAR)"
150 IF AA = 0 THEN DRAWTEXT 8, 24, "MODE: OFF (NEAREST)"
160 DRAWTEXT 8, 180, "SPACE TOGGLE   Q QUIT"
170 VSYNC
180 GOTO 70
190 AA = 1 - AA
200 IF AA = 1 THEN ANTIALIAS ON ELSE ANTIALIAS OFF
210 RETURN
