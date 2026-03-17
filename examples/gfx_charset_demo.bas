1 REM GFX CHARSET DEMO: show screen codes 0-255
2 REM Run with: ./basic-gfx examples/gfx_charset_demo.bas
3 REM
4 REM Screen RAM starts at 1024 (0x0400), colour RAM at 55296 (0xD800).
5 REM The screen is 40x25 characters (1000 cells).  This demo writes
6 REM screen codes 0..255 into the top of screen RAM so you can see
7 REM how each code is rendered by the built-in 8x8 font.
10 BASE = 1024
20 COLORBASE = 55296
30 WIDTH = 40
40 TOTAL = 256
50 REM Fill screen codes 0..255 across rows, then leave the rest blank
60 FOR I = 0 TO TOTAL-1
70   POKE BASE + I, I
80 NEXT I
90 REM Clear the remaining cells to space (32)
100 FOR I = TOTAL TO WIDTH*25-1
110   POKE BASE + I, 32
120 NEXT I
130 REM Set colours: cycle through the 16 C64 colours (no MOD operator)
140 FOR I = 0 TO WIDTH*25-1
150   K = INT(I / 16)
160   K = I - K * 16
170   POKE COLORBASE + I, K
180 NEXT I
190 REM Keep the window open for a few seconds so you can inspect it
200 PRINT "GFX CHARSET DEMO: SCREEN CODES 0..255"
210 PRINT "WINDOW WILL CLOSE IN 5 SECONDS..."
220 SLEEP 3000
230 END

