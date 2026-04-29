' ============================================================
'  hud_demo.bas — HUD panel + attribute icons + counters
'
'  Demonstrates the canonical Zelda / SNES-RPG HUD pattern:
'
'    1. SCREEN 2 (RGBA) — required for OVERLAY redirect to work.
'    2. Panel PNG loaded into an RGBA IMAGE slot, blended into the
'       overlay each frame so it sits ABOVE world sprites + tiles.
'    3. Icon sheet loaded as a 16x16 tile-sheet sprite, stamped
'       once per attribute (hearts, keys, coins).
'    4. DRAWTEXT mixed with icons for numeric counters ("x3").
'
'  Controls:  H  +1 heart                K  +1 key
'             R  +1 coin                D  -1 damage (heart)
'             Q  quit
'
'  Asset list (the IDE preloader scans these literals into MEMFS):
'    hud_panel.png   — 320x24 RGBA strip, semi-transparent if you want
'                       the world peeking through behind it.
'    hud_icons.png   — 64x16 sheet (4 icons, 16x16 each):
'                       cell 1: heart full
'                       cell 2: heart empty
'                       cell 3: key
'                       cell 4: coin
'
'  Until you have art, the demo paints solid coloured stand-ins so
'  the layout is visible. Replace USE_PNG = 0 with USE_PNG = 1 once
'  the PNGs are in the same folder.
' ============================================================

' Asset preload hints — the IDE asset scanner picks up quoted string
' literals in LOAD calls. Listing them once near the top guarantees
' the preloader stages the files before the program runs even when
' the actual LOAD line is conditional or inside a function.
DIM ASSET_HINT$(1)
ASSET_HINT$(0) = "hud_panel.png"
ASSET_HINT$(1) = "hud_icons.png"

USE_PNG = 0                              ' flip to 1 when art exists

SCREEN 2
DOUBLEBUFFER ON
BACKGROUNDRGB 12, 12, 28
CLS

IF USE_PNG = 1 THEN
  ' Panel goes into an RGBA IMAGE slot so its alpha survives into
  ' IMAGE BLEND. SPRITE LOAD also works but IMAGE BLEND lets us
  ' position pixel-perfectly inside the overlay buffer.
  IMAGE CREATE 1, 320, 24
  IMAGE LOAD 1, "hud_panel.png"
  ' Icon sheet — 4 cells of 16x16 in a row.
  SPRITE LOAD 5, "hud_icons.png", 16, 16
END IF

' --- player attributes --- (drive the HUD)
HEARTS_MAX = 3
HEARTS = 3
KEYS = 0
COINS = 0

' --- key codes ---
KQ = 81 : KH = 72 : KK = 75 : KR = 82 : KD = 68

' Rising-edge key state for "press once per tap" semantics. KEYDOWN
' would bump every frame the key is held — typing H once would jump
' hearts to max instantly. KEYPRESS is the rgc-basic helper for this
' but we implement it inline for clarity.
PREV_H = 0 : PREV_K = 0 : PREV_R = 0 : PREV_D = 0

DO
  IF KEYDOWN(KQ) THEN EXIT

  ' --- input: bump counters on rising edge ---
  CUR_H = KEYDOWN(KH)
  IF CUR_H = 1 AND PREV_H = 0 AND HEARTS < HEARTS_MAX THEN HEARTS = HEARTS + 1
  PREV_H = CUR_H

  CUR_K = KEYDOWN(KK)
  IF CUR_K = 1 AND PREV_K = 0 THEN KEYS = KEYS + 1
  PREV_K = CUR_K

  CUR_R = KEYDOWN(KR)
  IF CUR_R = 1 AND PREV_R = 0 THEN COINS = COINS + 1
  PREV_R = CUR_R

  CUR_D = KEYDOWN(KD)
  IF CUR_D = 1 AND PREV_D = 0 AND HEARTS > 0 THEN HEARTS = HEARTS - 1
  PREV_D = CUR_D

  ' --- world (placeholder so the HUD has something to sit on top of) ---
  CLS
  COLORRGB 60, 90, 140
  FILLRECT 0, 30 TO 319, 199
  COLORRGB 240, 200, 100
  FILLCIRCLE 160, 110, 30                ' "sun"
  COLORRGB 255, 255, 255
  DRAWTEXT 80, 188, "WORLD GOES HERE"

  ' --- HUD: paint into the overlay so it sits above the world ---
  OVERLAY ON
    OVERLAY CLS                          ' transparent every frame

    ' Panel background — PNG if available, otherwise solid strip.
    IF USE_PNG = 1 THEN
      IMAGE BLEND 1, 0, 0, 320, 24 TO 0, 0, 0
    ELSE
      COLORRGB 0, 0, 0, 220
      FILLRECT 0, 0 TO 319, 23
      COLORRGB 80, 80, 100
      LINE 0, 23 TO 319, 23              ' bottom border
    END IF

    ' Hearts — one icon per max-heart, full or empty by current count.
    FOR I = 0 TO HEARTS_MAX - 1
      IF I < HEARTS THEN
        FRAME = 1                        ' full
      ELSE
        FRAME = 2                        ' empty
      END IF
      IF USE_PNG = 1 THEN
        SPRITE STAMP 5, 4 + I * 18, 4, FRAME, 260
      ELSE
        IF FRAME = 1 THEN
          COLORRGB 220, 40, 40, 255
        ELSE
          COLORRGB 60, 30, 30, 255
        END IF
        FILLRECT 4 + I * 18, 4 TO 18 + I * 18, 18
      END IF
    NEXT I

    ' Keys — icon + count.
    IF USE_PNG = 1 THEN
      SPRITE STAMP 5, 100, 4, 3, 260     ' frame 3 = key
    ELSE
      COLORRGB 240, 220, 60, 255
      FILLRECT 100, 4 TO 114, 18
    END IF
    COLORRGB 255, 255, 255, 255
    DRAWTEXT 118, 8, "x" + STR$(KEYS)

    ' Coins — icon + count.
    IF USE_PNG = 1 THEN
      SPRITE STAMP 5, 160, 4, 4, 260     ' frame 4 = coin
    ELSE
      COLORRGB 80, 200, 120, 255
      FILLRECT 160, 4 TO 174, 18
    END IF
    COLORRGB 255, 255, 255, 255
    DRAWTEXT 178, 8, STR$(COINS)

    ' Footer hint, right-aligned-ish.
    COLORRGB 180, 180, 200, 255
    DRAWTEXT 220, 8, "H K R D Q"

  OVERLAY OFF
  VSYNC
LOOP
END
