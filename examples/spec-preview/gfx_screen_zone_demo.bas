1 REM =========================================================
2 REM gfx_screen_zone_demo — parallax via SCREEN ZONE + SCREEN SCROLL
3 REM STATUS: spec preview, requires rgc-basic v1.9+
4 REM
5 REM Three horizontal bands scroll left at different speeds:
6 REM   band 1 (sky)    — 1 px/tick, slowest
7 REM   band 2 (mid)    — 2 px/tick
8 REM   band 3 (ground) — 4 px/tick, fastest
9 REM
10 REM Each SCREEN SCROLL call blits the named zone by its defined
11 REM velocity. Content wraps at the zone edges.
12 REM
13 REM Keys: Q quit
14 REM =========================================================
20 PRINT CHR$(14)
30 REM fill the three bands with distinctive content — here we just
40 REM paint coloured bars via POKE, a real demo would IMAGE COPY
50 REM tile art in first.
60 REM define three scrollable zones on the visible screen (slot 0)
70 SCREEN ZONE 1, 0,   0,  320,  60, -1, 0
80 SCREEN ZONE 2, 0,  60,  320, 140, -2, 0
90 SCREEN ZONE 3, 0, 140,  320, 200, -4, 0
100 REM paint initial terrain (placeholder: three coloured hlines)
110 COLOR 6  : REM blue sky
120 FOR Y = 0 TO 59   : LINE 0,Y,319,Y : NEXT Y
130 COLOR 5  : REM green mid
140 FOR Y = 60 TO 139 : LINE 0,Y,319,Y : NEXT Y
150 COLOR 8  : REM brown ground
160 FOR Y = 140 TO 199 : LINE 0,Y,319,Y : NEXT Y
170 REM overlay some markers so the scroll is visible
180 COLOR 1
190 FOR X = 0 TO 319 STEP 32 : LINE X,0,X,59   : NEXT X
200 FOR X = 0 TO 319 STEP 16 : LINE X,60,X,139 : NEXT X
210 FOR X = 0 TO 319 STEP 8  : LINE X,140,X,199 : NEXT X
220 REM ---- main loop ----
230 K$ = UCASE$(INKEY$())
240 IF K$ = "Q" THEN END
250 SCREEN SCROLL 1
260 SCREEN SCROLL 2
270 SCREEN SCROLL 3
280 SLEEP 2
290 GOTO 230
