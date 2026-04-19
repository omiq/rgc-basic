' Nested FOR + 2D array + PRINT
' If canvas WASM "freezes" but basic-gfx is fine, the tab is busy
' without yielding. Try Stop, or SLEEP 1 inside the inner loop.

DIM A(2, 3)

FOR I = 0 TO 1
  FOR J = 0 TO 2
    A(I, J) = I * 10 + J
  NEXT J
NEXT I

FOR I = 0 TO 1
  FOR J = 0 TO 2
    PRINT I; ","; J; "="; A(I, J)
  NEXT J
NEXT I
