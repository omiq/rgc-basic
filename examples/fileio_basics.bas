' ============================================================
'  FILE I/O BASICS — write and read a simple data file
' ============================================================
'  Core CBM-style file commands:
'    OPEN   - open a file for reading or writing
'    PRINT# - write numbers and strings to a file
'    INPUT# - read from a file into variables
'    CLOSE  - close a file when done (always close to avoid losing data!)
'
'  OPEN arguments: logical file number, device, secondary, "filename"
'    - Logical file number: 1..255 (handle used by PRINT#/INPUT#)
'    - Device 1 = disk/file
'    - Secondary: 0=read, 1=write, 2=append
'    - Filename: path in current directory
' ============================================================

' Step 1 — open for WRITING (secondary 1), logical file 1
OPEN 1, 1, 1, "SAMPLE.DAT"

' Step 2 — write some data with PRINT#
PRINT#1, 1234
PRINT#1, "Hello"
PRINT#1, "A"; "B"; "C"
CLOSE 1

' Step 3 — reopen the SAME file for READING (secondary 0)
'          Use a different logical number so we never mix read/write.
OPEN 2, 1, 0, "SAMPLE.DAT"

' Step 4 — read back with INPUT# (one variable per call)
'          Order and types must match what you wrote.
INPUT#2, A
INPUT#2, I$
INPUT#2, C$
CLOSE 2

' Step 5 — use the data
PRINT "Number read back: "; A
PRINT "First string:     "; I$
PRINT "Second string:    "; C$
