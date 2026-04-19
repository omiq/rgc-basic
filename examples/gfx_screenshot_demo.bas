' ============================================================
'  gfx_screenshot_demo - IMAGE GRAB + IMAGE SAVE PNG tour
'
'  Shows the two supported IMAGE SAVE paths:
'    1. Press S to grab the fully-composited framebuffer and
'       save it as screenshot.png (full palette + alpha).
'    2. A commented-out per-frame recorder at the bottom
'       dumps frame_00001.png, frame_00002.png, ... for ffmpeg:
'         ffmpeg -framerate 60 -i frame_%05d.png \
'                -c:v libx264 -pix_fmt yuv420p out.mp4
'
'  Assets: examples/ship.png (32x32 alpha sprite)
'  Keys:   WASD move, S screenshot, Q quit
' ============================================================

SCREEN 1
BACKGROUND 0
SPRITE LOAD 0, "ship.png"

X = 144 : Y = 84
SHOT = 0                                  ' screenshot counter

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYDOWN(ASC("A")) THEN X = X - 2
  IF KEYDOWN(ASC("D")) THEN X = X + 2
  IF KEYDOWN(ASC("W")) THEN Y = Y - 2
  IF KEYDOWN(ASC("S")) THEN GOSUB TakeScreenshot
  IF X < 0   THEN X = 0
  IF X > 288 THEN X = 288
  IF Y < 0   THEN Y = 0
  IF Y > 168 THEN Y = 168

  CLS
  ' Scene: bitmap + text + sprite, so the grab proves everything is captured
  COLOR 7
  FILLCIRCLE 60, 100, 20
  COLOR 1
  DRAWTEXT 8, 8,   "SCREENSHOT DEMO"
  DRAWTEXT 8, 180, "WASD MOVE  S SHOT  Q QUIT"
  DRAWTEXT 8, 190, "SAVED: " + STR$(SHOT)
  DRAWSPRITE 0, X, Y, 100

  VSYNC
LOOP

END

' ------------------------------------------------------------

TakeScreenshot:
  ' One VSYNC ensures the frame being saved includes the current
  ' sprite and text. Grab services on the render thread, reads the
  ' composited target, writes RGBA into slot 1. SAVE picks PNG from
  ' the .png extension and writes the slot's RGBA buffer direct.
  VSYNC
  IMAGE GRAB 1, 0, 0, 320, 200
  SHOT = SHOT + 1
  PATH$ = "screenshot_" + RIGHT$("0000" + STR$(SHOT), 4) + ".png"
  IMAGE SAVE 1, PATH$
  ' Small debounce so a held key doesn't fire 60 shots/sec
  FOR D = 1 TO 20 : VSYNC : NEXT D
RETURN

' ------------------------------------------------------------
' Per-frame recorder (uncomment to capture every frame).
' Writes frame_00001.png, frame_00002.png, ...
'
' N = 0
' DO
'   ' ... your per-frame render here ...
'   VSYNC
'   IMAGE GRAB 1, 0, 0, 320, 200
'   N = N + 1
'   IMAGE SAVE 1, "frame_" + RIGHT$("00000" + STR$(N), 5) + ".png"
'   IF N >= 300 THEN EXIT         ' 5 seconds at 60 fps
' LOOP
'
' Encode with ffmpeg:
'   ffmpeg -framerate 60 -i frame_%05d.png \
'          -c:v libx264 -pix_fmt yuv420p screen_capture.mp4
' ------------------------------------------------------------
