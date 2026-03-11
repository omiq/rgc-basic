REM Test PRINT / semicolon / escape-sequence behaviour

REM CASE 1: Plain text with and without semicolons
PRINT "A"
PRINT "B";
PRINT "C"

REM CASE 2: Color escapes and names, all with semicolons
PRINT CHR$(28);
PRINT "RED";
PRINT CHR$(5);

REM CASE 3: Color escapes and names, last one without semicolon
PRINT CHR$(159);
PRINT "CYAN"

REM CASE 4: Explicitly use carriage return
PRINT "A";CHR$(13);"B";CHR$(13);"C"

END

