' 2-D array DIM/assign/read demo

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
