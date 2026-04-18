0 OPTION PETSCII
10 REM ============================================================
20 REM C64 BASIC CONTROL CODES DEMO (expanded, explained)
30 REM ============================================================
40 REM Run with: ./basic -petscii examples/c64_control_codes_demo.bas
50 REM
60 REM This demo shows {TOKEN} brace substitutions that expand to
70 REM CHR$() calls at load time. See docs/c64-color-codes.md for
80 REM the full reference. Tokens work in -petscii mode (ANSI) and
90 REM in basic-gfx (PETSCII).
100 REM ============================================================

110 REM --- Clear screen and add spacing ---
120 REM CHR$(147) = CLR/HOME on C64; clears screen and moves cursor home.
130 REM In -petscii mode this becomes ANSI clear + home.
140 PRINT CHR$(147): PRINT : PRINT : PRINT

150 REM --- Title with colors ---
160 REM {WHITE} and {LIGHTBLUE} set foreground color. Numeric {13} = RETURN.
170 PRINT "{WHITE}CONTROL CODES DEMO{LIGHTBLUE}"
180 PRINT "{13}-------------------"
190 PRINT
200 PRINT

210 REM --- Screen control tokens ---
220 REM {HOME} = cursor to top-left. {DOWN},{UP},{LEFT},{RIGHT} move cursor.
230 REM {DEL} = delete char left. {INS} = insert mode.
240 PRINT "{HOME}";"HOME","SCREEN CONTROLS:"
250 PRINT "{DOWN}";"DOWN";"  {UP}";"UP      ";:PRINT
260 PRINT "{LEFT}";" LEFT";"  {RIGHT}";"RIGHT";:PRINT
270 PRINT "{DEL}";" DEL   {INS}";"INS";:PRINT
280 PRINT

290 REM --- Reverse video ---
300 REM {RVS} = reverse on, {RVS OFF} = reverse off. Text between is inverted.
310 PRINT "REVERSE VIDEO: {RVS}ON{RVS OFF} AND {RVS}OFF{RVS OFF}"
320 PRINT

330 REM --- Color palette ---
340 REM All 16 C64 colors. Use full names or abbrevs: {BLK},{WHT},{CYN},etc.
350 PRINT "COLORS:" : PRINT
360 PRINT " {BLACK}";"BLACK  ";"{WHITE}";"WHITE  ";"{RED}";"RED  ";"{CYAN}";"CYAN"
370 PRINT " {PURPLE}";"PURPLE ";"{GREEN}";"GREEN ";"{BLUE}";"BLUE  ";"{YELLOW}";"YELLOW"
380 PRINT " {ORANGE}";"ORANGE ";"{BROWN}";"BROWN ";"{PINK}";"PINK  ";"{GRAY1}";"GRAY1"
390 PRINT " {GRAY2}";"GRAY2 ";"{GRAY3}";"GRAY3 ";"{LIGHTGREEN}";"LIGHTGREEN"
400 PRINT " {LIGHTBLUE}";"LIGHTBLUE"
410 PRINT

420 REM --- Mixed colors ---
430 PRINT "MIXED TEXT: ";"{YELLOW}";"YELLOW ";"{GREEN}";"GREEN ";"{BLUE}";"BLUE";"{WHITE}"
440 PRINT

450 REM --- ANSI reset (terminal only) ---
460 REM {RESET} or {DEFAULT} outputs ANSI ESC[0m to reset terminal to default
470 REM colors/attributes. Useful when you can't query current settings.
480 PRINT "{RESET}";"(reset to default)"
490 PRINT

500 REM --- Wait for key ---
510 PRINT "PRESS ANY KEY...";
520 GET A$:IF A$="" THEN GOTO 520

530 REM --- Done ---
540 PRINT "{CLR}";"DONE"
550 END
