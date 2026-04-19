' ============================================================
'  gfx_anim_demo - ANIMFRAME auto-cycles a sprite's tile index
'
'  boing_sheet.png is 768x64 (12 frames at 64x64) showing an
'  Amiga-style boing ball rolling through one cycle.
'  ANIMFRAME(1, 12, 4) cycles 12 frames at 15 FPS (60/4).
'  SPRITE FRAME sets which tile DRAWSPRITE uses when called
'  without explicit crop args.
'
'  Keys: Q quit
' ============================================================

SPRITE LOAD 0, "boing_sheet.png", 64, 64

X = 128 : Y = 68

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  CLS
  SPRITE FRAME 0, ANIMFRAME(1, 12, 4)
  DRAWSPRITE 0, X, Y, 100
  VSYNC
LOOP
