10 X = 5
20 Y = 3
30 K$ = " "
40 WHILE K$ <> "Q"
50 GET K$
55 K$ = UCASE$(K$)
60 IF K$ = "A" THEN X = X - 1
70 IF K$ = "D" THEN X = X + 1
80 IF K$ = "W" THEN Y = Y - 1
90 IF K$ = "S" THEN Y = Y + 1
100 CLS
110 TEXTAT X, Y, "@"
120 WEND
