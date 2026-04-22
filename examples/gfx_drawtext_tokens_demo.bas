' ============================================================
'  gfx_drawtext_tokens_demo — DRAWTEXT inline PETSCII tokens
'
'  DRAWTEXT consumes the PETSCII colour + reverse-video control
'  bytes inside a string (same ones PRINT honours) so a single
'  DRAWTEXT call can paint multi-colour, mixed reverse-video
'  text without a separate call per segment. Tokens supported:
'
'    {REVERSE ON} / {REVERSE OFF}
'    {BLACK} {WHITE} {RED} {CYAN} {PURPLE} {GREEN} {BLUE} {YELLOW}
'    {ORANGE} {BROWN} {PINK} {DARKGRAY} {MEDGRAY} {LIGHTGREEN}
'    {LIGHTBLUE} {LIGHTGRAY}
'
'  Cursor-move tokens (DOWN / UP / LEFT / RIGHT / HOME / CLEAR)
'  and \n / \r are consumed silently — DRAWTEXT is pixel-space,
'  use multiple DRAWTEXT calls at different y values for
'  multi-line layout.
'
'  Keys: Q = quit
' ============================================================

#OPTION PETSCII

' SCREEN 2 (RGBA) so COLORRGB + LINE paint a real per-pixel
' gradient for the knockout-text example below. The {colour}
' tokens still use the C64 palette (indices 0..15) the same
' way they do on SCREEN 3 — token handling is palette-based in
' both modes.
SCREEN 2
BACKGROUNDRGB 0, 0, 0
CLS

COLOR WHITE
DRAWTEXT 8, 8, "INLINE PETSCII TOKENS IN DRAWTEXT", 1, -1, 0, 2

' Multi-colour HUD — one call, four colours.
DRAWTEXT 8, 48, "{WHITE}HEALTH {RED}25{WHITE}/{GREEN}100  {YELLOW}SCORE {CYAN}007350", 1, -1, 0, 2

' Reverse-video + colour. The {REVERSE ON} flips the glyph/cell
' relationship; colours inside the reverse run still apply as
' the cell colour.
DRAWTEXT 8, 80, "{REVERSE ON}{RED}  DANGER  {REVERSE OFF} {WHITE}ENEMY AHEAD", 1, 0, 0, 2

' Mixed modes across one line.
DRAWTEXT 8, 112, "{WHITE}ITEMS: {LIGHTBLUE}KEY  {YELLOW}COIN*3  {PURPLE}POTION", 1, -1, 0, 2

' Transparent-glyph reverse-video: knock the letters out of a
' solid cell so whatever is painted BENEATH shows through the
' letter shapes. Paint a gradient first, then DRAWTEXT over it.
FOR Y = 0 TO 31
  T = Y / 31.0
  R = INT( 40 + T * 180)
  G = INT(160 - T * 120)
  B = INT(255 - T *  60)
  COLORRGB R, G, B
  LINE 0, 150 + Y TO 319, 150 + Y
NEXT
DRAWTEXT 8, 156, "{REVERSE ON}GRADIENT SHOWS THROUGH LETTERS", 0, -1, 0, 2

COLOR WHITE
DRAWTEXT 8, 190, "Q = quit"

DO
  IF KEYDOWN(ASC("Q")) THEN EXIT
  SLEEP 16
LOOP

SCREEN 0
CLS
PRINT "Thanks for watching."
