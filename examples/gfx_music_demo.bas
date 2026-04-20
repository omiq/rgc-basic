' ============================================================
'  gfx_music_demo - tracker module playback
'
'  LOADMUSIC slot, path$           stream MOD / XM / S3M / IT
'  PLAYMUSIC slot                  start (or restart)
'  STOPMUSIC slot                  rewind + stop
'  PAUSEMUSIC slot / RESUMEMUSIC   suspend + continue
'  MUSICLOOP slot, 0 | 1           repeat on end of track
'  MUSICVOLUME slot, 0.0 .. 1.0    per-slot gain
'  MUSICPLAYING(slot)              1 while audible, 0 idle
'
'  raylib's raudio decoder pumps each loaded stream once per
'  frame automatically — BASIC programs just issue the verbs,
'  no UpdateMusicStream call needed.
'
'  All three bundled modules are Public Domain (see
'  examples/music/LICENSES.md).
'
'  Keys: 1/2/3 switch track, SPACE pause/resume, S stop, L toggle loop,
'        + / - volume, Q quit
' ============================================================

SCREEN 4
BACKGROUNDRGB 16, 16, 32
CLS

LOADMUSIC 0, "music/drozerix_ai_renaissance.mod"
LOADMUSIC 1, "music/8bit_castle.mod"
LOADMUSIC 2, "music/jam_highway_encounter.mod"

MUSICLOOP 0, 1 : MUSICVOLUME 0, 0.8
MUSICLOOP 1, 1 : MUSICVOLUME 1, 0.8
MUSICLOOP 2, 1 : MUSICVOLUME 2, 0.8

CURRENT = 0
VOL     = 0.8
PAUSED  = 0
LOOPING = 1

PLAYMUSIC CURRENT

COLORRGB 240, 240, 255
DRAWTEXT 16, 16,  "RGC-BASIC MUSIC TRACKER DEMO", 1, -1, 0, 2
COLORRGB 180, 180, 220
DRAWTEXT 16, 56,  "1  AI Renaissance        - Drozerix"
DRAWTEXT 16, 72,  "2  8-bit Castle"
DRAWTEXT 16, 88,  "3  Highway Encounter     - Jam"
DRAWTEXT 16, 120, "SPACE  pause / resume"
DRAWTEXT 16, 136, "S      stop (rewind)"
DRAWTEXT 16, 152, "L      toggle loop"
DRAWTEXT 16, 168, "+ / -  volume"
DRAWTEXT 16, 184, "Q      quit"
DRAWTEXT 16, 220, "All three tracks are Public Domain"
DRAWTEXT 16, 236, "(see examples/music/LICENSES.md)"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT
  IF KEYPRESS(ASC("1")) THEN STOPMUSIC CURRENT : CURRENT = 0 : PAUSED = 0 : PLAYMUSIC CURRENT
  IF KEYPRESS(ASC("2")) THEN STOPMUSIC CURRENT : CURRENT = 1 : PAUSED = 0 : PLAYMUSIC CURRENT
  IF KEYPRESS(ASC("3")) THEN STOPMUSIC CURRENT : CURRENT = 2 : PAUSED = 0 : PLAYMUSIC CURRENT
  IF KEYPRESS(ASC(" ")) THEN
    IF PAUSED = 0 THEN PAUSEMUSIC CURRENT : PAUSED = 1 ELSE RESUMEMUSIC CURRENT : PAUSED = 0
  END IF
  IF KEYPRESS(ASC("S")) THEN STOPMUSIC CURRENT : PAUSED = 0
  IF KEYPRESS(ASC("L")) THEN
    IF LOOPING = 1 THEN LOOPING = 0 ELSE LOOPING = 1
    MUSICLOOP CURRENT, LOOPING
  END IF
  IF KEYPRESS(ASC("+")) OR KEYPRESS(ASC("=")) THEN
    VOL = VOL + 0.1 : IF VOL > 1.0 THEN VOL = 1.0
    MUSICVOLUME CURRENT, VOL
  END IF
  IF KEYPRESS(ASC("-")) THEN
    VOL = VOL - 0.1 : IF VOL < 0.0 THEN VOL = 0.0
    MUSICVOLUME CURRENT, VOL
  END IF

  ' Status line — clear + redraw each frame so state stays current.
  COLORRGB 16, 16, 32 : FILLRECT 0, 360 TO 639, 399
  COLORRGB 200, 255, 200
  MSG$ = "TRACK " + STR$(CURRENT) + "   VOL " + STR$(VOL)
  IF PAUSED = 1 THEN MSG$ = MSG$ + "   [PAUSED]"
  IF LOOPING = 1 THEN MSG$ = MSG$ + "   LOOP" ELSE MSG$ = MSG$ + "   ONE-SHOT"
  IF MUSICPLAYING(CURRENT) = 1 THEN MSG$ = MSG$ + "   PLAYING" ELSE MSG$ = MSG$ + "   IDLE"
  DRAWTEXT 16, 372, MSG$
  SLEEP 1
LOOP

STOPMUSIC 0
STOPMUSIC 1
STOPMUSIC 2
