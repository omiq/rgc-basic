' ============================================================
'  demo-scroller-sprites.bas — Approach 4: sprite-per-character
'                              Amiga-style bitmap font with
'                              sine wobble
'
'  AMOS / STOS-style scroller. One PNG sheet holds every glyph;
'  we iterate the message string, looking up each character's
'  tile index and stamping it at a bouncing Y position via
'  SPRITE STAMP. DRAWSPRITETILE tracks one persistent position
'  per slot (overwritten by each subsequent call), so it can't
'  place multiple copies of the same slot in a single frame.
'  SPRITE STAMP appends to a per-frame cell list, which is
'  exactly what we need here.
'
'  Trade-off: SPRITE STAMP shares one SPRITEMODULATE per slot —
'  no per-letter rainbow tint. The bundled chrome font already
'  carries its own baked gradient, so leaving the tint at
'  default (255,255,255) keeps the metallic highlights intact.
'
'  Bundled font: `scroller_font.png` — a 32x32 Amiga-style
'  chrome/glass bitmap font from ianhan/BitmapFonts (public
'  domain demoscene collection). 320 x 200 PNG, tiles 32 x 32,
'  10 columns x 6 rows = 60 tiles. Glyph order is row-major
'  ASCII starting at space (32) and ending at '[' (91) — all
'  uppercase, no lowercase. Lowercase input is folded to
'  uppercase at runtime; anything outside 32..91 falls through
'  to space (tile 0).
'
'  Want a different font? Any PNG that follows the same row-
'  major-ASCII-from-space layout drops in — tweak TW / TH /
'  COLS / FIRST_CHAR / LAST_CHAR below. See
'  https://github.com/ianhan/BitmapFonts for more.
'
'  Keys: Q = quit
' ============================================================

SCREEN 2
BACKGROUNDRGB 0, 0, 0         ' pure black so opaque-black cells blend
CLS
DOUBLEBUFFER ON

' --- font geometry -------------------------------------------
TW         = 32               ' tile width
TH         = 32               ' tile height
COLS       = 10               ' columns in the sheet
FIRST_CHAR = 32               ' ASCII of first tile (space)
LAST_CHAR  = 91               ' ASCII of last tile ('[')

LOADSPRITE 0, "scroller_font.png", TW, TH
IF SPRITEW(0) = 0 THEN
  COLORRGB 255, 100, 100
  DRAWTEXT 8, 90, "scroller_font.png not found"
  DRAWTEXT 8, 106, "(expected a 320x200 PNG bitmap font, 32x32 tiles)"
  SLEEP 3000
  END
END IF

MSG$ = "  * * *  RGC-BASIC 2.0  * * *  MUSIC + GRAPHICS + TRACKER MODS.  TYPE 1..9 TO LOAD TRACKS.  GREETINGS TO EVERYONE WHO REMEMBERS AMOS.  "
MSG$ = UCASE$(MSG$)           ' font is uppercase only; fold early
LEN_MSG = LEN(MSG$)

SCROLL_X = 0
T = 0

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT

  CLS

  ' Stamp each visible character via SPRITE STAMP. Appending to
  ' the per-frame cell list means N stamps of slot 0 all land at
  ' different positions this frame (DRAWSPRITETILE would collapse
  ' them onto one spot — only the last call would survive).
  FOR I = 0 TO LEN_MSG - 1
    GX = I * TW - SCROLL_X
    IF GX >= -TW AND GX <= 320 THEN
      C = ASC(MID$(MSG$, I + 1, 1))
      IF C < FIRST_CHAR OR C > LAST_CHAR THEN
        TILE = 0
      ELSE
        TILE = C - FIRST_CHAR
      END IF
      ' Sine wobble: y = base + amplitude * sin(phase). Phase
      ' per-letter (I) + time (T) so the wave travels along the
      ' string. 0.4 ≈ wavelength, 16 px amplitude.
      GY = 70 + INT( SIN( I * 0.4 + T ) * 16 )
      SPRITE STAMP 0, GX, GY, TILE + 1
    END IF
  NEXT

  SCROLL_X = SCROLL_X + 3
  IF SCROLL_X > LEN_MSG * TW THEN SCROLL_X = -320
  T = T + 0.12

  COLORRGB 180, 200, 255
  DRAWTEXT 4, 190, "Q = quit   approach 4: Amiga sprite font + sine wobble"

  VSYNC
LOOP

DOUBLEBUFFER OFF
UNLOADSPRITE 0
SCREEN 0
CLS
PRINT "Thanks for watching."
