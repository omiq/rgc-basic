' ============================================================
'  FILE I/O — reading until end of file using ST
' ============================================================
'  Pattern: OPEN for read, loop INPUT# and exit on ST <> 0.
'
'    ST = 0   success, more data may follow
'    ST = 64  end of file
'    ST = 1   error (e.g. file not open)
' ============================================================

' Write 10 random numbers to a file
PRINT "Writing 10 numbers to file..."
OPEN 1, 1, 1, "NUMBERS.DAT"
FOR I = 1 TO 10
  A = RND(0)
  PRINT A
  PRINT#1, A
NEXT I
CLOSE 1

' Read them back without knowing the count
PRINT "Reading back until end of file..."
OPEN 1, 1, 0, "NUMBERS.DAT"
DO
  INPUT#1, N
  IF ST <> 0 THEN EXIT
  PRINT N
LOOP
CLOSE 1

PRINT "Done."
