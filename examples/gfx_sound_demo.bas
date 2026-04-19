' ============================================================
'  gfx_sound_demo - single-voice WAV playback
'
'  LOADSOUND slot, "file.wav"    preload into slot (0..31)
'  PLAYSOUND slot                fire and forget (non-blocking)
'  STOPSOUND                     halt whichever voice is playing
'  UNLOADSOUND slot              free slot
'  SOUNDPLAYING()                1 while audible, 0 otherwise
'
'  Single voice for v1 - starting another PLAYSOUND stops the
'  previous cue. Pair with KEYPRESS/ISMOUSEBUTTONPRESSED so the
'  first sound fires after a user gesture (browsers keep the
'  AudioContext suspended until then).
'
'  Keys: B = blip, X = boom, S = stop, Q = quit
' ============================================================

SCREEN 1
BACKGROUND 0

LOADSOUND 0, "blip.wav"
LOADSOUND 1, "boom.wav"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("B")) THEN PLAYSOUND 0
  IF KEYPRESS(ASC("X")) THEN PLAYSOUND 1
  IF KEYPRESS(ASC("S")) THEN STOPSOUND

  CLS
  COLOR 7  : DRAWTEXT  8,  8,  "SOUND DEMO", 2
  COLOR 10 : DRAWTEXT  8, 40,  "B = BLIP", 1
  COLOR 10 : DRAWTEXT  8, 54,  "X = BOOM", 1
  COLOR 10 : DRAWTEXT  8, 68,  "S = STOP", 1
  COLOR 14 : DRAWTEXT  8, 90,  "Q = QUIT", 1
  IF SOUNDPLAYING() THEN
    COLOR 13 : DRAWTEXT 8, 120, "PLAYING ...", 1
  ELSE
    COLOR 11 : DRAWTEXT 8, 120, "IDLE", 1
  END IF

  SLEEP 1
LOOP

STOPSOUND
UNLOADSOUND 0
UNLOADSOUND 1
