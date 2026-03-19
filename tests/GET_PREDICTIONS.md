# GET behavior – predicted outcomes

For the pattern:
```basic
WHILE K$ <> "Q"
  IF K$<>"" THEN PRINT K$
  GET K$
WEND
PRINT "DONE"
```

| Input (piped) | Predicted output |
|---------------|------------------|
| `Q` | DONE (exit immediately, no print of Q) |
| `AQ` | A, DONE |
| `ABQ` | A, B, DONE |
| `A\nQ` | A, newline (from CHR$(13)), DONE |
| `AB\nQ` | A, B, newline, DONE |
| `\nQ` | newline, DONE |
| `sls\nQ` | s, l, s, newline, DONE |

Notes:
- GET returns `""` when no key is available (non-blocking).
- Enter yields CHR$(13); PRINT outputs CR, then PRINT adds newline → CR+LF.
- Raw mode is kept across GET calls until Enter, so no double-echo.
- On real TTY, after Enter we restore cooked mode; next GET sets raw again.
