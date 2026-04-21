' ============================================================
'  gfx_music_demo - tracker module playback with track info,
'                   progress bar and VU meter.
'
'  Verbs:
'    LOADMUSIC slot, path$             stream MOD/XM/S3M/IT/OGG/MP3
'    PLAYMUSIC slot                    start (or restart)
'    STOPMUSIC slot                    rewind + stop
'    PAUSEMUSIC slot / RESUMEMUSIC     suspend + continue
'    MUSICLOOP slot, 0 | 1             repeat on end of track
'    MUSICVOLUME slot, 0.0 .. 1.0      per-slot gain
'    UNLOADMUSIC slot                  free the stream
'
'  Functions:
'    MUSICPLAYING(slot)                1 while audible, 0 idle
'    MUSICLENGTH(slot)                 track length in seconds
'    MUSICTIME(slot)                   elapsed seconds, wraps on loop
'    MUSICPEAK()                       0..1 master-mix peak (VU)
'    MUSICTITLE$(slot)                 20-byte MOD title
'    MUSICCHANNELS(slot)               4 / 6 / 8 / ... from tag
'    MUSICPATTERNS(slot)               unique patterns in order table
'    MUSICORDERS(slot)                 song length (order entries)
'    MUSICSAMPLECOUNT(slot)            31 for classic MODs
'    MUSICSAMPLENAME$(slot, idx)       22-byte sample record name
'
'  Browsers block audio until the user clicks or presses a key,
'  so we wait for a keypress before touching raudio. All bundled
'  modules are Public Domain — see examples/music/LICENSES.md.
'
'  Keys: 1..9 switch track, SPACE pause, S stop, L loop,
'        + / - volume, Q quit
' ============================================================

SCREEN 4
BACKGROUNDRGB 12, 12, 24
CLS
DOUBLEBUFFER ON

DIM PATH$(9), NAME$(9)
PATH$(1) = "music/drozerix_ai_renaissance.mod" : NAME$(1) = "AI Renaissance - Drozerix"
PATH$(2) = "music/8bit_castle.mod"              : NAME$(2) = "8-bit Castle - Jam"
PATH$(3) = "music/jam_highway_encounter.mod"    : NAME$(3) = "Highway Encounter - Jam"
PATH$(4) = "music/drozerix_-_neon_techno.mod"   : NAME$(4) = "Neon Techno - Drozerix"
PATH$(5) = "music/jam_-_latenightcoffee.mod"    : NAME$(5) = "Late Night Coffee - JAM"
PATH$(6) = "music/jam_-_heatwave_cruise.mod"    : NAME$(6) = "Heatwave Cruise - JAM"
PATH$(7) = "music/musix-pleasant.mod"           : NAME$(7) = "pleasant2 - m0d"
PATH$(8) = "music/musix-heaven-rmx.mod"         : NAME$(8) = "heavens open - m0d"
PATH$(9) = "music/kc-dancinonamiga.mod"         : NAME$(9) = "Dancin' On Amiga - Katie Cadet"

' One loaded stream at a time — always slot 0 (gfx_sound caps at
' GFX_MUSIC_MAX_SLOTS = 8, so 9 tracks can't each own a slot). The
' UI-visible "track number" TRACK is 1..9 and picks PATH$(TRACK);
' the actual LOADMUSIC / PLAYMUSIC slot stays at 0.
SLOT = 0
TRACK = -1
VOL     = 0.8
PAUSED  = 0
LOOPING = 1

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  IF KEYPRESS(27) THEN EXIT

  NEW_TRACK = -1
  FOR K = 1 TO 9
    IF KEYPRESS(ASC(STR$(K))) THEN NEW_TRACK = K
  NEXT

  IF NEW_TRACK <> -1 AND NEW_TRACK <> TRACK THEN
    IF TRACK <> -1 THEN
      STOPMUSIC SLOT
      UNLOADMUSIC SLOT
    END IF
    TRACK = NEW_TRACK
    LOADMUSIC SLOT, PATH$(TRACK)
    MUSICLOOP   SLOT, LOOPING
    MUSICVOLUME SLOT, VOL
    PLAYMUSIC   SLOT
    PAUSED = 0
  END IF

  IF TRACK <> -1 THEN
    IF KEYPRESS(ASC(" ")) THEN
      IF PAUSED = 0 THEN PAUSEMUSIC SLOT : PAUSED = 1 ELSE RESUMEMUSIC SLOT : PAUSED = 0
    END IF
    IF KEYPRESS(ASC("S")) THEN STOPMUSIC SLOT : PAUSED = 0
    IF KEYPRESS(ASC("L")) THEN
      IF LOOPING = 1 THEN LOOPING = 0 ELSE LOOPING = 1
      MUSICLOOP SLOT, LOOPING
    END IF
    IF KEYPRESS(ASC("+")) OR KEYPRESS(ASC("=")) THEN
      VOL = VOL + 0.1 : IF VOL > 1.0 THEN VOL = 1.0
      MUSICVOLUME SLOT, VOL
    END IF
    IF KEYPRESS(ASC("-")) THEN
      VOL = VOL - 0.1 : IF VOL < 0.0 THEN VOL = 0.0
      MUSICVOLUME SLOT, VOL
    END IF
  END IF

  CLS

  COLORRGB 240, 240, 255
  DRAWTEXT 16, 16, "RGC-BASIC MUSIC TRACKER DEMO", 1, -1, 0, 2
  COLORRGB 255, 220, 120
  DRAWTEXT 16, 52, "Press 1..9 to load + play a track"
  COLORRGB 180, 180, 220
  DRAWTEXT 16, 68, "(browsers block autoplay until a user gesture)"

  ' two-column track list
  COLORRGB 200, 200, 230
  FOR K = 1 TO 5
    DRAWTEXT 16,  96 + (K-1) * 14, STR$(K) + "  " + NAME$(K)
  NEXT
  FOR K = 6 TO 9
    DRAWTEXT 320, 96 + (K-6) * 14, STR$(K) + "  " + NAME$(K)
  NEXT

  COLORRGB 180, 180, 220
  DRAWTEXT 16, 180, "SPACE pause   S stop   L loop   + / - volume   Q quit"

  IF TRACK = -1 THEN
    COLORRGB 200, 255, 200
    DRAWTEXT 16, 220, "IDLE - press 1..9"
  ELSE
    ' --- now-playing panel ---
    COLORRGB 120, 200, 255
    T$ = MUSICTITLE$(SLOT)
    IF LEN(T$) = 0 THEN T$ = NAME$(TRACK)
    DRAWTEXT 16, 220, "NOW PLAYING: " + T$

    COLORRGB 200, 255, 200
    MSG$ = "TRACK " + STR$(TRACK)
    IF PAUSED = 1 THEN MSG$ = MSG$ + "  [PAUSED]"
    IF LOOPING = 1 THEN MSG$ = MSG$ + "  LOOP" ELSE MSG$ = MSG$ + "  ONE-SHOT"
    IF MUSICPLAYING(SLOT) = 1 THEN MSG$ = MSG$ + "  PLAYING" ELSE MSG$ = MSG$ + "  IDLE"
    DRAWTEXT 16, 236, MSG$

    COLORRGB 180, 200, 255
    INFO$ = "CH " + STR$(MUSICCHANNELS(SLOT))
    INFO$ = INFO$ + "   PATTERNS " + STR$(MUSICPATTERNS(SLOT))
    INFO$ = INFO$ + "   ORDERS " + STR$(MUSICORDERS(SLOT))
    INFO$ = INFO$ + "   SAMPLES " + STR$(MUSICSAMPLECOUNT(SLOT))
    DRAWTEXT 16, 252, INFO$

    ' elapsed / length
    TT = MUSICTIME(SLOT)
    TL = MUSICLENGTH(SLOT)
    TM = INT(TT / 60) : TS = INT(TT) MOD 60
    LM = INT(TL / 60) : LS = INT(TL) MOD 60
    TPAD$ = "" : IF TS < 10 THEN TPAD$ = "0"
    LPAD$ = "" : IF LS < 10 THEN LPAD$ = "0"
    TIMEMSG$ = STR$(TM) + ":" + TPAD$ + STR$(TS)
    IF TL > 0 THEN TIMEMSG$ = TIMEMSG$ + " / " + STR$(LM) + ":" + LPAD$ + STR$(LS)
    COLORRGB 200, 220, 255
    DRAWTEXT 16, 272, TIMEMSG$

    ' progress bar
    COLORRGB 60, 60, 100
    RECT 16, 292 TO 623, 304
    IF TL > 0 THEN
      P = TT / TL
      IF P > 1.0 THEN P = 1.0
      W = INT(P * 605)
      COLORRGB 120, 200, 255
      FILLRECT 18, 294 TO 18 + W, 302
    END IF

    ' VU meter — 32 bars driven by MUSICPEAK (0..1)
    COLORRGB 180, 200, 220
    DRAWTEXT 16, 316, "VU"
    PK = MUSICPEAK()
    LIT = INT(PK * 32)
    IF LIT > 32 THEN LIT = 32
    FOR I = 0 TO 31
      BX = 48 + I * 18
      IF I < LIT THEN
        IF I < 22 THEN
          COLORRGB 80, 220, 80
        ELSE
          IF I < 28 THEN
            COLORRGB 255, 220, 80
          ELSE
            COLORRGB 255, 80, 80
          END IF
        END IF
      ELSE
        COLORRGB 40, 40, 60
      END IF
      FILLRECT BX, 316 TO BX + 14, 340
    NEXT

    COLORRGB 180, 200, 220
    DRAWTEXT 16, 352, "VOL"
    VBARS = INT(VOL * 32 + 0.5)
    FOR I = 0 TO 31
      BX = 48 + I * 18
      IF I < VBARS THEN COLORRGB 200, 180, 255 ELSE COLORRGB 40, 40, 60
      FILLRECT BX, 352 TO BX + 14, 364
    NEXT

    ' first few MOD sample names (aka tracker "liner notes")
    COLORRGB 180, 200, 220
    DRAWTEXT 16, 376, "Samples:"
    SN$ = ""
    FOR I = 0 TO 3
      S$ = MUSICSAMPLENAME$(SLOT, I)
      IF LEN(S$) > 0 THEN
        IF LEN(SN$) > 0 THEN SN$ = SN$ + "  |  "
        SN$ = SN$ + S$
      END IF
    NEXT
    IF LEN(SN$) > 60 THEN SN$ = LEFT$(SN$, 60) + ".."
    DRAWTEXT 88, 376, SN$
  END IF

  VSYNC
LOOP

DOUBLEBUFFER OFF
IF TRACK <> -1 THEN STOPMUSIC SLOT
