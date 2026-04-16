DIM X(255)
DIM Y(255)

REM Load the chick sprite
LOADSPRITE 0, "chick.png"
FOR S=0 TO 64
 SPRITECOPY 0, S
 X(S)=(RND(1)*320)-32
 Y(S)=(RND(1)*200)-32
NEXT S

REM Jiggle the chicks around
DO
 FOR S=0 TO 64
  DRAWSPRITE S, X(S), Y(S)
  XM=-4+RND(1)*8
  YM=-4+RND(1)*8
  X(S)=X(S)+XM
  Y(S)=Y(S)+YM
 NEXT S
LOOP

