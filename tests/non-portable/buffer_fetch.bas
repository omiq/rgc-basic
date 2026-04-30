REM Should fail: BUFFER* — no network / temp-file infrastructure on retro.
BUFFERNEW 0
BUFFERFETCH 0, "https://api.example.com/data"
PRINT BUFFERLEN(0)
BUFFERFREE 0
END
