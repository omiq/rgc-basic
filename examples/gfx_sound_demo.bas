' ============================================================
'  gfx_sound_demo - single-voice WAV playback
'
'  LOADSOUND slot, "file.wav"    preload into slot (0..31)
'  PLAYSOUND slot                fire and forget (non-blocking)
'  STOPSOUND                     halt whichever voice is playing
'  UNLOADSOUND slot              free slot
'  SOUNDPLAYING()                1 while audible, 0 otherwise
'
'  Single voice - starting another PLAYSOUND stops the previous
'  cue. Pair with KEYPRESS so the first sound fires after a user
'  gesture (browsers keep the AudioContext suspended until then).
'
'  COLOUR NOTE: the bitmap plane is 1bpp - COLOR sets a single
'  renderer-side pen register read once per composite, so changing
'  it mid-frame retints EVERYTHING drawn that tick. This demo
'  picks one pen.
'
'  Keys: B = blip (short), X = boom (short), L = siren (long),
'        S = stop, Q = quit
' ============================================================

SCREEN 1
BACKGROUND 0
COLOR 14                    ' single pen for the whole frame

LOADSOUND 0, "blip.wav"
LOADSOUND 1, "boom.wav"
LOADSOUND 2, "siren.wav"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(ASC("B")) THEN PLAYSOUND 0
  IF KEYPRESS(ASC("X")) THEN PLAYSOUND 1
  IF KEYPRESS(ASC("L")) THEN PLAYSOUND 2
  IF KEYPRESS(ASC("S")) THEN STOPSOUND

  CLS
  DRAWTEXT  8,  8, "SOUND DEMO", 2
  DRAWTEXT  8, 36, "B = BLIP (SHORT)", 1
  DRAWTEXT  8, 50, "X = BOOM (SHORT)", 1
  DRAWTEXT  8, 64, "L = SIREN (LONG)", 1
  DRAWTEXT  8, 80, "S = STOP", 1
  DRAWTEXT  8, 96, "Q = QUIT", 1
  IF SOUNDPLAYING() THEN
    DRAWTEXT  8, 130, "PLAYING ...", 1
  ELSE
    DRAWTEXT  8, 130, "IDLE", 1
  END IF

  SLEEP 1
LOOP

STOPSOUND
UNLOADSOUND 0
UNLOADSOUND 1
UNLOADSOUND 2
