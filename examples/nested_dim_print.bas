REM Nested FOR + 2D array + PRINT — if canvas WASM "freezes" but basic-gfx is fine,
REM the tab is likely busy in WASM without yielding (browser main thread).
REM Try Stop, or add SLEEP 1 inside the inner loop to confirm.

10 DIM A(2,3)
20 FOR I=0 TO 1
30 FOR J=0 TO 2
40 A(I,J)=I*10+J
50 NEXT J
60 NEXT I
70 FOR I=0 TO 1
80 FOR J=0 TO 2
90 PRINT I;",";J;"=";A(I,J)
100 NEXT J
110 NEXT I
120 END
