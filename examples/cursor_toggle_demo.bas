' CURSOR ON / CURSOR OFF demo — transpiler-clean (FUNCTION/DO-LOOP subset).
'
' CURSOR OFF hides the text input caret; CURSOR ON restores it. The C
' transpiler now emits plat_cursor(0|1), which each adapter maps to its native
' mechanism (cc65 cursor(), ncurses curs_set, ST VT52 ESC e/f, MSX CSRSW) or
' no-ops where the target shows no caret. Runs the same under the interpreter,
' which toggles the terminal's ANSI show/hide cursor.
'
' Structured (no GOTO) so `rgcx emit-c` / `rgcx build` accept it.

CLS
CURSOR OFF
PRINT "CURSOR HIDDEN. PRESS ANY KEY."

K$ = ""
DO
  GET K$
LOOP UNTIL K$ <> ""

CURSOR ON
PRINT "CURSOR SHOWN AGAIN. BYE."
