' ============================================================
'  FILE I/O — reading one character at a time (GET#)
' ============================================================
'  GET# reads a single character (byte) from a file into a string
'  variable. Use it for character-by-character processing or raw
'  binary-like data.
'
'    GET# fileNumber, stringVar
'
'  After GET# check ST: 0 = got a character, 64 = end of file.
'  (stringVar is empty at EOF.)
' ============================================================

' Write three characters (no newline) to a file
OPEN 1, 1, 1, "CHARS.DAT"
PRINT#1, "X";
PRINT#1, "Y";
PRINT#1, "Z"
CLOSE 1

' Read them back one character at a time
OPEN 2, 1, 0, "CHARS.DAT"
GET#2, A$
GET#2, B$
GET#2, C$
CLOSE 2

PRINT "First  char: '"; A$; "'"
PRINT "Second char: '"; B$; "'"
PRINT "Third  char: '"; C$; "'"

IF A$ = "X" AND B$ = "Y" AND C$ = "Z" THEN PRINT "OK - all correct!"

' Bonus: read-until-EOF pattern (uncomment to try) -----------
' OPEN 1, 1, 0, "CHARS.DAT"
' DO
'   GET#1, C$
'   IF ST <> 0 THEN EXIT
'   PRINT C$;
' LOOP
' CLOSE 1
' PRINT
