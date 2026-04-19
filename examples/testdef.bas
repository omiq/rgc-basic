' DEF FN — single-expression user function
' For multi-statement blocks, use FUNCTION / END FUNCTION instead.

DEF FNY(X) = INT((SIN(X * 0.3) + 1) * 18 + 1)

FOR I = 1 TO 5
  PRINT I, FNY(I)
NEXT I
