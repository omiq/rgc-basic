1 REM =========================================================
2 REM gfx_anim_demo — ANIMFRAME auto-cycles a sprite's tile index
3 REM
4 REM boing_sheet.png is a 768x64 sheet (12 frames at 64x64 each)
5 REM showing an Amiga-style boing ball rolling through its cycle.
6 REM ANIMFRAME(1, 12, 4) cycles 12 frames at 15 FPS (60/4 = 15).
7 REM SPRITE FRAME sets which tile DRAWSPRITE uses when called without
8 REM explicit crop args.
9 REM
10 REM Keys: Q quit
11 REM =========================================================
20 SPRITE LOAD 0, "boing_sheet.png", 64, 64
30 X = 128 : Y = 68
40 IF KEYDOWN(ASC("Q")) THEN END
50 CLS
60 SPRITE FRAME 0, ANIMFRAME(1, 12, 4)
70 DRAWSPRITE 0, X, Y, 100
80 VSYNC
90 GOTO 40
