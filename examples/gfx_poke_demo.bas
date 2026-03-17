1 REM GFX POKE DEMO: write characters and colours to screen RAM
2 REM Run with: ./basic-gfx examples/gfx_poke_demo.bas
3 REM This is a commented, example-friendly version of tests/gfx_poke_test.bas.
4 REM Screen RAM starts at 1024 (0x0400), colour RAM at 55296 (0xD800).
5 REM The screen is 40x25, laid out row-major in RAM.
10 REM Write "HELLO" at top-left of screen (screen codes: H=8,E=5,L=12,O=15)
20 POKE 1024, 8
30 POKE 1025, 5
40 POKE 1026, 12
50 POKE 1027, 12
60 POKE 1028, 15
70 REM Colour them: white=1, red=2, green=5, blue=6, yellow=7
80 POKE 55296, 1
90 POKE 55297, 2
100 POKE 55298, 5
110 POKE 55299, 6
120 POKE 55300, 7
130 REM Write "WORLD" on the second row (offset 40)
140 POKE 1064, 23
150 POKE 1065, 15
160 POKE 1066, 18
170 POKE 1067, 12
180 POKE 1068, 4
190 REM Colour: all cyan=3
200 FOR I = 0 TO 4
210 POKE 55336+I, 3
220 NEXT I
230 REM Draw a row of reversed spaces as a red bar on row 4
240 FOR I = 0 TO 39
250 POKE 1024+160+I, 160
260 POKE 55296+160+I, 2
270 NEXT I
280 REM Write "POKE WORKS!" centred on the red bar (row 4, col 14)
290 REM P=16 O=15 K=11 E=5 space=32 W=23 O=15 R=18 K=11 S=19 !=33
300 POKE 1024+174, 16
310 POKE 1024+175, 15
320 POKE 1024+176, 11
330 POKE 1024+177, 5
340 POKE 1024+178, 32
350 POKE 1024+179, 23
360 POKE 1024+180, 15
370 POKE 1024+181, 18
380 POKE 1024+182, 11
390 POKE 1024+183, 19
400 POKE 1024+184, 33
410 REM Colour the text white on red bar
420 FOR I = 174 TO 184
430 POKE 55296+I, 1
440 NEXT I
450 REM PEEK test: read back first screen byte
460 A = PEEK(1024)
470 PRINT "PEEK(1024) ="; A; " (expected 8 for H)"
480 REM Use SLEEP to keep the window open (5 seconds at 60Hz)
490 PRINT "GFX POKE DEMO COMPLETE. WINDOW WILL CLOSE IN 5 SECONDS..."
500 SLEEP 300
510 END

