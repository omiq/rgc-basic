' PRINT with reverse-video and colour mid-stream.
' CHR$(18)/CHR$(146) toggle reverse video; CHR$(158)=yellow, CHR$(5)=white.
' {RVS ON}/{RVS OFF} tokens inside a string expand to the same codes at load time.

' yellow pen
PRINT CHR$(158);
' one reversed X, then back to white
PRINT "{RVS ON}X{RVS OFF}";
COLOR 1
PRINT "X"; "X";
PRINT "X";
PRINT "END"
