REM OBJLOAD / OBJSAVE — objects-overlay round-trip + replace/append modes.
REM
REM Companion files in tests/:
REM   tests/_objload_easy.json    3 objects
REM   tests/_objload_hard.json    5 objects
REM
REM Both are Shape A overlays (top-level objects[]). The test file paths
REM are relative to whatever CWD the test runner uses; run_bas_suite.sh
REM cd's to the repo root, so paths are tests/_objload_*.json.

FAILS = 0

REM Caller is responsible for sizing MAP_OBJ_* arrays — must hold the
REM largest overlay or the append total of base + overlay.
DIM MAP_OBJ_TYPE$(31)
DIM MAP_OBJ_KIND$(31)
DIM MAP_OBJ_X(31)
DIM MAP_OBJ_Y(31)
DIM MAP_OBJ_W(31)
DIM MAP_OBJ_H(31)
DIM MAP_OBJ_ID(31)
MAP_OBJ_COUNT = 0

REM 1. Plain replace load. Easy overlay has 3 objects.
OBJLOAD "tests/_objload_easy.json"
IF MAP_OBJ_COUNT <> 3 THEN PRINT "FAIL 1 expected 3 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(0) <> "spawn" THEN PRINT "FAIL 1a TYPE got "; MAP_OBJ_TYPE$(0) : FAILS = FAILS + 1
IF MAP_OBJ_KIND$(0) <> "player" THEN PRINT "FAIL 1b KIND got "; MAP_OBJ_KIND$(0) : FAILS = FAILS + 1
IF MAP_OBJ_X(0) <> 32 THEN PRINT "FAIL 1c X got "; MAP_OBJ_X(0) : FAILS = FAILS + 1
IF MAP_OBJ_Y(0) <> 32 THEN PRINT "FAIL 1d Y got "; MAP_OBJ_Y(0) : FAILS = FAILS + 1

REM 2. Replace mode is the default — load hard overlay, easy data must
REM    be wiped, MAP_OBJ_COUNT must reset to 5.
OBJLOAD "tests/_objload_hard.json"
IF MAP_OBJ_COUNT <> 5 THEN PRINT "FAIL 2 expected 5 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(0) <> "enemy" THEN PRINT "FAIL 2a TYPE got "; MAP_OBJ_TYPE$(0) : FAILS = FAILS + 1
IF MAP_OBJ_KIND$(4) <> "boss" THEN PRINT "FAIL 2b KIND[4] got "; MAP_OBJ_KIND$(4) : FAILS = FAILS + 1

REM 3. Explicit "replace" mode == default — round-trip same load.
OBJLOAD "tests/_objload_easy.json", "replace"
IF MAP_OBJ_COUNT <> 3 THEN PRINT "FAIL 3 expected 3 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1

REM 4. "append" mode — easy (3) + hard (5) = 8 objects total. First
REM    three are easy data unchanged; remaining are hard.
OBJLOAD "tests/_objload_hard.json", "append"
IF MAP_OBJ_COUNT <> 8 THEN PRINT "FAIL 4 expected 8 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(0) <> "spawn" THEN PRINT "FAIL 4a TYPE[0] got "; MAP_OBJ_TYPE$(0) : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(3) <> "enemy" THEN PRINT "FAIL 4b TYPE[3] got "; MAP_OBJ_TYPE$(3) : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(7) <> "enemy" THEN PRINT "FAIL 4c TYPE[7] got "; MAP_OBJ_TYPE$(7) : FAILS = FAILS + 1

REM 5. Round-trip: load easy, OBJSAVE to a temp, OBJLOAD that, expect
REM    identical state. Tests that OBJSAVE emits valid Shape A.
OBJLOAD "tests/_objload_easy.json"
SAVED_COUNT = MAP_OBJ_COUNT
SAVED_TYPE$ = MAP_OBJ_TYPE$(0)
SAVED_KIND$ = MAP_OBJ_KIND$(2)
SAVED_X = MAP_OBJ_X(2)
SAVED_Y = MAP_OBJ_Y(2)
OBJSAVE "tests/_objload_easy_roundtrip.json"
IF FILEEXISTS("tests/_objload_easy_roundtrip.json") = 0 THEN PRINT "FAIL 5 OBJSAVE produced no file" : FAILS = FAILS + 1
OBJLOAD "tests/_objload_easy_roundtrip.json"
IF MAP_OBJ_COUNT <> SAVED_COUNT THEN PRINT "FAIL 5a count got "; MAP_OBJ_COUNT : FAILS = FAILS + 1
IF MAP_OBJ_TYPE$(0) <> SAVED_TYPE$ THEN PRINT "FAIL 5b TYPE got "; MAP_OBJ_TYPE$(0) : FAILS = FAILS + 1
IF MAP_OBJ_KIND$(2) <> SAVED_KIND$ THEN PRINT "FAIL 5c KIND got "; MAP_OBJ_KIND$(2) : FAILS = FAILS + 1
IF MAP_OBJ_X(2) <> SAVED_X THEN PRINT "FAIL 5d X got "; MAP_OBJ_X(2) : FAILS = FAILS + 1
IF MAP_OBJ_Y(2) <> SAVED_Y THEN PRINT "FAIL 5e Y got "; MAP_OBJ_Y(2) : FAILS = FAILS + 1

REM 6. shape "point" round-trip — w and h stay zero, no rect fields.
REM    The easy overlay's first object (spawn, kind=player) is a point.
IF MAP_OBJ_W(0) <> 0 THEN PRINT "FAIL 6a W expected 0 got "; MAP_OBJ_W(0) : FAILS = FAILS + 1
IF MAP_OBJ_H(0) <> 0 THEN PRINT "FAIL 6b H expected 0 got "; MAP_OBJ_H(0) : FAILS = FAILS + 1

REM 7. Append onto an empty list — should behave like replace from zero.
MAP_OBJ_COUNT = 0
OBJLOAD "tests/_objload_easy.json", "append"
IF MAP_OBJ_COUNT <> 3 THEN PRINT "FAIL 7 expected 3 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1

REM 8. Empty OBJSAVE — write 0 objects, OBJLOAD that file, count=0.
MAP_OBJ_COUNT = 0
OBJSAVE "tests/_objload_empty.json"
IF FILEEXISTS("tests/_objload_empty.json") = 0 THEN PRINT "FAIL 8 OBJSAVE empty produced no file" : FAILS = FAILS + 1
OBJLOAD "tests/_objload_empty.json"
IF MAP_OBJ_COUNT <> 0 THEN PRINT "FAIL 8a expected 0 got "; MAP_OBJ_COUNT : FAILS = FAILS + 1

REM --- summary --------------------------------------------------------
IF FAILS > 0 THEN PRINT "OBJLOAD/OBJSAVE: "; FAILS; " failure(s)" : STOP
PRINT "OBJLOAD/OBJSAVE: all 8 cases passed"
END
