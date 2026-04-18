1 REM ===========================================================
2 REM gfx_bitmap_demo — hi-res bitmap (SCREEN 1, 320x200)
3 REM   PSET/PRESET/LINE, shape primitives, DRAWTEXT, raw POKE
4 REM ===========================================================
10 SCREEN 1
20 BACKGROUND 0
25 REM --- grid backdrop ---
30 COLOR 11
40 FOR X=0 TO 319 STEP 20 : LINE X,0 TO X,199 : NEXT X
50 FOR Y=0 TO 199 STEP 20 : LINE 0,Y TO 319,Y : NEXT Y
55 REM --- animated sine wave (one pass) ---
60 COLOR 7
70 FOR X=0 TO 319
80 Y = 100 + INT(40 * SIN(X*0.04))
90 PSET X, Y
100 NEXT X
105 REM --- concentric circles ---
110 COLOR 1
120 FOR R=8 TO 64 STEP 8 : CIRCLE 60, 60, R : NEXT R
125 REM --- filled shape trio ---
130 COLOR 2 : FILLRECT     128, 24 TO 168, 56
140 COLOR 4 : FILLCIRCLE   200, 40, 20
150 COLOR 5 : FILLTRIANGLE 236, 60, 276, 20, 312, 60
155 REM --- outlined + filled ellipse pair ---
160 COLOR 8 : ELLIPSE      184, 120, 40, 16
170 COLOR 3 : FILLELLIPSE  184, 150, 28, 10
175 REM --- raw POKE: four pixels at top-left via bitmap RAM ---
180 POKE 8192, 255 : POKE 8193, 255
190 POKE 8232, 255 : POKE 8233, 255
195 REM --- star scatter with PSET ---
200 FOR I=1 TO 40
210 PSET INT(RND(1)*320), INT(RND(1)*60)
220 NEXT I
225 REM --- labels ---
230 COLOR 1 : DRAWTEXT 8, 182, "SCREEN 1 BITMAP DEMO"
240 DRAWTEXT 8, 190, "PSET LINE CIRCLE RECT ..."
250 SLEEP 600
