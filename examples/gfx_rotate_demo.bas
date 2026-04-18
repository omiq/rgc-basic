1 REM =========================================================
2 REM gfx_rotate_demo — SPRITE STAMP with rotation
3 REM
4 REM Shows the 6th optional arg to SPRITE STAMP:
5 REM   SPRITE STAMP slot, x, y, frame, z, rot_deg
6 REM
7 REM Rotation pivots around the sprite centre. Only basic-gfx (raylib
8 REM backend) rotates — canvas/WASM accepts the arg but ignores it.
9 REM
10 REM Sixteen ships fan out in a circle, each pointing outward; the
11 REM whole ring also spins clockwise over time.
12 REM
13 REM Keys: Q quit
14 REM =========================================================
20 SPRITE LOAD 0, "ship.png"
30 CX = 160 : CY = 100
40 R = 70
50 N = 16
60 T = 0
70 IF KEYDOWN(ASC("Q")) THEN END
80 CLS
90 FOR I = 0 TO N-1
100 REM angle in degrees, fans out across 360
110 A = (I * 360 / N) + T
120 AX = CX + R * COS(A * 3.14159 / 180) - 16
130 AY = CY + R * SIN(A * 3.14159 / 180) - 16
140 REM rot matches the ring angle + 90 so ship points outward
150 SPRITE STAMP 0, AX, AY, 0, 10, A + 90
160 NEXT I
170 T = T + 2
180 IF T >= 360 THEN T = 0
190 VSYNC
200 GOTO 70
