#OPTION CHARSET PET-LOWER

' INITIALISE VARS
SCREEN 2
BACKGROUND LIGHTBLUE
COLOUR BLACK
S = 0
X = 0
Y = 50
M = 0
CX=0
CY=0
MAX_MSG=2
CLS



' Scroll state. Start with the strip just off the right edge so
' the text reads in from the side. T advances each frame and
' drives the sine wave for the vertical bounce; scale it to
' control the wobble speed (bigger = faster oscillation).
SCSX  = -320
T   = 0.0
BASE_Y = 120                ' centre line of the scroller
AMP    = 24                ' pixels of vertical swing (up + down)
FREQ   = 0.05              ' radians per frame — ~0.05 = gentle


' Bake sky tint via a spare slot (SPRITECOPY src!=dst for best compat)
LOADSPRITE 6, "sky.png"
SPRITEMODULATE 6, 35, 255, 255, 255, 0.5
SPRITECOPY 6, 0
SPRITECOPY 6, 2
UNLOADSPRITE 6
LOADSPRITE 1, "clouds.png"
SPRITECOPY 1, 3

' BACKGROUND MUSIC TRACKER MOD
LOADMUSIC 0, "music/drozerix_-_neon_techno.mod" 
MUSICLOOP   0, 1
MUSICVOLUME 0, 0.5
PLAYMUSIC   0

' SPRITES
S=4
LOADSPRITE S, "rgc-logo-large.png"
LOADSPRITE S+1, "rgc-logo-large.png"

' VISUAL TWEAKS
SPRITEMODULATE S, 255, 255, 255, 255, 0.40
SPRITEMODULATE S+1, 35, 0, 0, 0, 0.40

' INITIAL DRAW
DRAWSPRITE S, (RND(-1)*320)-32, (RND(-1)*200)-32
DRAWSPRITE S+1, SPRITEX(S)+4, SPRITEY(S)+4

' LOADSPRITE path is a literal quoted string so the IDE's asset
' auto-preload regex sees it and fetches the PNG into MEMFS
' before the program runs.
LOADSPRITE S+2, "scroller_strip.png"
' Read the strip dimensions from ITS slot (S+2), not slot 0 —
' slot 0 is the tinted sky (320 px wide) and would make the
' scroller wrap every 320 px instead of travelling its full length.
STRIP_W = SPRITEW(S+2)
STRIP_H = SPRITEH(S+2)

' TIMERS FOR "MULTITASKING"
TIMER 1,100,MOV
TIMER 2,1000,MSG
TIMER 3,10,CLOUD_MOVE
TIMER 4,10,SCR

' REPEATING MESSAGE
DIM MSGLINE$(4)
MSGLINE$(0)="Welcome"
MSGLINE$(1)="to the"
MSGLINE$(2)="Retro Game Coders IDE!"


' MAIN LOOP
DO
 
 VSYNC
 
 
LOOP

Function MOV()

  DRAWSPRITE S,  INT(32 * SIN(X / 3.14)), Y, 1
  DRAWSPRITE S+1, INT(32 * SIN(X / 3.14))+3, Y+3, 0
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
  DRAWSPRITE 0, SX, CY, -2
  DRAWSPRITE 2, SX - 320, CY, -2

  REM Cloud layer (1.5x faster) — two sprites wrapping independently
  FX = INT(CX * 1.5) MOD 640
  DRAWSPRITE 1, FX, CY, -1
  DRAWSPRITE 3, FX - 640, CY, -1

  CX = CX + 1

End Function

Function SCR()

  ' Horizontal scroll + sine bounce. DRAWSPRITE positions the
  ' whole strip each frame; the engine clips to the framebuffer
  ' so negative X reveals later pixels of the strip. The strip
  ' moves as one rigid body — for a "per-letter wave" effect see
  ' demo-scroller-sprites.bas (each character stamped on its own
  ' sine phase).
  YY = BASE_Y + INT( SIN(T) * AMP )
  DRAWSPRITE S+2, -SCSX, YY,12

  ' Wrap: once the strip has fully exited the left edge, restart
  ' from the right. Add a ~320 px gap between loops so the start
  ' is visibly distinct from the end.
  IF SCSX > STRIP_W THEN SCSX = -320

  SCSX = SCSX + 2
  T  = T  + FREQ



End Function