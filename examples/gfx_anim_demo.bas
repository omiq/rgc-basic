1 REM =========================================================
2 REM gfx_anim_demo — ANIMFRAME auto-cycles a sprite's tile index
3 REM
4 REM tile_sheet.png is a 2-frame 64x32 sheet (32x32 per cell).
5 REM ANIMFRAME(1, 2, 15) cycles between tile 1 and tile 2, advancing
6 REM every 15 jiffies (60/15 = 4 FPS). SPRITE FRAME sets which tile
7 REM DRAWSPRITE uses when called without explicit crop args.
8 REM
9 REM Keys: Q quit
10 REM =========================================================
20 SPRITE LOAD 0, "tile_sheet.png", 32, 32
30 X = 144 : Y = 84
40 IF KEYDOWN(ASC("Q")) THEN END
50 CLS
60 SPRITE FRAME 0, ANIMFRAME(1, 2, 15)
70 DRAWSPRITE 0, X, Y, 100
80 VSYNC
90 GOTO 40
