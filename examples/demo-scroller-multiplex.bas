' ============================================================
'  demo-scroller-multiplex.bas — Approach 6: sprite-pool
'                                "multiplexing" scroller
'
'  A modern take on the classic 8-bit sprite-multiplexing trick:
'  a small fixed pool of persistent sprites (12 of them here)
'  chews through an arbitrarily long message by recycling each
'  sprite when it leaves the left edge of the screen — the sprite
'  jumps back to the right edge and re-skins itself as the next
'  character in the stream. Unlike demo-scroller-sprites.bas,
'  which uses SPRITE STAMP (an append-per-frame cell list), this
'  one uses 12 real persistent DRAWSPRITE slots so each letter
'  has its own SPRITEMODULATE tint and its own sine phase that
'  survives across frames.
'
'  Why "multiplex"? On the C64 / Amiga the hardware sprite count
'  was small (eight) and developers moved sprites vertically
'  between raster lines to get more on screen. We're doing the
'  same idea in the X axis: we have more LETTERS than SPRITES,
'  so we keep reassigning each sprite to the next letter in the
'  queue once it's done its job.
'
'  Uses the bundled 32x32 Amiga bitmap font:
'    scroller_font.png — 10 cols x 6 rows, ASCII 32..91 (upper
'    only). See demo-scroller-sprites.bas for the full layout
'    description.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 0, 0, 0
CLS
DOUBLEBUFFER ON

' --- font geometry (shared with demo-scroller-sprites.bas) ----
TW         = 32
TH         = 32
COLS       = 10
FIRST_CHAR = 32
LAST_CHAR  = 91

' Load the sheet into every pool slot independently. LOADSPRITE
' blocks the interpreter until the render thread finishes the GPU
' upload (see gfx_sprite_wait_gpu_op), so by the time we enter the
' main loop every slot 0..POOL_N-1 is guaranteed ready with its
' tile grid (TW×TH) registered — essential because SPRITEFRAME /
' effective_source_rect silently no-op on a slot whose tile fields
' haven't been set yet, and the default full-sheet source rect
' would render the entire 320×200 font as one giant sprite.
'
' SPRITECOPY would halve the PNG-decode cost but enqueues async —
' the main loop's first few DRAWSPRITE calls can race the copy and
' hit the "whole-sheet fallback" rect. Plain LOADSPRITE per slot
' avoids the race; the OS caches the PNG so loads 2..N are fast.
POOL_N = 12
FOR I = 0 TO POOL_N - 1
  LOADSPRITE I, "scroller_font.png", TW, TH
NEXT
IF SPRITEW(0) = 0 THEN
  COLORRGB 255, 100, 100
  DRAWTEXT 8, 90, "scroller_font.png not found"
  DRAWTEXT 8, 106, "(expected 320x200 RGBA PNG, 32x32 tiles)"
  SLEEP 3000
  END
END IF

' Per-sprite state — parallel arrays. X/Y is the current position,
' MSGI is the message-character index each sprite is currently
' displaying, PH is that sprite's sine-wave phase offset so the
' bounce ripples across the pool instead of moving in lockstep,
' TINT_R/G/B is its persistent per-sprite colour.
DIM SX(POOL_N), SY(POOL_N), MSGI(POOL_N), PH(POOL_N)
DIM TR(POOL_N), TG(POOL_N), TB(POOL_N)

MSG$ = "  * * *  RGC-BASIC 2.0 * * *  SPRITE MULTIPLEXING SCROLLER: 12 REAL PERSISTENT SPRITES, ONE LONG MESSAGE, EACH SLOT RECYCLES WHEN IT LEAVES THE SCREEN.  GREETINGS FROM RETROGAMECODERS.  "
MSG$ = UCASE$(MSG$)
LEN_MSG = LEN(MSG$)

' Space the pool evenly across the visible screen at startup so
' every sprite is on-screen from frame 0 — pause in the first
' second and you'll still see the whole multiplexer lineup.
' Stride = (screen width + one extra cell) / pool size so the
' pool fills 0..319 + a buffer cell about to enter from the
' right. Sprites recycle to SX = 320 (off-screen right) once
' they leave the left edge, so steady-state spacing = stride.
STRIDE = INT((320 + TW) / POOL_N)
QPOS = 0

FOR I = 0 TO POOL_N - 1
  SX(I)   = I * STRIDE
  SY(I)   = 90
  MSGI(I) = QPOS
  PH(I)   = I * 0.4
  QPOS = (QPOS + 1) MOD LEN_MSG
  ' Per-sprite hue, spread around the colour wheel by slot index.
  ' 30 degrees per slot = 12 slots × 30 = full 360 rainbow.
  H = I * 30
  GOSUB HSV_TO_RGB
  TR(I) = HR : TG(I) = HG : TB(I) = HB
  SPRITEMODULATE I, 255, HR, HG, HB
NEXT

T = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  FOR I = 0 TO POOL_N - 1
    ' Move left.
    SX(I) = SX(I) - 3

    ' Recycle when fully off the left edge — jump to the right
    ' edge and claim the next character in the message queue.
    ' This is the "multiplex" step: the same sprite slot now
    ' represents a DIFFERENT letter than a moment ago.
    IF SX(I) < -TW THEN
      SX(I) = 320
      MSGI(I) = QPOS
      QPOS = (QPOS + 1) MOD LEN_MSG
    END IF

    ' Pick the tile index from the message character this slot
    ' is carrying. Non-printable or out-of-range chars fall
    ' through to the space tile.
    C = ASC(MID$(MSG$, MSGI(I) + 1, 1))
    IF C < FIRST_CHAR OR C > LAST_CHAR THEN
      TILE = 0
    ELSE
      TILE = C - FIRST_CHAR
    END IF
    SPRITEFRAME I, TILE + 1

    ' Per-sprite sine bounce. PH(I) offsets each sprite's phase
    ' so the wave travels across the pool.
    BY = SY(I) + INT( SIN( PH(I) + T ) * 18 )

    DRAWSPRITE I, SX(I), BY
  NEXT

  T = T + 0.10

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 6: 12-sprite pool multiplexer"

  VSYNC
LOOP

DOUBLEBUFFER OFF
FOR I = 0 TO POOL_N - 1
  UNLOADSPRITE I
NEXT
SCREEN 0
CLS
PRINT "Thanks for watching."
END

' ============================================================
'  HSV -> RGB helper. H in 0..360, output HR/HG/HB in 0..255.
'  Saturation + value fixed at 1.0 for a full-bright rainbow.
' ============================================================
HSV_TO_RGB:
  HH = H / 60.0
  HI = INT(HH) MOD 6
  FR = HH - INT(HH)
  P = 0
  Q = INT(255 * (1 - FR))
  TT = INT(255 * FR)
  IF HI = 0 THEN HR = 255 : HG = TT  : HB = P
  IF HI = 1 THEN HR = Q   : HG = 255 : HB = P
  IF HI = 2 THEN HR = P   : HG = 255 : HB = TT
  IF HI = 3 THEN HR = P   : HG = Q   : HB = 255
  IF HI = 4 THEN HR = TT  : HG = P   : HB = 255
  IF HI = 5 THEN HR = 255 : HG = P   : HB = Q
  RETURN
