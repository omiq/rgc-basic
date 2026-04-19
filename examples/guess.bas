' NUMBER GUESSING GAME
' Picks a secret 1..100 and prompts until you guess it; then asks to play again.

T = RND(-TI)                    ' seed RNG from jiffy clock

DO
  CLS
  PRINT "NUMBER GUESSING GAME"
  PRINT "===================="
  PRINT
  R = INT(RND(1) * 100) + 1
  PRINT "I'M THINKING OF A NUMBER BETWEEN 1 AND 100."
  PRINT

  DO
    INPUT "YOUR GUESS"; G
    IF G < R THEN PRINT "TOO LOW!"
    IF G > R THEN PRINT "TOO HIGH!"
  LOOP UNTIL G = R

  PRINT "CORRECT! YOU WIN!"
  PRINT
  INPUT "PLAY AGAIN? (1=YES, 0=NO)"; A
LOOP UNTIL A <> 1

PRINT "THANKS FOR PLAYING!"
