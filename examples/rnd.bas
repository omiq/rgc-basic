' RND demo — roll 10 dice per line, run until Ctrl-C
' RND(-N) seeds; RND(0) is uniform 0..1

R = RND(-TI)

DO
  FOR I = 1 TO 10
    PRINT INT(RND(0) * 6); " ";
  NEXT I
  PRINT
  SLEEP 30
LOOP
