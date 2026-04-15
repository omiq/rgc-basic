REM buffer_http_demo -- fetch a large JSON response into a BUFFER,
REM then stream through it with the existing file-I/O verbs instead of
REM stuffing everything into a MAX_STR_LEN-capped BASIC string.
REM
REM Canvas WASM / basic-gfx only (HTTP is not available in the
REM plain terminal build).

#OPTION COLUMNS 80
#OPTION CHARSET PET-LOWER

REM ---- fetch into a RAM-disk file ----
BUFFERNEW 0
BUFFERFETCH 0, "https://wasterecyclingapi.eastriding.gov.uk/api/RecyclingData"

PRINT "HTTP status: "; HTTPSTATUS()
PRINT "fetched     "; BUFFERLEN(0); " bytes"
PRINT "stored at   "; BUFFERPATH$(0)

REM ---- stream the payload in MAX_STR_LEN-sized chunks and INSTR each ----
TARGET$ = "MARKET PLACE POCKLINGTON YO42 2AR"
FOUND = 0
CHUNKS = 0

OPEN 1, 1, 0, BUFFERPATH$(0)
DO WHILE NOT EOF(1) AND FOUND = 0
    REM INPUT# reads up to the next newline or comma, or 4095 bytes.
    INPUT#1, LINE$
    CHUNKS = CHUNKS + 1
    IF INSTR(LINE$, TARGET$) > 0 THEN FOUND = 1
LOOP
CLOSE 1

PRINT "scanned "; CHUNKS; " chunks"
IF FOUND THEN
    PRINT "found: "; TARGET$
ELSE
    PRINT "not found in response"
END IF

BUFFERFREE 0
