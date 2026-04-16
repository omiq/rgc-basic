#OPTION CHARSET PET-LOWER
BACKGROUND LIGHTBLUE
COLOUR BLACK
S = 0
X = 0
Y = 50
M = 0
CX=0
CY=0
MAX_MSG=2


LOADSPRITE 0, "sky.png"
SPRITEMODULATE 0, 35, 255, 255, 255, 0.5
SPRITECOPY 0,0
SPRITECOPY 0,2
LOADSPRITE 1, "clouds.png"
SPRITECOPY 1,3




S=4
LOADSPRITE S, "rgc-logo-large.png"
LOADSPRITE S+1, "rgc-logo-large.png"

SPRITEMODULATE S, 255, 255, 255, 255, 0.40
SPRITEMODULATE S+1, 35, 0, 0, 0, 0.40



DRAWSPRITE S, (RND(-1)*320)-32, (RND(-1)*200)-32
DRAWSPRITE S+1, SPRITEX(S)+4, SPRITEY(S)+4

TIMER 1,100,MOV
TIMER 2,1000,MSG
TIMER 3,10,CLOUD_MOVE

DIM MSGLINE$(4)
MSGLINE$(0)="Welcome"
MSGLINE$(1)="to the"
MSGLINE$(2)="Retro Game Coders IDE!"


DO
 
 REM Sleep does not delay the timers, just the main loop.
 SLEEP 1000
 
 
LOOP

Function MOV()

  DRAWSPRITE S,  INT(32 * SIN(X / 3.14)), Y
  DRAWSPRITE S+1, INT(32 * SIN(X / 3.14))+3, Y+3
  X=X+1
  IF X > 628 THEN X=0

End Function

Function MSG()

 REST_OF_LINE=40-LEN(MSGLINE$(M))
 TEXTAT 0,3,STRING(REST_OF_LINE/2,32)+MSGLINE$(M)+STRING(REST_OF_LINE/2,32)

 M=M+1
 IF M>MAX_MSG THEN M=0
 
End Function

Function CLOUD_MOVE()

  REM Sky layer (slow) — two sprites wrapping at 320px
  SX = CX MOD 320
  DRAWSPRITE 0, SX, CY, 0
  DRAWSPRITE 2, SX - 320, CY, 0

  REM Cloud layer (1.5x faster) — two sprites wrapping independently
  FX = INT(CX * 1.5) MOD 640
  DRAWSPRITE 1, FX, CY, 1
  DRAWSPRITE 3, FX - 640, CY, 1

  CX = CX + 1

End Function