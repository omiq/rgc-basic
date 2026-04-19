' ============================================================
'  gfx_menu_demo - per-row + per-char PAPER/COLOR demo
'
'  Two attribute-control modes:
'   1. Per-row:  highlighted selection bar via PAPER on a full
'      LOCATE + PRINT line.
'   2. Per-char: rainbow title + coloured border chars, each
'      PRINT fragment using a different PAPER/COLOR pair.
'
'  Keys: up/down (or W/S) cycle selection, Q quits.
' ============================================================

BACKGROUND 6 : CLS

DIM M$(4)
M$(0) = "NEW GAME"
M$(1) = "LOAD"
M$(2) = "OPTIONS"
M$(3) = "CREDITS"
M$(4) = "QUIT"

SEL = 0

DO
  GOSUB DrawMenu
  IF KEYDOWN(ASC("Q")) THEN CLS : EXIT
  IF KEYDOWN(KEY_DOWN) OR KEYDOWN(ASC("S")) THEN SEL = SEL + 1 : GOSUB Debounce
  IF KEYDOWN(KEY_UP)   OR KEYDOWN(ASC("W")) THEN SEL = SEL - 1 : GOSUB Debounce
  VSYNC
LOOP

END

' ------------------------------------------------------------

Debounce:
  ' Wrap selection + small debounce so held keys don't race
  IF SEL < 0 THEN SEL = 4
  IF SEL > 4 THEN SEL = 0
  FOR D = 1 TO 6 : VSYNC : NEXT D
RETURN

DrawMenu:
  ' HOME (not CLS) to avoid flicker during per-tick redraw
  PRINT "{HOME}";

  ' Rainbow title: one PRINT fragment per letter
  LOCATE 12, 2
  PAPER 0 : COLOR 2  : PRINT "R";
  PAPER 0 : COLOR 8  : PRINT "G";
  PAPER 0 : COLOR 7  : PRINT "C";
  PAPER 0 : COLOR 1  : PRINT " ";
  PAPER 0 : COLOR 5  : PRINT "B";
  PAPER 0 : COLOR 13 : PRINT "A";
  PAPER 0 : COLOR 3  : PRINT "S";
  PAPER 0 : COLOR 14 : PRINT "I";
  PAPER 0 : COLOR 4  : PRINT "C"

  ' Top border
  LOCATE 6, 5
  PAPER 0 : COLOR 1 : PRINT "┌";
  FOR I = 1 TO 24 : PRINT "─"; : NEXT I
  PRINT "┐"

  ' Menu rows
  FOR I = 0 TO 4
    LOCATE 6, 6 + I
    IF I = SEL THEN GOSUB DrawRowSelected ELSE GOSUB DrawRowPlain
  NEXT I

  ' Bottom border
  LOCATE 6, 11
  PAPER 0 : COLOR 1 : PRINT "└";
  FOR I = 1 TO 24 : PRINT "─"; : NEXT I
  PRINT "┘"

  ' Footer hint
  LOCATE 4, 20
  PAPER 6 : COLOR 15 : PRINT "keys: ";
  PAPER 6 : COLOR 7  : PRINT "W/S";
  PAPER 6 : COLOR 15 : PRINT " move  ";
  PAPER 6 : COLOR 7  : PRINT "Q";
  PAPER 6 : COLOR 15 : PRINT " quit"
RETURN

DrawRowSelected:
  ' Selected: left border white on black, item white on RED, right border back to black
  PAPER 0 : COLOR 1 : PRINT "│";
  PAPER 2 : COLOR 1 : PRINT " > ";
  PAPER 2 : COLOR 1 : PRINT M$(I);
  L = LEN(M$(I))
  FOR J = 1 TO 21 - L : PRINT " "; : NEXT J
  PAPER 0 : COLOR 1 : PRINT "│"
RETURN

DrawRowPlain:
  ' Plain: all blue bg, white text
  PAPER 0 : COLOR 1  : PRINT "│";
  PAPER 6 : COLOR 1  : PRINT "   ";
  PAPER 6 : COLOR 15 : PRINT M$(I);
  L = LEN(M$(I))
  FOR J = 1 TO 21 - L : PRINT " "; : NEXT J
  PAPER 0 : COLOR 1  : PRINT "│"
RETURN
