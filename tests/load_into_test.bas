1 REM Test LOAD INTO (GFX build only)
2 REM Terminal: expects "LOAD INTO requires basic-gfx"
3 REM GFX: loads DATA into char memory, verifies with PEEK
10 CHAR_BASE = 12288
20 LOAD @CHARDATA INTO CHAR_BASE
30 X = PEEK(CHAR_BASE)
40 IF X = 60 THEN PRINT "OK: LOAD @label"
50 END
100 CHARDATA: DATA 60,102,110,110,96,98,60,0
