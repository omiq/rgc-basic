REM Should fail: HTTP$ + HTTPSTATUS — no network on retro hardware.
R$ = HTTP$("https://example.com/api")
PRINT HTTPSTATUS()
END
