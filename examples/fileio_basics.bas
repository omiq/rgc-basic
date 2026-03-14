1 REM ============================================================
2 REM  FILE I/O BASICS - Write and read a simple data file
3 REM ============================================================
4 REM  This example shows the core CBM-style file commands:
5 REM    OPEN   - open a file for reading or writing
6 REM    PRINT# - write numbers and strings to a file
7 REM    INPUT# - read from a file into variables
8 REM    CLOSE  - close a file when done (always close to avoid losing data!)
9 REM
10 REM  OPEN uses: logical file number, device, secondary, "filename"
11 REM    - Logical file number: 1 to 255 (like a handle; use it in PRINT#/INPUT#)
12 REM    - Device 1 = disk/file (normal file on your computer)
13 REM    - Secondary: 0 = read, 1 = write, 2 = append (add to end of file)
14 REM    - Filename: path in current directory, e.g. "DATA.TXT"
15 REM ============================================================
16 REM --- STEP 1: Open file for WRITING (secondary 1) ---
17 REM     We use logical file number 1. The file "SAMPLE.DAT" will be
18 REM     created in the current directory (or overwritten if it exists).
19 OPEN 1,1,1,"SAMPLE.DAT"

20 REM --- STEP 2: Write some data with PRINT# ---
21 REM     PRINT# works like PRINT but sends output to the file.
22 REM     Use , for tab separation, ; for no extra space.
23 PRINT#1, 1234
24 PRINT#1, "Hello"
25 PRINT#1, "A"; "B"; "C"
26 CLOSE 1
27 REM --- STEP 3: Open the SAME file for READING (secondary 0) ---
28 REM     Use a different logical number (2) so we don't mix read/write.
29 OPEN 2,1,0,"SAMPLE.DAT"
30 REM --- STEP 4: Read back with INPUT# ---
31 REM     One variable per INPUT#; reads one "token" (comma or newline separated).
32 REM     Order and types must match what you wrote!
33 INPUT#2, A
34 INPUT#2, I$
35 INPUT#2, C$
36 CLOSE 2
37 REM --- STEP 5: Use the data in your program ---
38 PRINT "Number read back:"; A
39 PRINT "First string:"; I$
40 PRINT "Second string:"; C$
41 END
