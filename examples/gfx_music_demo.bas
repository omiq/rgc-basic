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
'  Browsers block audio until the user clicks or presses a key,
'  so the demo waits for a keypress before touching raudio. Only
'  one track is loaded at a time (switching tracks unloads the
'  previous slot then loads the next) so Chrome's autoplay policy
'  sees a clean gesture-driven init.
'
'  All three bundled modules are Public Domain (see
'  examples/music/LICENSES.md).
'
'  Keys: 1/2/3 switch, SPACE pause, S stop, L loop, +/- volume, Q quit
' ============================================================

SCREEN 4
BACKGROUNDRGB 16, 16, 32
CLS

COLORRGB 240, 240, 255
DRAWTEXT 16, 32, "RGC-BASIC MUSIC TRACKER DEMO", 1, -1, 0, 2
COLORRGB 255, 220, 120
DRAWTEXT 16, 80,  "Press 1, 2 or 3 to load + play a track"
COLORRGB 180, 180, 220
DRAWTEXT 16, 104, "(browsers block autoplay until a user gesture)"
DRAWTEXT 16, 140, "1  AI Renaissance     - Drozerix"
DRAWTEXT 16, 156, "2  8-bit Castle"
DRAWTEXT 16, 172, "3  Highway Encounter  - Jam"
DRAWTEXT 16, 204, "SPACE pause   S stop   L loop   + / - volume   Q quit"
DRAWTEXT 16, 240, "All three tracks are Public Domain"
DRAWTEXT 16, 256, "(see examples/music/LICENSES.md)"

CURRENT = -1
VOL     = 0.8
PAUSED  = 0
LOOPING = 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  NEW_TRACK = -1
  IF KEYPRESS(ASC("1")) THEN NEW_TRACK = 0
  IF KEYPRESS(ASC("2")) THEN NEW_TRACK = 1
  IF KEYPRESS(ASC("3")) THEN NEW_TRACK = 2

  IF NEW_TRACK <> -1 AND NEW_TRACK <> CURRENT THEN
    IF CURRENT <> -1 THEN
      STOPMUSIC CURRENT
      UNLOADMUSIC CURRENT
    END IF
    CURRENT = NEW_TRACK
    IF CURRENT = 0 THEN LOADMUSIC 0, "music/drozerix_ai_renaissance.mod"
    IF CURRENT = 1 THEN LOADMUSIC 1, "music/8bit_castle.mod"
    IF CURRENT = 2 THEN LOADMUSIC 2, "music/jam_highway_encounter.mod"
    MUSICLOOP   CURRENT, LOOPING
    MUSICVOLUME CURRENT, VOL
    PLAYMUSIC   CURRENT
    PAUSED = 0
  END IF

  IF CURRENT <> -1 THEN
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
  END IF

  COLORRGB 16, 16, 32 : FILLRECT 0, 360 TO 639, 399
  COLORRGB 200, 255, 200
  IF CURRENT = -1 THEN
    DRAWTEXT 16, 372, "IDLE - press 1, 2 or 3"
  ELSE
    MSG$ = "TRACK " + STR$(CURRENT) + "   VOL " + STR$(VOL)
    IF PAUSED = 1 THEN MSG$ = MSG$ + "   [PAUSED]"
    IF LOOPING = 1 THEN MSG$ = MSG$ + "   LOOP" ELSE MSG$ = MSG$ + "   ONE-SHOT"
    IF MUSICPLAYING(CURRENT) = 1 THEN MSG$ = MSG$ + "   PLAYING" ELSE MSG$ = MSG$ + "   IDLE"
    DRAWTEXT 16, 372, MSG$
  END IF

  SLEEP 3
LOOP

IF CURRENT <> -1 THEN STOPMUSIC CURRENT
