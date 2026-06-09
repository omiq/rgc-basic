0 REM === DUNGEON DICE - C64 BASIC V2 - RANDOM ===
1 REM Stock C64 BASIC V2 (NOT rgc-basic). POKEs screencodes
2 REM straight to screen RAM. Companion to gfx_dice_map_demo.bas
3 REM (the rgc-basic edge-match demo) - this is the cut-down
4 REM tutorial port: 13x8 grid of 3x3 meta-tiles, # walls / .
5 REM floor, exits punched per a 4-bit mask (N=1 E=2 S=4 W=8).
10 POKE 53280,0:POKE 53281,0
20 X=RND(-TI)
30 SB=1024:CB=55296
40 GC=13:GR=8
50 W=35:D=46
60 REM W=screencode '#'  D=screencode '.'
90 REM --- draw a new dungeon ---
100 PRINT CHR$(147)
110 FOR CY=0 TO GR-1
120 FOR CX=0 TO GC-1
130 GOSUB 600
140 OX=CX*3:OY=CY*3
150 P=SB+OY*40+OX
160 REM top row: corners wall, mid = N exit
170 POKE P,W
180 IF (M AND 1) THEN POKE P+1,D
190 IF (M AND 1)=0 THEN POKE P+1,W
200 POKE P+2,W
210 REM mid row: W exit, centre floor, E exit
220 IF (M AND 8) THEN POKE P+40,D
230 IF (M AND 8)=0 THEN POKE P+40,W
240 POKE P+41,D
250 IF (M AND 2) THEN POKE P+42,D
260 IF (M AND 2)=0 THEN POKE P+42,W
270 REM bottom row: corners wall, mid = S exit
280 POKE P+80,W
290 IF (M AND 4) THEN POKE P+81,D
300 IF (M AND 4)=0 THEN POKE P+81,W
310 POKE P+82,W
320 NEXT CX
330 NEXT CY
340 REM drop player @ on a random cell centre
350 CX=INT(RND(1)*GC):CY=INT(RND(1)*GR)
360 POKE SB+(CY*3+1)*40+(CX*3+1),0
370 A$="SPACE=NEW Q=QUIT"
380 FOR I=0 TO LEN(A$)-1:POKE SB+960+I,ASC(MID$(A$,I+1,1)) AND 63:NEXT
390 REM --- wait for a key ---
400 GET A$:IF A$="" THEN 400
410 IF A$="Q" THEN PRINT CHR$(147):END
420 GOTO 100
590 REM ===== roll one cell's exit mask into M =====
600 F=1+INT(RND(1)*6)
610 BA=15
620 IF F=1 THEN BA=5
630 IF F=2 THEN BA=12
640 IF F=3 THEN BA=14
650 NR=1
660 IF F=1 THEN NR=2
670 IF F=2 THEN NR=4
680 IF F=3 THEN NR=4
690 K=INT(RND(1)*NR)
700 M=BA:J=0
710 IF J>=K THEN RETURN
720 GOSUB 800:J=J+1:GOTO 710
790 REM ===== rotate M one quarter clockwise =====
800 NB=0
810 IF (M AND 8) THEN NB=NB+1
820 IF (M AND 1) THEN NB=NB+2
830 IF (M AND 2) THEN NB=NB+4
840 IF (M AND 4) THEN NB=NB+8
850 M=NB:RETURN
