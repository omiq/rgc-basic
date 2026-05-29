REM unknown-keyword rule (E003): invented/misspelled built-ins.
REM Each line below uses a keyword that does NOT exist in rgc-basic.
REM PRINTLN is the canonical hallucination (PRINT is real, PRINTLN is not
REM and is deliberately NOT in the keyword-normalisation split-list, so it
REM stays one token and gets caught).
PRINTLN "this is not a keyword"
BEEP 440
CLEARSCREEN
