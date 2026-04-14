1  REM RGC-BASIC mouse demo — exercises every mouse API
2  REM Native:  ./basic-gfx examples/gfx_mouse_demo.bas
3  REM Canvas:  load into canvas.html (or web/mouse-demo.html) then Run
4  REM
5  REM Controls:
6  REM   LEFT button   — paint pixels at the cursor
7  REM   RIGHT button  — clear the drawing area
8  REM   MIDDLE button — toggle cursor visibility (HIDECURSOR / SHOWCURSOR)
9  REM   LEFT+RIGHT    — warp pointer to centre (MOUSESET 160,100)
10 REM
11 REM Cursor shape auto-changes by vertical zone:
12 REM   top banner   -> 5 (pointer hand)
13 REM   middle band  -> 4 (crosshair)
14 REM   bottom area  -> 0 (default)

20 SCREEN 1
30 COLOR 1
40 BACKGROUND 6
50 PRINT CHR$(147);

100 GOSUB 800:                         REM draw banner + legend
110 HIDDEN = 0
120 LASTZONE = -1
130 KEYBASE = 56320

200 REM ---- main loop ----
210 MX = GETMOUSEX()
220 MY = GETMOUSEY()

230 REM paint while left button is held
240 IF ISMOUSEBUTTONDOWN(0) THEN PSET MX, MY

250 REM clear drawing area when right button is pressed this frame
260 IF ISMOUSEBUTTONPRESSED(1) THEN GOSUB 900

270 REM toggle cursor on middle-button press
280 IF ISMOUSEBUTTONPRESSED(2) THEN GOSUB 950

290 REM LEFT + RIGHT held together warps pointer to screen centre (MOUSESET)
300 IF ISMOUSEBUTTONDOWN(0) AND ISMOUSEBUTTONDOWN(1) THEN MOUSESET 160, 100

310 REM change cursor shape by zone (only when zone changes)
320 ZONE = 0
330 IF MY < 40  THEN ZONE = 5
340 IF MY >= 40 AND MY < 140 THEN ZONE = 4
350 IF ZONE <> LASTZONE THEN SETMOUSECURSOR ZONE : LASTZONE = ZONE

360 REM live status line on row 24
370 LOCATE 24, 1
380 PRINT "X=";MX;" Y=";MY;" L=";ISMOUSEBUTTONDOWN(0);
385 PRINT " R=";ISMOUSEBUTTONDOWN(1);" M=";ISMOUSEBUTTONDOWN(2);"    ";

390 SLEEP 1
400 GOTO 210

800 REM ---- banner / instruction block ----
810 LOCATE 1, 1
820 PRINT "{WHT}RGC-BASIC MOUSE DEMO"
830 PRINT "{GRN}LEFT PAINT   RIGHT CLEAR   MID HIDE/SHOW"
840 PRINT "{YEL}LEFT+RIGHT WARPS POINTER TO CENTRE"
850 PRINT "{CYN}--------------------------------"
860 RETURN

900 REM ---- clear drawing area, preserve banner ----
910 PRINT CHR$(147);
920 GOSUB 800
930 RETURN

950 REM ---- toggle cursor visibility ----
960 IF HIDDEN = 0 THEN HIDECURSOR: HIDDEN = 1: RETURN
970 SHOWCURSOR
980 HIDDEN = 0
990 RETURN
