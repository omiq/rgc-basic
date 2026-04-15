REM buffer_http_demo -- fetch a large JSON response into a BUFFER,
REM then scan through it with GET# to find a target string.
REM
REM The recycling API returns one long JSON line, so INPUT# would
REM read up to the MAX_STR_LEN cap (4095 bytes) and stop — the
REM target might be anywhere in a response of 100 KB+.  Instead we
REM read byte-by-byte with GET# and build a sliding window the same
REM width as the target string, so no boundary is ever missed.
REM
REM Canvas WASM / basic-gfx only (HTTP is not available in the
REM plain terminal build).

#OPTION COLUMNS 80
#OPTION CHARSET PET-LOWER

REM ---- fetch into a RAM-disk file ----
BUFFERNEW 0
REM Replace the URL below with any JSON API endpoint you want to search.
REM e.g. a public REST API that returns a large response.
BUFFERFETCH 0, "https://api.example.com/data"

PRINT "HTTP status: "; HTTPSTATUS()
PRINT "fetched     "; BUFFERLEN(0); " bytes"

REM ---- scan byte-by-byte with a sliding window ----
REM Change TARGET$ to any string you want to find in the response.
TARGET$ = "CollectionDay"
TLEN = LEN(TARGET$)
WINDOW$ = STRING$(TLEN, 32)   : REM pre-fill with spaces
FOUND = 0
BYTES = 0

OPEN 1, 1, 0, BUFFERPATH$(0)

REM CHECK STRINGS UNTIL TARGET FOUND
DO WHILE NOT EOF(1) AND FOUND = 0
    GET#1, C$
    IF C$ = "" THEN EXIT
    BYTES = BYTES + 1
    REM slide the window: drop leftmost char, append new byte
    WINDOW$ = RIGHT$(WINDOW$, TLEN - 1) + C$
    IF WINDOW$ = TARGET$ THEN FOUND = 1
LOOP
CLOSE 1

PRINT "scanned "; BYTES; " bytes"
IF FOUND THEN
    PRINT "found: "; TARGET$; " at byte ~"; BYTES
ELSE
    PRINT "not found in response"
END IF

BUFFERFREE 0
