REM FOR / NEXT / IF / ELSE IF — all portable.
FOR I = 1 TO 10
  IF I MOD 2 = 0 THEN
    PRINT I; " EVEN"
  ELSE IF I = 1 THEN
    PRINT I; " ONE"
  ELSE
    PRINT I; " ODD"
  END IF
NEXT I
END
